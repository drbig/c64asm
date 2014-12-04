# c64asm [![Yard Docs](http://img.shields.io/badge/yard-docs-blue.svg)](http://www.rubydoc.info/github/drbig/c64asm/master)

A MOS6502 assembler as a Ruby DLS, with focus on the Commodore 64.

Features:

- You write MOS6502 assembly naturally but still have full power of Ruby (it's awesome)
- Macros with variables as the basic building block
- C64 BASIC compiler built in
- Data driven with a generating tool, I *didn't write* data.rb
- Can output a source code representation (that I believe I've based upon some well known and established assembler)
- Can output a disassembler-like output, useful for cycle counting

Bugs:
- No test suite
- I believe my 'scrape opcodes table' approach missed some edge cases

Todo:
- More C64 helpers, e.g. bank switching helpers and a hash of named addresses
- Not far away from adding a basic CPU simulator (note: this is far from an emulator)

*I've written the bulk of it more than two years ago. I got to a rather cosy state of overall functionality, but I believe it misses some edge-cases. Please feel free to go nuts hacking it!*

# Showcase

Got the gem, in the examples folder:

    $ cat hello_world.rb 
    #!/usr/bin/env ruby
    # encoding: utf-8
    # See LICENSE.txt for licensing information.
    
    $LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
    require 'c64asm'
    
    hello_world = C64Asm::Macro.new do
      block C64Asm::Basic.new('10 sys 49153').code
    
      align 0xc000    # 49153
      jsr 0xe544      # clear
      ldx.d 0         # string index
      label :load
      lda.ax :msg     # load character
      cmp.d 35        # hash is the end of line
      beq :finish     # if so we're done
      jsr 0xffd2      # chrout
      inx             # increment index
      jmp :load       # if not load the next character
      label :finish
      rts             # back to basic(s)
      label :msg
      data "HELLO WORLD#"
    end
    
    code = hello_world.call         # compile the macro
    puts code.dump                  # print detailed
    #puts code.to_source            # just the source code
    code.write!('hello_world.prg')  # save to a standard .prg file
    

Let's run it:

    $ ./hello_world.rb 
    $0801                   .block
    $0801                   .block
    $0801                   * = $801
    $0801   .. .. ..        .byte $3,$8,$a,$0,$9e,$20,$34,$39,$31,$35,$33,$0,$0,$0
    $080f                   .bend
    $080F                   * = $c000
    $C000   20 44 E5        jsr $e544
    $C003   A2 00           ldx #$0
    $C005              load
    $C005   BD 14 C0        lda msg,x
    $C008   C9 23           cmp #$23
    $C00A   F0 07           beq finish
    $C00C   20 D2 FF        jsr $ffd2
    $C00F   E8              inx
    $C010   4C 05 C0        jmp load
    $C013              finish
    $C013   60              rts
    $C014              msg
    $C014   .. .. ..        .text "HELLO WORLD#"
    $c020                   .bend

And run the compiled .prg with VICE:

    $ x64 hello_world.prg

![Hello world](https://raw.github.com/drbig/c64asm/master/examples/hello_world.png)

- - -

And an old demo screenshot, source not distributed 'cause it sucks, but it does compile under this gem:

    $ ruby 04.rb.3
    $ x64 04.prg

![I guess that's the fourth demo third revision](https://raw.github.com/drbig/c64asm/master/examples/04.png)

And it moves and stuff (no sound though), you can grab the .prg [here](https://raw.github.com/drbig/c64asm/master/examples/04.prg) and see the whole thing. The big ugly numbers are sprites - I assume the point was to make them move and be interesting, oh well.

Also my raster bar code is flawed.

## Additional notes

First compiler. Also I believe that'd be my second/third non-trivial Ruby project. I'm also by no means a C64 hacker, but I appreciate the platform very much. It was fun, even this get-this-public-now work.

This project has been inspired by a blog post of person that did a NES assembler in Common Lisp (kudos to the author!).

## Contributing

Follow the usual GitHub development model:

1. Clone the repository
2. Make your changes on a separate branch
4. Make a pull request

See licensing for legalese.

## Licensing

Standard two-clause BSD license, see LICENSE.txt for details.

Any contributions will be licensed under the same conditions.

Copyright (c) 2012 - 2014 Piotr S. Staszewski
