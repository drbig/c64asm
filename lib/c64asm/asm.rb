# encoding: utf-8
# See LICENSE.txt for licensing information.

require 'logger'
require 'c64asm/data'
require 'c64asm/basic'

class Fixnum
  def ls_byte; self & 255; end
  def ms_byte; self >> 8; end
end

module C64Asm
  attr_accessor :logger
  @logger = Logger.new(STDERR)
  @logger.level = Logger::DEBUG
  @logger.formatter = lambda do |s, d, p, m|
    "#{d.strftime('%H:%M:%S.%L')} #{s.to_s.ljust(7)} -- #{m}\n"
  end

  def self.log(level, msg)
    @logger.send(level, msg) if @logger
  end

  class Error < Exception; end

  class OperandError < Error; end
  class Operand
    attr_reader :op, :mode, :arg, :label

    def initialize(op, arg = false, mod = false)
      raise OperandError, 'No such operand' unless OP_CODES.has_key? op

      @op = op
      @mode = false
      @arg = arg
      @mod = mod
      @label = false
      @ready = false

      opcode = OP_CODES[op]

      # mode resolution
      if opcode.has_key? :n
        # all immediates
        @mode = :n
        @ready = true
      elsif not arg and opcode.has_key? :e
        @mode = :e
        @ready = true
      elsif opcode.keys.length == 1
        # branching and jsr
        @mode = opcode.keys.first
      elsif arg and arg.instance_of? Fixnum
        # for the rest, let's try figure out mode by checking argument
        # we treat addressing modes as of higher priority, eg. :z over :d
        if arg >= 0 and arg <= 255
          if opcode.has_key? :z
            @mode = :z
          elsif opcode.has_key? :d
            @mode = :d
          else
            raise OperandError, 'No mode handling byte'
          end
        elsif arg >= 256 and arg <= 65535
          if opcode.has_key? :a
            @mode = :a
          else
            raise OperandError, 'Argument out of range'
          end
        end
      end

      # future reference handling, aka labels
      if arg and arg.instance_of? Symbol
        # labels can point only to absolute addresses
        unless (has_a = opcode.has_key? :a) or opcode.has_key? :r
          raise OperandError, 'Used with label but no :a or :r modes'
        end

        @mode = has_a ? :a : :r
        @label = arg
      end

      # argument checking
      if @mode and not @label
        raise OperandError, 'Invalid argument' unless validate

        @ready = true
      end

      # modifier checking
      check_mod if mod
    end

    # create addressing mode methods
    ADDR_MODES.keys.each do |mode|
      class_eval "def #{mode}(arg, mod = nil); check_mode(:#{mode}, arg, mod); end"
    end

    def ready?; @ready; end

    def resolve(arg)
      return true unless @label

      @mod ? @arg = arg.send(*@mod) : @arg = arg
      raise OperandError, 'Invalid argument' unless validate

      @ready = true
    end

    def to_source
      source = @op.to_s

      if @label
        if @mod
          case @mod.first
          when :+
            label = @label.to_s + ('%+d' % @mod[1])
          when :ls_byte
            label = '<' + @label.to_s
          when :ms_byte
            label = '>' + @label.to_s
          else
            label = @label.to_s + @mod.join
          end
        else
          label = @label.to_s
        end
      end

      unless @mode == :n or @mode == :e
        if @label
          source += ADDR_MODES[@mode][:src] % label
        else
          if @mode == :r
            source += ' *%+d' % @arg.to_s
          else
            source += ADDR_MODES[@mode][:src] % ('$' + @arg.to_s(16))
          end
        end
      end

      source
    end

    def length; @mode ? 1 + ADDR_MODES[@mode][:len] : false; end

    def to_s; "<Operand: #{to_source}>"; end

    def to_a
      return [] unless @ready

      bytes = [OP_CODES[@op][@mode][:byte]]

      if @arg and @arg > 255
        bytes += [@arg.ls_byte, @arg.ms_byte]
      elsif @arg
        bytes += [@arg]
      else
        bytes
      end
    end

    def to_binary
      return '' unless @ready

      @mode == :r ? to_a.pack('Cc') : to_a.pack('C*')
    end

    private
    def check_mode(mode, arg, mod)
      raise OperandError, 'Operand was ready' if @ready
      raise OperandError, 'No such mode' unless OP_CODES[@op].has_key? mode

      @mode = mode
      @arg = arg
      @mod = mod

      case arg
      when Fixnum
        raise OperandError, 'Invalid argument' unless validate
        @ready = true
      when Symbol
        modec = @mode.to_s[0]
        if @mod
          raise OperandError, 'Label used with wrong mode' unless (modec == 'a') or (modec == 'd')
        else
          raise OperandError, 'Label used with wrong mode' unless modec == 'a'
        end
        @label = arg
      else
        raise OperandError, 'Invalid argument type'
      end

      check_mod if mod

      self
    end

    def check_mod
      raise OperandError, 'Modifier used with non-label argument' unless @label

      if @mod.instance_of? Fixnum
        @mod = [:+, @mod]
      elsif @mod.instance_of? Array and @mod.length == 2 and [:/, :*, :<<, :>>, :& , :|].member? @mod.first
        raise OperandError, 'Arithmetic argument has to be a fixnum' unless @mod[1].instance_of? Fixnum
      elsif [:<, :>].member? @mod
        # this two modifiers make sense only for :d addressing mode
        if not @mode or (@mode and @mode != :d)
          unless OP_CODES[@op].has_key? :d
            raise OperandError, 'Byte modifier used with non-direct addressing mode'
          end

          @mode = :d
        end

        @mod = [@mod == :< ? :ls_byte : :ms_byte]
      else
        raise OperandError, 'Unknown modifier'
      end
    end

    def validate
      if (@mode == :n and @arg) or \
        (@mode == :r and not (@arg >= -128 and @arg <= 127)) or \
        ([:a, :ax, :ay, :ar].member? @mode and not (@arg >= 0 and @arg <= 65535)) or \
        ([:d, :z, :zx, :zy, :zxr, :zyr].member? @mode and not (@arg >= 0 and @arg <= 255))
        false
      else
        true
      end
    end
  end

  class NopError < Error; end
  class Nop
    def ready?; true; end
    def label; false; end
    def to_a; []; end
    def to_binary; ''; end
  end

  class LabelError < NopError; end
  class Label < Nop
    attr_reader :name

    def initialize(name)
      raise LabelError, 'Label name must be a symbol' unless name.instance_of? Symbol

      @name = name
    end

    def to_source; @name.to_s; end
    def to_s; "<Label: #{@name}>"; end
  end

  class AlignError < NopError; end
  class Align < Nop
    attr_reader :addr

    def initialize(addr)
      unless addr.instance_of? Fixnum and (addr >= 0 and addr <= 65535)
        raise AlignError, 'Alignment address has to be in range $0 - $ffff'
      end

      @addr = addr
    end

    def to_source; "* = $#{@addr.to_s(16)}"; end
    def to_s; "<Align: $#{@addr.to_s(16)}"; end
  end

  class DataError < NopError; end
  class Data < Nop
    attr_reader :data, :mode, :length

    def initialize(data, mode = :default)
      case data
      when String
        raise DataError, 'Unimplemented mode' unless [:default, :screen].member? mode
        @length = data.length
      when Array
        raise DataError, 'Unimplemented mode' unless [:default, :word].member? mode
        @length = mode == :word ? 2 * data.length : data.length
      end

      @data = data
      @mode = mode

      validate
    end

    def to_s
      string = '<Data: '

      case @data
      when String
        string += '"' + (@data.length > 16 ? @data.slice(0, 16) + '...' : @data) + '"'
      when Array
        slice = @data.length > 8 ? @data.slice(0, 8) : @data
        string += slice.collect{|e| '$' + e.to_s(16)}.join(',')
        string += '...' if slice.length != @data.length
      end

      if @mode != :default
        string += " (#{mode})"
      end

      string += '>'
    end

    def to_source
      case @data
      when String
        case @mode
        when :default
          ".text \"#{@data}\""
        when :screen
          ".screen \"#{@data}\""
        end
      when Array
        case @mode
        when :default
          ".byte #{@data.collect{|e| '$' + e.to_s(16)}.join(',')}"
        when :word
          ".word #{@data.collect{|e| '$' + e.to_s(16)}.join(',')}"
        end
      end
    end

    def to_binary
      case @data
      when String
        case @mode
        when :default
          @data.each_codepoint.to_a.collect{|p| PETSCII[p]}.pack('C*')
        when :screen
          @data.upcase.each_codepoint.to_a.collect{|p| CHAR_MAP[p]}.pack('C*')
        end
      when Array
        case @mode
        when :default
          @data.pack('C*')
        when :word
          @data.collect{|e| [e.ls_byte, e.ms_byte]}.flatten.pack('C*')
        end
      end
    end

    private
    def validate
      case @data
      when String
        case @mode
        when :default
          @data.each_codepoint{|p| raise DataError, 'Invalid data' unless PETSCII.has_key? p}
        when :screen
          @data.upcase.each_codepoint{|p| raise DataError, 'Invalid data' unless CHAR_MAP.has_key? p}
        end
      when Array
        case @mode
        when :default
          @data.each{|e| raise DataError, 'Invalid data' unless (e >= 0 and e <= 255)}
        when :word
          @data.each{|e| raise DataError, 'Invalid data' unless (e >= 0 and e <= 65535)}
        end
      end
    end
  end

  class BlockError < Error; end
  class Block < Array
    attr_reader :labels, :linked

    def initialize
      @labels = {}
      @linked = false
      @chunks = {}
    end

    def link(origin = 0x1000)
      raise BlockError, 'Invalid origin' unless (origin >= 0 and origin <= 65535)

      # override origin if first non-Block element is an Align object
      felem = first
      while felem.class == Block
        felem = felem.first
      end
      if felem.instance_of? Align
        origin = felem.addr
      end

      endaddr = _linker_pass(origin, :one)
      _linker_pass(origin, :two)

      @linked
    end

    def to_source
      (['.block'] + collect{|e| e.to_source} + ['.bend']).flatten
    end

    def to_s; "<Block #{length}>"; end

    def to_binary
      link unless @linked
      [@linked[0].ls_byte, @linked[0].ms_byte].pack('CC') + _binary_pass
    end

    def dump
      link unless @linked
      lines = _dump
      lines.shift
      lines
    end

    def write!(fname, mode = 'w', what = :prg)
      File.open(fname, mode) do |fd|
        case what
        when :prg
          fd.write(to_binary)
        when :src
          fd.write(to_source.join("\n"))
        when :dump
          fd.write(dump.join("\n"))
        else
          raise BlockError, 'Unknown generation mode'
        end
      end
    end

    def _dump
      addr = @linked.first
      lines = []

      lines.push('$%0.4x   ' % addr +  "           \t.block")
      each do |e|
        line = ('$%0.4x   ' % addr).upcase
        block = false

        case e
        when Operand
          if e.mode == :r
            bytes = e.to_a.pack('Cc').unpack('C*')
          else
            bytes = e.to_a
          end
          line += bytes.to_a.collect{|e| '%0.2X' % e}.join(' ')
          line += ' ' * (9 - (3 * e.length))
          line += "   \t#{e.to_source}"
          addr += e.length
        when Align
          line += "           \t#{e.to_source}"
          addr = e.addr
        when Label
          line += "           #{e.to_source}"
        when Data
          line += ".. .. ..   \t#{e.to_source}"
          addr += e.length
        when Block
          addr, _lines = e._dump
          lines += _lines
          block = true
        end

        lines.push(line) unless block
      end
      lines.push('$%0.4x   ' % addr +  "           \t.bend")

      [addr, lines]
    end

    def _binary_pass
      binary = ''
      each do |e|
        case e
        when Align
          binary += ([0] * (e.addr - @chunks[e.addr])).pack('C*')
        when Label
          true
        when Data
          binary += e.to_binary
        when Operand
          binary += e.to_binary
        when Block
          binary += e._binary_pass
        end
      end

      binary
    end

    def _linker_pass(addr, pass)
      @labels = {} if pass == :one
      origin = addr

      each do |e|
        case e
        when Align
          raise BlockError, "Invalid alignment from $#{addr.to_s(16)} to $#{e.addr.to_s(16)}" if e.addr < addr

          @chunks[e.addr] = addr if pass == :one
          addr = e.addr
        when Label
          if pass == :one
            if @labels.has_key? e.name
              C64Asm.log :warn, "Redefinition of label #{e.name} from $#{@labels[e.name].to_s(16)} to $#{addr.to_s(16)}"
            end

            @labels[e.name] = addr
          end
        when Data
          addr += e.length
        when Operand
          if pass == :two
            unless e.ready?
              if e.label == :*
                arg = addr
              elsif @labels.has_key? e.label
                arg = @labels[e.label]
              else
                C64Asm.log :error, "Can't resolve label for #{e.to_s}"
                raise BlockError
              end

              if e.mode == :r
                arg = arg - addr -2
              end

              e.resolve(arg)
            end
          end

          addr += e.length
        when Block
          addr = e._linker_pass(addr, pass)
        else
          C64Asm.log :error, "Invalid element #{e.to_s} in Block"
          raise BlockError
        end
      end

      @linked = [origin, addr] if pass == :one
      addr
    end
  end

  class MacroError < Error; end
  class Macro
    attr_reader :variables

    def initialize(vars = {}, &blk)
      @variables = vars
      @procs = []

      @procs.push(blk) if blk
    end

    def add_code(&blk); @procs.push(blk); end

    def to_s; "<Macro #{@procs.length} #{@variables.to_s}>"; end

    def call(vars = {})
      return Block.new if @procs.empty?

      @code = Block.new
      @labels = []

      # check for extraneous variables
      extra = vars.keys - @variables.keys
      raise MacroError, "Extraneous variables #{extra.join(', ')}" unless extra.empty?

      # merge variable hash
      @vars = @variables.merge(vars)

      @procs.each{|b| instance_eval(&b)}
      @code
    end

    private
    def align(addr)
      begin
        @code.push(Align.new(addr))
      rescue AlignError => e
        parse_error "Align instruction error: #{e.to_s}"
      end
      addr
    end

    def label(name)
      parse_warn "Redefinition of label #{name}" if @labels.member? name
      begin
        @code.push(Label.new(name))
      rescue LabelError => e
        parse_error "Label instruction error: #{e.to_s}"
      end
      @labels.push(name)
      name
    end

    def data(arg, mode = :default)
      begin
        data = Data.new(arg, mode)
        @code.push(data)
      rescue DataError => e
        parse_error "Data instruction error: #{e.to_s}"
      end
      data.length
    end

    def block(stuff)
      parse_error 'Block not an instance of Block' unless stuff.instance_of? Block
      @code.push(stuff)
      stuff.length
    end

    def insert(stuff)
      parse_error 'Block not an instance of Block' unless stuff.instance_of? Block
      @code += stuff
      stuff.length
    end

    def method_missing(name, *args, &blk)
      name = :and if name == :ane
      if OP_CODES.has_key? name
        begin
          if args.length == 0
            op = Operand.new(name)
          else
            arg = args.first
            mod = args[1] or false
            op = Operand.new(name, arg, mod)
          end
        rescue OperandError => e
          parse_error "Operand error: #{e.to_s}"
        end
        @code.push(op)
        op
      elsif @vars.has_key? name
        @vars[name]
      else
        parse_error "Method :#{name} not found"
      end
    end

    def say(level, msg)
      from = caller[2].match(/.*?\:\d+/)[0]
      C64Asm.log level, "(#{from}) #{msg}"
    end

    def parse_error(msg)
      say :error, msg
      raise MacroError
    end

    def parse_warn(msg); say :warn, msg; end
  end
end
