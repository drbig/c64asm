require 'logger'

class Object
  @@logger = false
  def self.logger; @@logger; end
  def self.logger=(obj); @@logger = obj; end
  def log(level, msg); @@logger.send(level, msg) if @@logger; end
  def crap(msg, e)
    return unless @@logger
    @@logger.error(msg)
    @@logger.error(e.to_s)
    @@logger.error(e.backtrace.join("\n"))
  end
  def die(msg, e = nil)
    if @@logger
      crap(msg, e) if e
      @@logger.fatal(msg)
    else
      STDERR.puts "FATAL ERROR: #{msg}"
    end
    exit(5)
  end
end

module ObjLogger
  @present = false

  def self.setup(level = 0, target = false)
    return Object.logger if @present
    target = STDERR unless target
    Object.logger = Logger.new(target)
    Object.logger.level = level
    Object.logger.formatter = proc { |s,d,p,m| "#{d.strftime('%H:%M:%S')} (#{s.ljust(7)}) > #{m}\n" }
    @present = true
    Object.logger
  end
end
