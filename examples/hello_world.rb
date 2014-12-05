#!/usr/bin/env ruby
# encoding: utf-8
# See LICENSE.txt for licensing information.

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
require 'c64asm'

hello_world = C64Asm::Macro.new do
  block C64Asm::Basic.new('10 sys 49152').code

  align 0xc000    # 49152
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
