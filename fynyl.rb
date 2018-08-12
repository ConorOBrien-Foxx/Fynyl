#!/usr/bin/ruby
require 'cmath'
require 'readline'

def to_base(base, n)
    return [0] if n.zero?
    arr = []
    until n.zero?
        n, m = n.divmod(base)
        arr.unshift m
    end
    arr
end

def from_base(base, arr)
    arr.map.with_index { |e, i| e * base**(arr.size - i - 1) }.sum
end

def chunk_by(arr, n)
    arr = arr.clone
    res = []
    until arr.empty?
        res << arr.shift(n)
    end
    res
end

def chunk_into(arr, n)
    chunk_by(arr, (arr.size / n.to_f).ceil)
end

class FynylToken
    def initialize(raw=nil, type=nil, start=nil, line=nil, col=nil)
        @raw = raw
        @type = type
        @start = start
        @line = line
        @col = col
    end

    attr_accessor :raw, :type, :start, :line, :col

    def to_s
        "#{@raw.inspect} (#{type} #{line}:#{col})"
    end
end

class FynylState
    @@NUMBER = /_?\d+/
    @@STRING = /"(?:[^"]|"")*"/
    @@META = ["@", "#", "&", ".&", "q", "Q"]
    def FynylState.tokenize(code)
        line, col = 1, 1
        code.scan(/#@@NUMBER|#@@STRING|\s+|[`'].|[.:]*\S/).map.with_index { |raw, start|
            type = case raw
                when "{"
                    :block_open
                when "}"
                    :block_close
                when /^`/
                    :ord
                when /^'/
                    :char
                when /^#@@NUMBER$/
                    :number
                when /^#@@STRING$/
                    :string
                when /^\s+$/
                    :whitespace
                when *@@META
                    :meta
                when "("
                    :array_start
                when ")"
                    :array_end
                else
                    :operator
            end
            res = FynylToken.new raw, type, start, line, col
            raw.each_char { |c|
                if c == "\n"
                    line += 1
                    col = 1
                else
                    col += 1
                end
            }
            res
        }
    end

    def initialize(code)
        @stack = []
        @stack_stack = []
        @variables = { "A" => ("A".."Z").to_a.join, "h" => "", "H" => " " }
        @functions = {}
        if Array === code
            @tokens = code
        else
            @tokens = FynylState.tokenize(code)
        end
        @pos = 0
        @building_block_depth = nil
    end
    attr_accessor :stack, :stack_stack, :tokens, :variables, :functions

    def cur
        @tokens[@pos]
    end

    def advance
        @pos += 1
    end

    def call_op(op = cur.raw)
        case op
            when /^[-+%]$/
                a, b = @stack.pop(2)
                @stack.push a.send op, b

            when "_"
                a = @stack.pop
                @stack << if Array === a || String === a
                    a.reverse

                elsif Numeric === a
                    -a

                elsif a.respond_to? :reverse
                    a.reverse

                elsif a.respond_to? :to_a
                    a.to_a.reverse

                else
                    raise 'idk'
                end

            when "|"
                @stack.push @stack.pop.abs

            when "/"
                a, b = @stack.pop(2)

                @stack << if String === a && String === b
                    a.split b
                elsif Numeric === a && Numeric === b
                    a / b
                elsif Numeric === b
                    chunk_into(a, b)
                end

            when ":%"
                fmt, n = @stack.pop(2)
                args = @stack.pop(n)
                @stack << fmt.gsub(/%(\d+)/) { args[$1.to_i] }

            when "^"
                a, b = @stack.pop(2)
                @stack << a ** b

            when "="
                a, b = @stack.pop(2)
                @stack.push a == b
            when "<"
                a, b = @stack.pop(2)
                @stack.push a < b
            when ".<"
                @stack.push @stack.pop(2).min
            when ":<"
                a, b = @stack.pop(2)
                @stack.push a <= b
            when ">"
                a, b = @stack.pop(2)
                @stack.push a > b
            when ".>"
                @stack.push @stack.pop(2).max
            when ":>"
                a, b = @stack.pop(2)
                @stack.push a >= b

            when "?"
                e = @stack.pop
                stack << case e
                    when Array, String
                        e.to_a.sample
                    else
                        rand e
                end

            when ".?"
                @stack.push @stack.pop.shuffle

            when "["
                @stack.push @stack.pop.pred
            when "]"
                @stack.push @stack.pop.succ

            when "*"
                a, b = @stack.pop(2)
                if FynylState === a
                    b.times {
                        call_subinst a
                    }
                elsif FynylState === b
                    a.times {
                        call_subinst b
                    }
                else
                    @stack << a * b
                end

            when ","
                @stack << @stack.pop(2)

            when "$"
                @stack.pop
            when ".$"
                @stack.pop @stack.pop

            when "!"
                call_subinst @stack.pop

            when "b"
                @stack.push FynylState.truthy? @stack.pop

            when "C"
                @stack.clear

            when "c"
                @stack.push @stack.pop.chr

            when ".c"
                @stack.push CMath::cos @stack.pop
            when ":c"
                @stack.push CMath::acos @stack.pop

            when "d"
                @stack.push @stack.last
            when "D"
                n = @stack.pop
                @stack << case n
                    when String
                        n.chars
                    when Array
                        n.dup
                    when Numeric
                        n.digits.reverse
                end
            when "E"
                exit 0
            when ".E"
                exit! @stack.pop

            when "e"
                call_subinst FynylState.new(@stack.pop)

            when "F"
                @stack.push FynylState.new(@stack.pop)

            when "f"
                a, f = @stack.pop(2)
                # deduce seed, if applicable
                signature = f.body.strip
                seed = case signature
                    when "+"
                        0
                    when "*"
                        1
                    else
                        nil
                end

                a = [seed, *a] unless seed.nil?

                @stack << a.inject { |p, c| call_inst(f, p, c).last }

            when "i"
                @stack.push @stack.pop * 1i

            when "j"
                a, j = @stack.pop(2)
                @stack << a.join(j)

            when "L"
                f = @stack.pop
                loop {
                    call_subinst f
                }
            when ".l"
                path = @stack.pop
                call_subinst File.read(path)

            when "m"
                a, f = @stack.pop(2)
                @stack << a.map { |e|
                    call_inst(f, e).last
                }
            when ".m"
                a, f = @stack.pop(2)
                a.each { |e|
                    call_inst(f, e).last
                }

            when "o"
                puts @stack.pop
            when "O"
                print @stack.pop
            when "p"
                puts FynylState.format(@stack.pop)
            when "P"
                print FynylState.format(@stack.pop)

            when "r"
                a = @stack.pop
                @stack << (1..a).to_a

            when "R"
                a, b = @stack.pop(2)
                @stack << (a..b).to_a

            when ".r"
                @stack << Readline.readline("", true)
            when "..r"
                @stack << Readline.readline(@stack.pop, true)
            when ":r"
                @stack << File.read(@stack.pop)

            when "s"
                @stack << @stack.pop.size
            when ";"
                @stack << @stack.pop.to_s

            when "S"
                call_subinst "@+f"

            when "t"
                as, bs, f = @stack.pop(3)
                @stack << as.map { |a|
                    bs.map { |b|
                        call_inst(f, a, b).last
                    }
                }

            when ".:S"
                print_stack

            when "T"
                @stack.push @stack.pop.transpose

            when "v"
                f = @stack.pop
                rec = lambda { |l, r|
                    case [Array === l, Array === r]
                        when [true, true]
                            l.zip(r).map { |e, k| rec[e, k] }

                        when [true, false]
                            l.map { |e| rec[e, r] }

                        when [false, true]
                            r.map { |e| rec[l, e] }

                        when [false, false]
                            call_inst(f, l, r).last
                    end
                }
                @stack << rec[*@stack.pop(2)]

            when "V"
                f = @stack.pop
                rec = lambda { |a|
                    Array === a ? a.map { |e| rec[e] } : call_inst(f, a).last
                }
                @stack << rec[@stack.pop]

            when "w"
                f = @stack.pop
                while FynylState.truthy? @stack.last
                    call_subinst f
                end
            when "W"
                c, f = @stack.pop(2)
                loop {
                    call_subinst c
                    unless FynylState.truthy? @stack.last
                        break
                    end
                    call_subinst f
                }

            when "x"
                n, b = @stack.pop(2)
                @stack << to_base(b, n)

            when "X"
                n, b = @stack.pop(2)
                @stack << from_base(b, n)

            when "y"
                @stack.push @stack[-2]

            when "z"
                a, b, f = @stack.pop(3)
                @stack << a.zip(b).map { |e| call_inst(f, *e).last }

            when "~"
                @stack.pop(2).reverse_each { |e| @stack << e }

            else
                STDERR.puts "unknown operator #{op.inspect}"
        end
    end

    def running?
        @pos < @tokens.size
    end

    def call_subinst(inst)
        if String === inst
            inst = FynylState.new(inst)
        end
        inst.stack = @stack
        inst.variables = @variables
        inst.functions = @functions
        inst.run
    end

    def call_inst(inst, *args)
        inst.stack = args
        inst.variables = @variables.dup
        inst.functions = @functions.dup
        inst.run
        inst.stack
    end

    def step
        if @building_block_depth != nil
            @building_block_depth -= 1 if cur.type == :block_close
            @building_block_depth += 1 if cur.type == :block_open

            if @building_block_depth.zero?
                @stack << FynylState.new(@stack_stack.pop)
                @building_block_depth = nil
            else
                @stack_stack.last << cur
            end

        elsif @variables.has_key? cur.raw
            @stack << @variables[cur.raw]

        elsif @functions.has_key? cur.raw
            call_subinst @functions[cur.raw]

        else
            case cur.type
                when :whitespace
                    # pass
                when :array_start
                    @stack_stack << @stack.clone
                    @stack.clear
                when :array_end
                    temp = @stack_stack.pop
                    temp.push @stack.dup
                    @stack.clear
                    @stack.concat temp
                when :ord
                    @stack << cur.raw[1].ord
                when :char
                    @stack << cur.raw[1]
                when :number
                    @stack << cur.raw.tr('_', '-').to_i
                when :string
                    @stack << cur.raw[1..-2].gsub('""', '"')
                when :meta
                    meta_symbol = cur.raw
                    advance
                    case meta_symbol
                        when "@"
                            @stack << FynylState.new([cur])
                        when "&"
                            @variables[cur.raw] = @stack.pop
                        when ".&"
                            @functions[cur.raw] = @stack.pop
                        when "#"
                            a = [cur]
                            advance
                            a << cur
                            @stack << FynylState.new(a)
                        when "q"
                            call_subinst "@#{cur.raw}v"
                        when "Q"
                            call_subinst "@#{cur.raw}V"
                        else
                            STDERR.puts "unhandled meta #{meta_symbol.inspect}"
                    end
                when :operator
                    call_op cur.raw
                when :block_open
                    @building_block_depth = 1
                    @stack_stack << []
                else
                    STDERR.puts "unknown type #{cur.type} for #{cur}"
            end
        end

        advance
    end

    def run
        @pos = 0
        step while running?
    end

    def body
        tokens.map(&:raw).join
    end

    def to_s
        FynylState.format self
    end

    def print_stack
        @stack.each { |e|
            puts FynylState.format e
        }
    end

    def FynylState.format(entity)
        case entity
            when Array
                "(#{entity.map { |e| FynylState.format e } * " "})"
            when FynylState
                "{" + entity.body + "}"
            when TrueClass, FalseClass
                entity ? "1b" : "0b"
            when Complex
                res = if entity.real.zero?
                    "#{entity.imag}i".tr('-', '_')
                else
                    entity.to_s
                end
            when String
                '"' + entity.gsub('"', '""') + '"'
            when Numeric
                entity.to_s.tr('-', '_')
            else
                entity.to_s
        end
    end

    def FynylState.truthy?(n)
        n != 0 && n != "" && n != [] && n != false
    end
end

if $0 == __FILE__
    program = File.read(ARGV[0]) rescue ARGV[0]
    inst = FynylState.new program
    inst.run
    inst.print_stack
end
