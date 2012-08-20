#
# C64 Assembler DSL
# Version 4
#

load 'data.rb'
load 'objlogger.rb'

ObjLogger.setup

class Fixnum
  def lsbyte; self & 255; end
  def msbyte; self >> 8; end
end

class AsmOperandError < Exception; end
class AsmOperand
  attr_reader :op, :mode, :arg

  def initialize(op, arg = false, mod = false)
    raise AsmOperandError, 'No such operand' unless OPCODES.has_key? op

    @op = op
    @mode = false
    @arg = arg
    @mod = mod
    @label = false
    @ready = false

    opcode = OPCODES[op]

    # mode resolution
    if opcode.has_key? :n
      # all immediates
      @mode = :n
      @ready = true
    elsif opcode.keys.length == 1
      # branching and jsr
      @mode = opcode.keys.first
    elsif arg and arg.instance_of? Fixnum
      # for the rest, let's try figure out mode by checking argument
      # we treate addresing modes as of higher priority, eg. :z over :d
      if arg >= 0 and arg <= 255
        if opcode.has_key? :z
          @mode = :z
        elsif opcode.has_key? :d
          @mode = :d
        else
          raise AsmOperandError, 'No mode handling byte'
        end
      elsif arg >= 256 and arg <= 65535
        if opcode.has_key? :a
          @mode = :a
        else
          raise AsmOperandError, 'Argument out of range'
        end
      end
    end

    # future reference handling, aka labels
    if arg and arg.instance_of? Symbol
      # labels can point only to absolute addresses
      unless (has_a = opcode.has_key? :a) or opcode.has_key? :r
        raise AsmOperandError, 'Used with label but no :a or :r modes'
      end
      @mode = has_a ? :a : :r
      @label = arg
    end

    # argument checking
    if @mode and not @label
      raise AsmOperandError, 'Invalid argument' unless validate
      @ready = true
    end

    # modifier checking
    check_mod if mod
  end

  # create addressing mode methods
  ADDRMODES.keys.each do |mode|
    class_eval "def #{mode}(arg, mod = nil); check_mode(:#{mode}, arg, mod); end"
  end

  def ready?; @ready; end
  def deferred?; @label; end

  def resolve(arg)
    return true unless @label

    if @mod
      @arg = arg.send(*@mod)
    else
      @arg = arg
    end

    raise AsmOperandError, 'Invalid argument' unless validate
    @ready = true
  end

  def to_source
    source = @op.to_s

    if @label
      if @mod
        case @mod.first
        when :+
          label = @label.to_s + ('%+d' % @mod[1])
        when :lsbyte
          label = '<' + @label.to_s
        when :msbyte
          label = '>' + @label.to_s
        end
      else
        label = @label.to_s
      end
    end

    unless @mode == :n
      if @label
        source += ADDRMODES[@mode][:src] % label
      else
        if @mode == :r
          source += ' *%+d' % @arg.to_s
        else
          source += ADDRMODES[@mode][:src] % ('$' + @arg.to_s(16))
        end
      end
    end

    source
  end

  def length; @mode ? 1 + ADDRMODES[@mode][:len] : false; end

  def to_s; "<Operand: #{to_source}>"; end

  def to_a
    return [] unless @ready
    bytes = [OPCODES[@op][@mode]]
    if @arg and @arg > 255
      bytes += [@arg.lsbyte, @arg.msbyte]
    elsif @arg
      bytes += [@arg]
    else
      bytes
    end
  end

  def to_binary
    return '' unless @ready
    if @mode == :r
      to_a.pack('Cc')
    else
      to_a.pack('C*')
    end
  end

  private
  def check_mode(mode, arg, mod)
    raise AsmOperandError, 'Operand was ready' if @ready
    raise AsmOperandError, 'No such mode' unless OPCODES[@op].has_key? mode

    @mode = mode
    @arg = arg
    @mod = mod

    if arg.instance_of? Fixnum
      raise AsmOperandError, 'Invalid argument' unless validate
      @ready = true
    elsif arg.instance_of? Symbol
      raise AsmOperandError, 'Label used with wrong mode' unless @mode.to_s[0] == 'a'
      @label = arg
    else
      raise AsmOperandError, 'Unhandled argument type'
    end

    check_mod if mod

    self
  end

  def check_mod
    raise AsmOperandError, 'Modifier used with non-label argument' unless @label

    if @mod.instance_of? Fixnum
      @mod = [ :+, @mod ]
    elsif [ :<, :> ].member? @mod
      # this two modifiers make sense only for :d addressing mode
      if not @mode or (@mode and @mode != :d)
        raise AsmOperandError, 'Byte modifier used with non-direct addressing mode' unless OPCODES[@op].has_key? :d
        @mode = :d
      end

      @mod = [ @mod == :< ? :lsbyte : :msbyte ]
    else
      raise AsmOperandError, 'Unknown modifier'
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

class AsmNopError < Exception; end
class AsmNop
  def ready?; true; end
  def deferred?; false; end
  def to_a; []; end
  def to_binary; ''; end
end

class AsmLabel < AsmNop
  attr_reader :name

  def initialize(name)
    raise AsmNopError, 'Label name must be a symbol' unless name.instance_of? Symbol
    @name = name
  end

  def to_source; @name.to_s; end
  def to_s; "<Label: #{@name}>"; end
end

class AsmAlign < AsmNop
  attr_reader :addr

  def initialize(addr)
    unless addr.instance_of? Fixnum and (addr >= 0 and addr <= 65535)
      raise AsmNopError, 'Alignment address has to be in range $0 - $ffff'
    end
    @addr = addr
  end

  def to_source; "* = $#{@addr.to_s(16)}"; end
  def to_s; "<Align: $#{@addr.to_s(16)}"; end
