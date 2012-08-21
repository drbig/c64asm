load 'asm.rb'

class C64BasicError < Exception; end
class C64Basic
  attr_reader :basic, :code

  def initialize(program, origin = 0x801, align = true)
    raise C64BasicError, 'Program has to be a string' unless program.instance_of? String
    raise C64BasicError, 'Origin has to be a fixnum' unless origin.instance_of? Fixnum
    raise C64BasicError, 'Origin out of range' unless (origin >= 0 and origin <= 65535)
    
    @basic = program
    @code = AsmBlock.new

    @code.push(AsmAlign.new(origin)) if align
    @code.push(AsmData.new(parse(origin)))
  end

  def to_s; "<Basic: #{@basic.lines.to_a.length}>"; end

  private
  def parse(addr)
    state = :nextline
    bytes = []
    line = []
    token = ''
    
    @basic.upcase.each_char do |c|
      if c == "\n"
        state = :nextline
        next
      end

      if state == :nextline
        unless token.empty?
          token.codepoints.each{|p| bytes += [C64Consts::PETSCII[p]]}
          token = ''
        end

        unless bytes.empty?
          bytes += [0]
          addr += 1
        end

        addr += 2
        bytes += [addr.lsbyte, addr.msbyte]
        state = :linenum
      end
      
      if state == :linenum
        if c.match(/\d/)
          token += c
          addr += 1
        else
          raise C64BasicError, 'Each line has to start with a line number' if token.empty?

          lineno = token.to_i
          raise C64BasicError, 'Line number out of range' unless (lineno >= 0 and lineno <= 65535)

          bytes += [lineno.lsbyte, lineno.msbyte]
          addr += 2
          state = :out
          token = ''

          next if c == ' '
        end
      end

      if state == :out
        if c == '"'
          bytes += [C64Consts::PETSCII['"'.ord]]
          addr += 1
          state = :in

          next
        elsif c == ' '
          unless token.empty?
            token.codepoints.each{|p| bytes += [C64Consts::PETSCII[p]]}
            token = ''
          end

          bytes += [C64Consts::PETSCII[' '.ord]]
          addr += 1
        elsif C64Consts::BASIC.has_key? c
          token.codepoints.each{|p| bytes += [C64Consts::PETSCII[p]]} unless token.empty?
          bytes += [C64Consts::BASIC[c]]
          addr += 1
          token = ''
        else
          raise C64BasicError, 'Unknown character' unless C64Consts::PETSCII.has_key? c.codepoints.to_a.first

          token += c
          addr += 1

          if C64Consts::BASIC.has_key? token
            bytes += [C64Consts::BASIC[token]]
            token = ''
          end
        end
      end

      if state == :in
        raise C64BasicError, 'Unknown character' unless C64Consts::PETSCII.has_key? c.codepoints.to_a.first

        token += c
        addr += 1
        state = :out if c == '"'
      end

      puts "#{c} #{addr} #{bytes} #{token}"
    end

    unless token.empty?
      token.codepoints.each{|p| bytes += [C64Consts::PETSCII[p]]}
      bytes += [0]
    end

    bytes += [0, 0]
  end
end
