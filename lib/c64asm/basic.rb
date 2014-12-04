# encoding: utf-8
# See LICENSE.txt for licensing information.

require 'c64asm/asm'
require 'c64asm/data'

module C64Asm
  class Error < Exception; end

  class BasicError < Error; end
  class Basic
    attr_reader :basic, :code

    def initialize(program, origin = 0x801, align = true)
      raise BasicError, 'Program has to be a string' unless program.instance_of? String
      raise BasicError, 'Origin has to be a fixnum' unless origin.instance_of? Fixnum
      raise BasicError, 'Origin out of range' unless (origin >= 0 and origin <= 65535)

      @basic = program
      @code = Block.new

      @code.push(Align.new(origin)) if align
      @code.push(Data.new(parse(origin)))
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
            token.codepoints.each{|p| bytes += [PETSCII[p]]}
            token = ''
          end

          unless bytes.empty?
            bytes += [0]
            addr += 1
          end

          addr += 2
          bytes += [addr.ls_byte, addr.ms_byte]
          state = :linenum
        end

        if state == :linenum
          if c.match(/\d/)
            token += c
            addr += 1
          else
            raise BasicError, 'Each line has to start with a line number' if token.empty?

            lineno = token.to_i
            raise BasicError, 'Line number out of range' unless (lineno >= 0 and lineno <= 65535)

            bytes += [lineno.ls_byte, lineno.ms_byte]
            addr += 2
            state = :out
            token = ''

            next if c == ' '
          end
        end

        if state == :out
          if c == '"'
            bytes += [PETSCII['"'.ord]]
            addr += 1
            state = :in

            next
          elsif c == ' '
            unless token.empty?
              token.codepoints.each{|p| bytes += [PETSCII[p]]}
              token = ''
            end

            bytes += [PETSCII[' '.ord]]
            addr += 1
          elsif BASIC.has_key? c
            token.codepoints.each{|p| bytes += [PETSCII[p]]} unless token.empty?
            bytes += [BASIC[c]]
            addr += 1
            token = ''
          else
            raise BasicError, 'Unknown character' unless PETSCII.has_key? c.codepoints.to_a.first

            token += c
            addr += 1

            if BASIC.has_key? token
              bytes += [BASIC[token]]
              token = ''
            end
          end
        end

        if state == :in
          raise BasicError, 'Unknown character' unless PETSCII.has_key? c.codepoints.to_a.first

          token += c
          addr += 1
          state = :out if c == '"'
        end
      end

      unless token.empty?
        token.codepoints.each{|p| bytes += [PETSCII[p]]}
        bytes += [0]
      end

      bytes += [0, 0]
    end
  end
end