end

class AsmData < AsmNop
  attr_reader :data, :mode, :length

  def initialize(data, mode = :default)
    case data
    when String
      raise AsmNopError, 'Unimplemented mode' unless [ :default ].member? mode
      @length = data.bytesize
    when Array
      raise AsmNopError, 'Unimplemented mode' unless [ :default, :unsigned ].member? mode
      @length = data.length
    end

    @data = data
    @mode = mode
  end

  def to_s
    string = '<Data: '
    if @data.instance_of? String
      string += '"' + (@data.length > 16 ? @data.slice(0, 16) + '...' : @data) + '"'
    elsif @data.instance_of? Array
      slice = @data.length > 8 ? @data.slice(0, 8) : @data
      string += slice.collect{|e| '$' + e.to_s(16)}.join(',')
      string += '...' if slice.length != @data.length
    else
      string += '?'
    end
    if @mode != :default
      string += " (#{mode})"
    end
    string += '>'
  end

  def to_source
    if @data.instance_of? String
      ".screen \"#{@data}\""
    elsif @data.instance_of? Array
      case @mode
      when :default
        ".byte #{@data.collect{|e| '$' + e.to_s(16)}.join(',')}"
      when :unsigned
        ".ubyte #{@data.collect{|e| '$' + e.to_s(16)}.join(',')}"
      end
    end
  end

  def to_binary
    if @data.instance_of? String
      @data.bytes.to_a.pack('C*')
    elsif @data.instance_of? Array
      case @mode
      when :default
        @data.pack('C*')
      when :unsigned
        @data.pack('c*')
      end
    end
  end
end

class AsmBlock < Array
  def to_source
    (['.block'] + self.collect{|e| e.to_source} + ['.bend']).flatten
  end

  def to_s; "<Block #{self.length}>"; end
end

class AsmMacroError < Exception; end
class AsmMacro
  attr_reader :variables

  def initialize(vars = {}, &blk)
    @code = AsmBlock.new
    @labels = []
    @variables = vars
    @vars = {}
    @blocks = []

    @blocks.push(blk) if blk
  end

  def add_code(&blk); @blocks.push(blk); end

  def to_s; "<Macro #{@blocks.length} #{@variables.to_s}>"; end

  def call(vars = {})
    return [] if @blocks.empty?

    @code = AsmBlock.new
    @labels = []

    # check for extraneous variables
    extra = vars.keys - @variables.keys
    raise AsmMacroError, "Extraneous variables #{extra.join(', ')}" unless extra.empty?

    # merge variable hash
    @vars = @variables.merge(vars)

    @blocks.each{|b| instance_eval(&b)}
    @code
  end

  private
  def align(addr)
    @code.push(AsmAlign.new(addr))
  end

  def label(name)
    parse_warn "Redefinition of label #{name}" if @labels.member? name
    @labels.push(name)
    @code.push(AsmLabel.new(name))
    name
  end

  def data(arg, mode = :default)
    @code.push(AsmData.new(arg, mode))
  end

  def use(stuff)
    @code.push(stuff)
  end

  def method_missing(name, *args, &blk)
    name = :and if name == :ane
    if OPCODES.has_key? name
      begin
        if args.length == 0
          op = AsmOperand.new(name)
        else
          arg = args.first
          mod = args[1] or false
          op = AsmOperand.new(name, arg, mod)
        end
      rescue AsmOperandError => e
        parse_error e.to_s
      end
      @code.push(op)
      op
    elsif @vars.has_key? name
      @vars[name]
    else
      parse_error 'Method not found'
    end
  end

  def say(level, msg)
    from = caller[2].match(/.*?\:\d+/)[0]
    log level, "(#{from}) #{msg}"
  end

  def parse_error(msg)
    say :error, msg
    raise AsmMacroError
  end

  def parse_warn(msg); say :warn, msg; end
end

class AsmLinkerError < Exception; end
module AsmLinker
  def AsmLinker.link(block, addr = 0x1000, pass = :init)
    raise AsmLinkerError, 'Invalid origin' unless (addr.instance_of? Fixnum and addr >= 0 and addr <= 65535)
    raise AsmLinkerError, 'Invalid data' unless block.instance_of? AsmBlock

    origin = addr
    labels = {}
    block.each do |e|
      case e
      when AsmAlign
        addr = e.addr
      when AsmLabel
        labels[e.name] = addr
      when AsmData
        addr += e.length
      when AsmOperand
        addr += e.length
      when AsmBlock
        addr = link(e, addr, :first)
      else
        puts e
        puts e.class
        log :error, 'Unknown stuff in AsmBlock'
        raise AsmLinkerError
      end
    end

    return addr if pass == :first

    binary = ''
    addr = origin
    block.each do |e|
      case e
      when AsmAlign
        if e.addr > addr
          binary += ([0] * (e.addr - addr)).pack('C*')
        else
          log :error, 'Misaligned chunk'
          raise AsmLinkerError
        end
        addr = e.addr
      when AsmLabel
        true
      when AsmData
        binary += e.to_binary
        addr += e.length
      when AsmOperand
        unless e.ready?
          if e.deferred? == :*
            arg = addr
          elsif labels.has_key? e.deferred?
            arg = labels[e.deferred?]
          else
            log :error, "Label resolution for #{e.to_s}"
          end

          if e.mode == :r
            arg = arg - addr - 2
          end

          e.resolve(arg)
        end

        binary += e.to_binary
        addr += e.length
      when AsmBlock
        data = link(e, addr, :second)
        binary += data
        addr += data.bytesize
      else
        log :error, 'Unknown stuff in AsmBlock'
      end
    end

    if pass == :init
      [origin.lsbyte, origin.msbyte].pack('C*') + binary
    else
      binary
    end
  end
end
