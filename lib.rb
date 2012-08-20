load 'asm.rb'

class C64BasicError < Exception; end
class C64Basic
  attr_reader :basic, :code

  def initialize(program)
    raise C64BasicError, 'Program has to be a string' unless program.instance_of? String

    @basic = program
    @code = parse
  end

  private
  def parse
    code = AsmBlock.new

    code.push(AsmAlign.new(2049))
    addr = 2049
    lines = @basic.upcase.lines.to_a.collect{|l| l == "\n" ? nil : (l.bytes.to_a.last == "\n".ord ? l.chop : l)}.compact
    lines.each do |l|
      raise C64BasicError, 'Parse error' unless (m = l.match(/(\d+) (.*)/))

      code.push(AsmData.new([addr+2], :word))
      code.push(AsmData.new([m[1].to_i], :word))

      in_quote = false
      tokens = m[2].split(' ')
      tokens.each do |t|
        if not in_quote and C64Consts::BASIC.has_key? t
          token  = AsmData.new([C64Consts::BASIC[t]])
          code.push(token)
          addr += token.length
        else
          token = AsmData.new(t)
          code.push(token)
          addr += token.length
          if in_quote
            in_quote == false if t.bytes.to_a.last == '"'.ord
          end
        end
        
        if t == tokens.last
          code.push(AsmData.new([0]))
        else
          code.push(AsmData.new(' '))
        end
        addr += 1
      end

      if l == lines.last
        code.push(AsmData.new([0], :word))
      end
    end
   
    code.link(2049)
    code
  end
end
