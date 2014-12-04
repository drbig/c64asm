require File.expand_path('../lib/c64asm/version', __FILE__)

Gem::Specification.new do |s|
  s.name          = 'c64asm'
  s.version       = C64Asm::VERSION
  s.date          = Time.now

  s.summary       = %q{Data-driven verbose DSL (almost dis-)assembler for MOS6502 with focus on Commoder 64}
  s.description   = %q{Already two-year-old project inspirated by the NES assembler written in Lisp. The assembly DSL lets you easily unroll loops, create screen maps on the fly and just hack the thing. As you write a plain .prg file you may also dump the code to a very verbose format to ponder the machine code.}
  s.license       = 'BSD'
  s.authors       = ['Piotr S. Staszewski']
  s.email         = 'p.staszewski@gmail.com'
  s.homepage      = 'https://github.com/drbig/c64asm'

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ['lib']
  
  s.required_ruby_version = '>= 1.8.7' # rather tentative
end
