load 'asm.rb'

#hello_world = AsmMacro.new do
#  jsr 0xe544 # clear
#  ldx.d 0
#  label :read
#  lda.ax :msg
#  cmp.d 35
#  beq :finish
#  jsr 0xffd2 # chrout
#  inx
#  jmp :read
#  label :finish
#  rts
#  label :msg
#  data "HELLO WORLD#"
#end
#code = hello_world.call
#puts code.to_source.join("\n")
#STDOUT.write(AsmLinker.link(code))

demo = AsmMacro.new do
  charofs = 39
  endpos = 16
  scol = 0
  bcol = 1

  rbars = 0x20
  rbare = 0x21
  rmode = 0x22
  lineofs = 0x23
  scrpos = 0x24
  textpos = 0x25
  counter = 0x26

  textptr = 0x27
  scrptr = 0x29
  colorptr = 0x2b

  lda.d   140
  sta     rbars
  lda.d   149
  sta     rbare
  lda.d   0
  sta     rmode
  sta     counter
  sta     lineofs
  lda     0x400
  sta     scrptr
  lda     0xd800
  sta     colorptr

  jsr     0xe544

  lda.d   0x1b
  sta     0xd011

  lda.d   0x08
  sta     0xd016

  lda.d   0x14
  sta     0xd018

  sei

  lda.d   0x7f
  sta     0xdc0d
  sta     0xdd0d

  lda     0xd01a
  ora.d   1
  sta     0xd01a

  lda     :rtr_int, :<
  sta     0x314
  lda     :rtr_int, :>
  sta     0x315

  lda     0xd011
  ane.d   0x7f
  sta     0xd011

  lda     rbars
  sta     0xd012

  cli

  label   :start

  ldx.d   10
  jsr     :sub_wait

  label   :barup

  ldx.d   1
  jsr :sub_wait

  dec rbars
  dec rbare
  lda rbars
  cmp.d 49
  bne :barup

  ldx.d 8
  jsr :sub_wait

  lda :textdata, :<
  sta textptr
  lda :textdata, :>
  sta textptr+1

  jsr :textgun

  label :infloop
  jmp :infloop

  label :textgun

  block(AsmMacro.new do
    ldx.d endpos
    stx lineofs
    ldx.d charofs
    ldy.d 0

    label :wpre

    lda counter
    cmp.d 1
    bne :wpre

    lda.d 0x20
    label :uno
    sta.ax 0x400

    label :wpo

    lda counter
    cmp.d 1
    bne :wpo

    dex

    label :put_char

    lda.zyr textptr
    bmi :end
    cmp.d 0x20
    beq :skip_char
    cmp.d 35
    beq :next_line
    label :dos
    sta.ax 0x400
    cpx lineofs
    bne :end_char

    inc lineofs
    ldx.d charofs
    iny

    label :end_char

    lda.d 0
    sta counter

    jmp :wpre

    label :skip_char

    inc lineofs
    ldx.d charofs
    iny

    lda.d 0
    sta counter

    jmp :wpre

    label :next_line

    txa
    pha
    ldx.d 7

    label :rbardown

    lda counter
    cmp.d 1
    bne :rbardown

    lda.d 0
    sta counter

    inc rbare
    dex
    bpl :rbardown

    pla
    tax
    
    lda :uno, +1
    clc
    adc.d 40
    bcc :skip_high

    pha
    lda :uno, +2
    clc
    adc.d 1
    sta :uno, +2
    sta :dos, +2
    pla

    label :skip_high

    sta :uno, +1
    sta :dos, +1

    lda.d endpos
    sta lineofs
    ldx.d charofs
    iny

    lda.d 0
    sta counter
    jmp :wpre

    label :end
    rts
  end.call)

  label :sub_wait

  block(AsmMacro.new do
    label :wl

    cpx counter
    bne :wl
    lda.d 0
    sta counter
    rts
  end.call)

  label :textdata
  [
    "#this is a test#",
    "#",
    "of some data test#",
    "test @ test.com 123#"
  ].each{|s| data s, :screen}
  data [0xff]

  align   0x4000

  label :rtr_int

  block(AsmMacro.new do
    ldx   0xd012
    inx
    stx   0xd012
    lda   :rtr_sync, :<
    sta   0x314
    asl   0xd019
    cli
    10.times.each{nop}

    label :rtr_sync

    nop
    cpx   0xd012
    bne   :*, +2

    label :rtr_branch

    lda rmode
    bne :rtr_mode_e

    label :rtr_mode_s
    lda.d 1
    sta rmode

    lda.d scol
    sta 0xd020
    sta 0xd021

    lda rbars
    sta 0xd012

    jmp :rtr_end

    label :rtr_mode_e
    
    lda.d 0
    sta rmode

    lda.d bcol
    sta 0xd020
    sta 0xd021

    lda rbare
    sta 0xd012
 
    label :rtr_end

    inc counter
    asl   0xd019
    pla
    tay
    pla
    tax
    pla
    rti
  end.call)
end
code = demo.call
STDOUT.puts(code.to_source.join("\n"))
STDERR.write(code.to_binary)
