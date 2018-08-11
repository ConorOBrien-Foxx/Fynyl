#!/usr/bin/ruby
require 'cmath'
require 'readline'

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
	@@META = ["@", "#", "&", ".&"]
	def FynylState.tokenize(code)
		line, col = 1, 1
		code.scan(/#@@NUMBER|\s+|[.:]*\S/).map.with_index { |raw, start|
			type = case raw
				when "{"
					:block_open
				when "}"
					:block_close
				when /^#@@NUMBER$/
					:number
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
		@variables = {"A" => ("A".."Z").to_a.join }
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
	
	def running?
		@pos < @tokens.size
	end
	
	def call_subinst(inst)
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
					@stack = @stack_stack.pop + [@stack]
				when :number
					@stack << cur.raw.tr('_', '-').to_i
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
						else
							STDERR.puts "unhandled meta #{meta_symbol.inspect}"
					end
				when :operator
					case cur.raw
						when /[-+\/%]/
							a, b = @stack.pop(2)
							@stack.push a.send cur.raw, b
						
						when "="
							a, b = @stack.pop(2)
							@stack.push a == b
						
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
						
						when "!"
							call_subinst @stack.pop
						
						when "b"
							@stack.push FynylState.truthy? @stack.pop
						
						when ".c"
							@stack.push CMath::cos @stack.pop
						
						when "d"
							@stack.push @stack.last
							
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
						
						when "m"
							a, f = @stack.pop(2)
							@stack << a.map { |e|
								call_inst(f, e).last
							}
						
						when "r"
							a = @stack.pop
							@stack << if Array === a || String === a
								a.reverse
								
							elsif Numeric === a
								(1..a).to_a
							
							elsif a.respond_to? :reverse
								a.reverse
							
							elsif a.respond_to? :to_a
								a.to_a.reverse
							
							else
								:no
							end
						
						when "R"
							a, b = @stack.pop(2)
							@stack << (a..b).to_a
						
						when "t"
							as, bs, f = @stack.pop(3)
							@stack << as.map { |a|
								bs.map { |b|
									call_inst(f, a, b).last
								}
							}
						
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
						
						when "y"
							@stack.push @stack[-2]
						
						when "z"
							a, b, f = @stack.pop(3)
							@stack << a.zip(b).map { |e| call_inst(f, *e).last }
						
						when "~"
							@stack.pop(2).reverse_each { |e| @stack << e }
							
						else
							STDERR.puts "unknown operator #{cur.raw.inspect}"
					end
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

inst = FynylState.new ARGV[0]
inst.run
inst.stack.each { |e|
	puts FynylState.format e
}
