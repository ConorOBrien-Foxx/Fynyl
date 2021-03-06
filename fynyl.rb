#!/usr/bin/ruby
require 'cmath'
require 'readline'

Infinity = Float::INFINITY

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

def iofn(arity=nil, &bl)
    arity ||= bl.arity
    lambda { |inst|
        args = inst.stack.pop(arity)
        res = bl[*args]
        inst.stack << res unless res == :none
    }
end

class FynylState
    @@NUMBER = /_?\d+/
    @@STRING = /"(?:[^"]|"")*"/
    @@META = ["z", "m", ".m", "v", "V", "t", "f"]
    @@UPDATE_TYPES = {
        "&" => :set_var,
        ".&" => :set_func,
    }
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

    def FynylState.block(code)
        FynylState.new code, populate: false
    end

    def initialize(code, populate: true)
        @stack = []
        @stack_stack = []
        if populate
            @variables = { "A" => ("A".."Z").to_a.join, "h" => "", "H" => " " }
        else
            @variables = {}
        end
        @functions = {}
        if Array === code
            @tokens = code
        else
            @tokens = FynylState.tokenize(code)
        end
        @pos = 0
        process_blocks
    end
    attr_accessor :stack, :stack_stack, :tokens, :variables, :functions

    def process_blocks
        result = []
        block_stack = []
        depth = nil
        read_count = nil
        build_read = []
        read_source = nil
        @tokens.each { |token|
            if depth != nil
                depth -= 1 if token.type == :block_close
                depth += 1 if token.type == :block_open

                if depth.zero?
                    result << FynylState.block(block_stack.pop)
                    depth = nil
                else
                    block_stack.last << token
                end

            elsif read_count != nil
                read_count -= 1
                build_read << token
                if read_count.zero?
                    read_count = nil
                    case read_source.raw
                        when "@", "#"
                            result << FynylState.block(build_read)
                        when "&", ".&"
                            result << FynylToken.new(
                                build_read.map(&:raw).join,
                                @@UPDATE_TYPES[read_source.raw],
                                read_source.start,
                                read_source.line,
                                read_source.col
                            )
                        else
                            raise "unhandled read_count source: #{read_source.inspect}"
                    end
                    build_read = []
                end

            elsif token.type == :block_open
                depth = 1
                block_stack << []

            elsif ["@", "&", ".&"].include? token.raw
                read_count = 1
                read_source = token

            elsif token.raw == "#"
                read_count = 2
                read_source = token

            else
                result << token
            end
        }
        @tokens = result
    end

    def cur
        @tokens[@pos]
    end

    def advance
        @pos += 1
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
        if Proc === inst
            [inst[*args]]
        else
            if String === inst
                inst = FynylState.new(inst)
            end
            inst.stack = args
            inst.variables = @variables.dup
            inst.functions = @functions.dup
            inst.run
            inst.stack
        end
    end

    def get_func(source)
        if FynylState === source
            source
        elsif FynylToken === source
            call_inst("{#{source.raw}}").last
        else
            raise "malformed source: #{source.inspect}"
        end
    end

    def call_meta(meta_symbol, fn=nil, &block)
        function = block || fn
        if function.raw == "~"
            function = @stack.pop
        end
        case meta_symbol
            when "z"
                iofn { |a, b|
                    a.zip(b).map { |e| call_inst(function, *e).last }
                }

            when "f"
                iofn { |a|
                    # deduce seed, if applicable
                    signature = function.body.strip
                    seed = case signature
                        when "+"
                            0
                        when "*"
                            1
                        else
                            nil
                    end

                    a = [seed, *a] unless seed.nil?

                    a.inject { |a, c| call_inst(function, a, c).last }
                }

            when "m"
                iofn { |a|
                    a.map { |e|
                        call_inst(function, e).last
                    }
                }

            when ".m"
                iofn { |a|
                    a.each { |e|
                        call_inst(function, e).last
                    }
                    :none
                }

            when "t"
                iofn { |as, bs|
                    as.map { |a|
                        bs.map { |b|
                            call_inst(function, a, b).last
                        }
                    }
                }

            when "v"
                rec = lambda { |l, r|
                    case [Array === l, Array === r]
                        when [true, true]
                            l.zip(r).map { |e, k| rec[e, k] }

                        when [true, false]
                            l.map { |e| rec[e, r] }

                        when [false, true]
                            r.map { |e| rec[l, e] }

                        when [false, false]
                            call_inst(function, l, r).last
                    end
                }
                iofn { |l, r| rec[l, r] }

            when "V"
                rec = lambda { |a|
                    Array === a ? a.map { |e| rec[e] } : call_inst(function, a).last
                }
                iofn { |a| rec[a] }

            else
                STDERR.puts "unhandled meta #{meta_symbol.inspect}"
        end
    end

    def step
        if FynylState === cur
            @stack << cur

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
                when :set_var
                    @variables[cur.raw] = @stack.pop
                when :set_func
                    @functions[cur.raw] = @stack.pop
                when :meta
                    meta_symbol = cur.raw
                    advance
                    function = call_meta meta_symbol, get_func(cur)
                    function[self]

                when :operator
                    call_op cur.raw
                else
                    STDERR.puts "unknown type #{cur.type} for #{cur}"
            end
        end

        advance
    end

    def call_op(op = cur.raw)
        case op
            when "+"
                a, b = @stack.pop(2)
                @stack.push a + b

            when "-"
                a, b = @stack.pop(2)
                @stack.push a - b

            when "%"
                a, b = @stack.pop(2)
                @stack.push a % b

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

            when "._"
                @stack.reverse!

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
            when ":="
                a, b = @stack.pop(2)
                @stack.push a != b
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
                case e
                    when Array, String
                        @stack << e.to_a.sample
                    when FynylState
                        a = @stack.pop
                        if FynylState.truthy? a
                            call_subinst e
                        end
                    else
                        @stack << rand(e)
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
            when ".,"
                @stack << @stack.pop(@stack.pop)
            when ";"
                @stack << @stack.pop.to_s

            when "$"
                @stack.pop
            when ".$"
                @stack.pop @stack.pop
            when ":$"
                size = @stack.pop
                @stack.pop until @stack.size <= size

            when "!"
                a = @stack.pop
                case a
                    when Numeric
                        @stack << a
                        call_subinst "rf*"
                    when TrueClass, FalseClass
                        @stack << !a
                    else
                        call_subinst a
                end
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
                a = @stack.pop
                if FynylState === a
                    @stack.push a
                else
                    @stack.push FynylState.new(a)
                end

            when "g"
                @stack.push @stack.pop.to_f
            when "G"
                @stack.push @stack.pop.to_r


            when "i"
                @stack.push @stack.pop * 1i

            when "I"
                @stack.push @stack.pop.to_i

            when ".I"
                el = @stack.pop
                @stack.clear
                @stack << el
            when ":I"
                els = @stack.pop(@stack.pop)
                @stack.clear
                @stack.concat els

            when "j"
                if Array === @stack.last
                    @stack << @stack.pop.join
                else
                    a, j = @stack.pop(2)
                    @stack << a.join(j)
                end

            when "L"
                f = @stack.pop
                loop {
                    call_subinst f
                }
            when ".l"
                path = @stack.pop
                call_subinst File.read(path)

            when "M"
                @stack.concat @stack.pop

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
            when ".R"
                @stack << STDIN.gets.chomp
            when "..R"
                @stack << STDIN.gets
            when ":R"
                call_subinst STDIN.gets
            when "::R"
                f = @stack.pop
                STDIN.each_line { |line|
                    call_subinst line
                    call_subinst f unless f.nil?
                }

            when "s"
                a = @stack.pop
                @stack << case a
                    when Numeric
                        a.abs.to_s.size
                    when FynylState
                        Infinity
                    else
                        a.size
                end

            when "S"
                call_subinst "@+f"

            when ".:S"
                print_stack

            when "T"
                @stack.push @stack.pop.transpose

            when "u"
                a, b = @stack.pop(2)
                @stack << b
                call_meta("V") { |b|
                    a[b]
                } [self]

            when "w"
                f = @stack.pop
                while FynylState.truthy? @stack.last
                    call_subinst f
                end
            when "W"
                c, f = @stack.pop(2)
                loop {
                    temp = @stack.dup
                    s = call_inst c, *temp
                    unless FynylState.truthy? s.last
                        break
                    end
                    call_subinst f
                }

            when ".w"
                File.write(@stack.pop, @stack.pop)

            when "x"
                n, b = @stack.pop(2)
                @stack << to_base(b, n)

            when "X"
                a, b = @stack.pop(2)
                @stack << from_base(b, a)

            when "y"
                @stack.push @stack[-2]


            # "z" - zip
            when "Z"
                a = @stack.pop
                case a
                    when Numeric
                        @stack.push (0...a).to_a
                    else
                        @stack.push (0...a.size).to_a
                end

            when "~"
                @stack.pop(2).reverse_each { |e| @stack << e }

            else
                STDERR.puts "unknown operator #{op.inspect}"
        end
    end


    def run
        @pos = 0
        step while running?
    end

    def body
        tokens.map(&:raw).join
    end

    alias :raw :body

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
    require 'optparse'
    file_name = File.basename $0

    options = {}
    parser = OptionParser.new { |opts|
        opts.program_name = file_name
        opts.banner = "Usage: #{file_name} [options]"

        opts.separator ""
        opts.separator "[options]"

        opts.on("-r", "--repl", "Engage REPL mode") { |v|
            options[:repl] = v
        }
        opts.on("-e", "--execute CODE", "Executes `CODE`") { |v|
            options[:code] = v
        }
        opts.on_tail("-h", "--help", "Show this help message") { |v|
            puts opts
            exit
        }
    }
    parser.parse!
    if ARGV.empty? && options.empty?
        puts parser
        exit
    end

    if options[:repl]
        program = File.read("examples/repl.fyn")
    elsif options[:code]
        program = options[:code]
    else
        program = File.read(ARGV[0])
    end

    inst = FynylState.new program
    inst.run
    inst.print_stack
end
