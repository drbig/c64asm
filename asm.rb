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
  attr_reader :op, :mode, :arg, :label

  def initialize(op, arg = false, mod = false)
    raise AsmOperandError, 'No such operand' unless AsmConsts::OPCODES.has_key? op

    @op = op
    @mode = false
    @arg = arg
    @mod = mod
    @label = false
    @ready = false

    opcode = AsmConsts::OPCODES[op]

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
  AsmConsts::ADDRMODES.keys.each do |mode|
    class_eval "def #{mode}(arg, mod = nil); check_mode(:#{mode}, arg, mod); end"
  end

  def ready?; @ready; end

  def resolve(arg)
    return true unless @label

    @mod ? @arg = arg.send(*@mod) : @arg = arg
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
        source += AsmConsts::ADDRMODES[@mode][:src] % label
      else
        if @mode == :r
          source += ' *%+d' % @arg.to_s
        else
          source += AsmConsts::ADDRMODES[@mode][:src] % ('$' + @arg.to_s(16))
        end
      end
    end

    source
  end

  def length; @mode ? 1 + AsmConsts::ADDRMODES[@mode][:len] : false; end

  def to_s; "<Operand: #{to_source}>"; end

  def to_a
    return [] unless @ready

    bytes = [AsmConsts::OPCODES[@op][@mode][:byte]]

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

    @mode == :r ? to_a.pack('Cc') : to_a.pack('C*')
  end

  private
  def check_mode(mode, arg, mod)
    raise AsmOperandError, 'Operand was ready' if @ready
    raise AsmOperandError, 'No such mode' unless AsmConsts::OPCODES[@op].has_key? mode

    @mode = mode
    @arg = arg
    @mod = mod

    case arg
    when Fixnum
      raise AsmOperandError, 'Invalid argument' unless validate
      @ready = true
    when Symbol
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
        unless AsmConsts::OPCODES[@op].has_key? :d
          raise AsmOperandError, 'Byte modifier used with non-direct addressing mode'
        end

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
  def label; false; end
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
      raise AsmNopError, 'Unimplemented mode' unless [ :default, :screen ].member? mode
      @length = data.length
    when Array
      raise AsmNopError, 'Unimplemented mode' unless [ :default, :word ].member? mode
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
        @data.each_codepoint.to_a.collect{|p| C64Consts::PETSCII[p]}.pack('C*')
      when :screen
        @data.upcase.each_codepoint.to_a.collect{|p| C64Consts::CHARMAP[p]}.pack('C*')
      end
    when Array
      case @mode
      when :default
        @data.pack('C*')
      when :word
        @data.collect{|e| [e.lsbyte, e.msbyte]}.flatten.pack('C*')
      end
    end
  end

  private
  def validate
    case @data
    when String
      case @mode
      when :default
        @data.each_codepoint{|p| raise AsmNopError, 'Invalid data' unless C64Consts::PETSCII.has_key? p}
      when :screen
        @data.upcase.each_codepoint{|p| raise AsmNopError, 'Invalid data' unless C64Consts::CHARMAP.has_key? p}
      end
    when Array
      case @mode
      when :default
        @data.each{|e| raise AsmNopError, 'Invalid data' unless (e >= 0 and e <= 255)}
      when :word
        @data.each{|e| raise AsmNopError, 'Invalid data' unless (e >= 0 and e <= 65535)}
      end
    end
  end
end

class AsmBlockError < Exception; end
class AsmBlock < Array
  attr_reader :labels, :linked

  def initialize
    @labels = {}
    @linked = false
    @chunks = {}
  end

  def link(origin = 0x1000)
    raise AsmBlockError, 'Invalid origin' unless (origin >= 0 and origin <= 65535)

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
    [@linked[0].lsbyte, @linked[0].msbyte].pack('CC') + _binary_pass
  end

  def dump
    link unless @linked
    lines = _dump
    lines.shift
    lines
  end

  def _dump
    addr = @linked.first
    lines = []

    lines.push('$%0.4x   ' % addr +  "           \t.block")
    each do |e|
      line = ('$%0.4x   ' % addr).upcase
      block = false

      case e
      when AsmOperand
        if e.mode == :r
          bytes = e.to_a.pack('Cc').unpack('C*')
        else
          bytes = e.to_a
        end
        line += bytes.to_a.collect{|e| '%0.2X' % e}.join(' ')
        line += ' ' * (9 - (3 * e.length))
        line += "   \t#{e.to_source}"
        addr += e.length
      when AsmAlign
        line += "           \t#{e.to_source}"
        addr = e.addr
      when AsmLabel
        line += "           #{e.to_source}"
      when AsmData
        line += ".. .. ..   \t#{e.to_source}"
        addr += e.length
      when AsmBlock
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
      when AsmAlign
        binary += ([0] * (e.addr - @chunks[e.addr])).pack('C*')
      when AsmLabel
        true
      when AsmData
        binary += e.to_binary
      when AsmOperand
        binary += e.to_binary
      when AsmBlock
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
      when AsmAlign
        raise AsmBlockError, "Unhandled alignment from #{addr} to #{e.addr}" if e.addr < addr
        @chunks[e.addr] = addr if pass == :one
        addr = e.addr
      when AsmLabel
        if pass == :one
          if @labels.has_key? e.name
            log :warn, "Redefinition of label #{e.name} from $#{@labels[e.name].to_s(16)} to $#{addr.to_s(16)}"
          end

          @labels[e.name] = addr
        end
      when AsmData
        addr += e.length
      when AsmOperand
        if pass == :two
          unless e.ready?
            if e.label == :*
              arg = addr
            elsif @labels.has_key? e.label
              arg = @labels[e.label]
            else
              log :error, "Can't resolve label for #{e.to_s}"
              raise AsmBlockError
            end

            if e.mode == :r
              arg = arg - addr -2
            end

            e.resolve(arg)
          end
        end

        addr += e.length
      when AsmBlock
        addr = e._linker_pass(addr, pass)
      else
        log :error, "Unhandled element #{e.to_s} in AsmBlock"
        raise AsmBlockError
      end
    end

    @linked = [origin, addr] if pass == :one
    addr
  end
end

class AsmMacroError < Exception; end
class AsmMacro
  attr_reader :variables

  def initialize(vars = {}, &blk)
    @variables = vars
    @procs = []

    @procs.push(blk) if blk
  end

  def add_code(&blk); @procs.push(blk); end

  def to_s; "<Macro #{@procs.length} #{@variables.to_s}>"; end

  def call(vars = {})
    return AsmBlock.new if @procs.empty?

    @code = AsmBlock.new
    @labels = []

    # check for extraneous variables
    extra = vars.keys - @variables.keys
    raise AsmMacroError, "Extraneous variables #{extra.join(', ')}" unless extra.empty?

    # merge variable hash
    @vars = @variables.merge(vars)

    @procs.each{|b| instance_eval(&b)}
    @code
  end

  private
  def align(addr)
    begin
      @code.push(AsmAlign.new(addr))
    rescue AsmNopError => e
      parse_error "Align instruction error: #{e.to_s}"
    end
    addr
  end

  def label(name)
    parse_warn "Redefinition of label #{name}" if @labels.member? name
    begin
      @code.push(AsmLabel.new(name))
    rescue AsmNopError => e
      parse_error "Label instruction error: #{e.to_s}"
    end
    @labels.push(name)
    name
  end

  def data(arg, mode = :default)
    begin
      data = AsmData.new(arg, mode)
      @code.push(data)
    rescue AsmNopError => e
      parse_error "Data instruction error: #{e.to_s}"
    end
    data.length
  end

  def block(stuff)
    parse_error 'Block not an instance of AsmBlock' unless stuff.instance_of? AsmBlock
    @code.push(stuff)
    stuff.length
  end

  def insert(stuff)
    parse_error 'Block not an instance of AsmBlock' unless stuff.instance_of? AsmBlock
    @code += stuff
    stuff.length
  end

  def method_missing(name, *args, &blk)
    name = :and if name == :ane
    if AsmConsts::OPCODES.has_key? name
      begin
        if args.length == 0
          op = AsmOperand.new(name)
        else
          arg = args.first
          mod = args[1] or false
          op = AsmOperand.new(name, arg, mod)
        end
      rescue AsmOperandError => e
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
    log level, "(#{from}) #{msg}"
  end

  def parse_error(msg)
    say :error, msg
    raise AsmMacroError
  end

  def parse_warn(msg); say :warn, msg; end
end
