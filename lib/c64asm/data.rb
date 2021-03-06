# encoding: utf-8
# See LICENSE.txt for licensing information.

module C64Asm
  # Known addressing modes
  ADDR_MODES = {
    :n => { :src => '', :len => 0 },
    :d => { :src => ' #%s', :len => 1},
    :z => { :src => ' %s', :len => 1},
    :zx => { :src => ' %s,x', :len => 1},
    :zy => { :src => ' %s,y', :len => 1},
    :zxr => { :src => ' (%s,z)', :len => 1},
    :zyr => { :src => ' (%s),y', :len => 1},
    :a => { :src => ' %s', :len => 2},
    :ax => { :src => ' %s,x', :len => 2},
    :ay => { :src => ' %s,y', :len => 2},
    :ar => { :src => ' (%s)', :len => 2},
    :r => { :src => ' %s', :len => 1},
    :e => { :src => '', :len => 1}
  }

  # Known operands
  OP_CODES = {
    :adc=>{:d=>{:byte=>105, :cycles=>2},
           :z=>{:byte=>101, :cycles=>3},
           :zx=>{:byte=>117, :cycles=>4},
           :zxr=>{:byte=>97, :cycles=>6},
           :zyr=>{:byte=>113, :cycles=>5, :page=>true},
           :a=>{:byte=>109, :cycles=>4},
           :ax=>{:byte=>125, :cycles=>4, :page=>true},
           :ay=>{:byte=>121, :cycles=>4, :page=>true}},
    :and=>{:d=>{:byte=>41, :cycles=>2},
           :z=>{:byte=>37, :cycles=>3},
           :zx=>{:byte=>53, :cycles=>4},
           :zxr=>{:byte=>33, :cycles=>6},
           :zyr=>{:byte=>49, :cycles=>5, :page=>true},
           :a=>{:byte=>45, :cycles=>4},
           :ax=>{:byte=>61, :cycles=>4, :page=>true},
           :ay=>{:byte=>41, :cycles=>4, :page=>true},
           :e=>{:cycles=>2}},
    :asl=>{:z=>{:byte=>6, :cycles=>5},
           :zx=>{:byte=>22, :cycles=>6},
           :a=>{:byte=>14, :cycles=>6},
           :ax=>{:byte=>30, :cycles=>7},
           :e=>{:byte=>10}},
    :bcc=>{:r=>{:byte=>144, :cycles=>2, :page=>true, :branch=>true}},
    :bcs=>{:r=>{:byte=>176, :cycles=>2, :page=>true, :branch=>true}},
    :beq=>{:r=>{:byte=>240, :cycles=>2, :page=>true, :branch=>true}},
    :bit=>{:d=>{:byte=>36, :cycles=>3}, :zyr=>{:byte=>44, :cycles=>4}},
    :bmi=>{:r=>{:byte=>48, :cycles=>2, :page=>true, :branch=>true}},
    :bne=>{:r=>{:byte=>208, :cycles=>2, :page=>true, :branch=>true}},
    :bpl=>{:r=>{:byte=>16, :cycles=>2, :page=>true, :branch=>true}},
    :brk=>{:n=>{:byte=>0, :cycles=>7}},
    :bvc=>{:r=>{:byte=>80, :cycles=>2, :page=>true, :branch=>true}},
    :bvs=>{:r=>{:byte=>112, :cycles=>2, :page=>true, :branch=>true}},
    :clc=>{:n=>{:byte=>24, :cycles=>2}},
    :cld=>{:n=>{:byte=>216, :cycles=>2}},
    :cli=>{:n=>{:byte=>88, :cycles=>2}},
    :clv=>{:n=>{:byte=>184, :cycles=>2}},
    :cmp=>{:d=>{:byte=>201, :cycles=>2},
           :z=>{:byte=>197, :cycles=>3},
           :zx=>{:byte=>213, :cycles=>4},
           :zxr=>{:byte=>193, :cycles=>6},
           :zyr=>{:byte=>209, :cycles=>5, :page=>true},
           :a=>{:byte=>205, :cycles=>4},
           :ax=>{:byte=>221, :cycles=>4, :page=>true},
           :ay=>{:byte=>217, :cycles=>4, :page=>true}},
    :cpx=>{:d=>{:byte=>224, :cycles=>2},
           :z=>{:byte=>228, :cycles=>3},
           :a=>{:byte=>236, :cycles=>4}},
    :cpy=>{:d=>{:byte=>192, :cycles=>2},
           :z=>{:byte=>196, :cycles=>3},
           :a=>{:byte=>204, :cycles=>4}},
    :dec=>{:z=>{:byte=>198, :cycles=>5},
           :zx=>{:byte=>214, :cycles=>6},
           :a=>{:byte=>206, :cycles=>6},
           :ax=>{:byte=>222, :cycles=>7}},
    :dex=>{:n=>{:byte=>202, :cycles=>2}},
    :dey=>{:n=>{:byte=>136, :cycles=>2}},
    :eor=>{:d=>{:byte=>73, :cycles=>2},
           :z=>{:byte=>69, :cycles=>3},
           :zx=>{:byte=>85, :cycles=>4},
           :zxr=>{:byte=>65, :cycles=>6},
           :zyr=>{:byte=>81, :cycles=>5, :page=>true},
           :a=>{:byte=>77, :cycles=>4},
           :ax=>{:byte=>93, :cycles=>4, :page=>true},
           :ay=>{:byte=>89, :cycles=>4, :page=>true}},
    :inc=>{:z=>{:byte=>230, :cycles=>5},
           :zx=>{:byte=>246, :cycles=>6},
           :a=>{:byte=>238, :cycles=>6},
           :ax=>{:byte=>254, :cycles=>7}},
    :inx=>{:n=>{:byte=>232, :cycles=>2}},
    :iny=>{:n=>{:byte=>200, :cycles=>2}},
    :jmp=>{:a=>{:byte=>76, :cycles=>3}, :ar=>{:byte=>108, :cycles=>5}},
    :jsr=>{:a=>{:byte=>32, :cycles=>6}},
    :lda=>{:d=>{:byte=>169, :cycles=>2},
           :z=>{:byte=>165, :cycles=>3},
           :zx=>{:byte=>181, :cycles=>4},
           :zxr=>{:byte=>161, :cycles=>6},
           :zyr=>{:byte=>177, :cycles=>5, :page=>true},
           :a=>{:byte=>173, :cycles=>4},
           :ax=>{:byte=>189, :cycles=>4, :page=>true},
           :ay=>{:byte=>185, :cycles=>4, :page=>true}},
    :ldx=>{:d=>{:byte=>162, :cycles=>2},
           :z=>{:byte=>166, :cycles=>3},
           :zy=>{:byte=>182, :cycles=>4},
           :a=>{:byte=>174, :cycles=>4},
           :ay=>{:byte=>190, :cycles=>4, :page=>true}},
    :ldy=>{:d=>{:byte=>160, :cycles=>2},
           :z=>{:byte=>164, :cycles=>3},
           :zx=>{:byte=>180, :cycles=>4},
           :a=>{:byte=>172, :cycles=>4},
           :ax=>{:byte=>188, :cycles=>4, :page=>true}},
    :lsr=>{:z=>{:byte=>70, :cycles=>5},
           :zx=>{:byte=>86, :cycles=>6},
           :a=>{:byte=>78, :cycles=>6},
           :ax=>{:byte=>94, :cycles=>7},
           :e=>{:byte=>74, :cycles=>2}},
    :nop=>{:n=>{:byte=>234, :cycles=>2}},
    :ora=>{:d=>{:byte=>9, :cycles=>2},
           :z=>{:byte=>5, :cycles=>3},
           :zx=>{:byte=>21, :cycles=>4},
           :zxr=>{:byte=>1, :cycles=>6},
           :zyr=>{:byte=>17, :cycles=>5, :page=>true},
           :a=>{:byte=>13, :cycles=>4},
           :ax=>{:byte=>29, :cycles=>4, :page=>true},
           :ay=>{:byte=>25, :cycles=>4, :page=>true}},
    :pha=>{:n=>{:byte=>72, :cycles=>3}},
    :php=>{:n=>{:byte=>8, :cycles=>3}},
    :pla=>{:n=>{:byte=>104, :cycles=>4}},
    :plp=>{:n=>{:byte=>40, :cycles=>4}},
    :rol=>{:z=>{:byte=>38, :cycles=>5},
           :zx=>{:byte=>54, :cycles=>6},
           :a=>{:byte=>46, :cycles=>6},
           :ax=>{:byte=>62, :cycles=>7},
           :e=>{:byte=>42, :cycles=>2}},
    :ror=>{:z=>{:byte=>102, :cycles=>5},
           :zx=>{:byte=>118, :cycles=>6},
           :a=>{:byte=>110, :cycles=>6},
           :ax=>{:byte=>126, :cycles=>7},
           :e=>{:byte=>106, :cycles=>2}},
    :rti=>{:n=>{:byte=>64, :cycles=>6}},
    :rts=>{:n=>{:byte=>96, :cycles=>6}},
    :sbc=>{:d=>{:byte=>233, :cycles=>2},
           :z=>{:byte=>229, :cycles=>3},
           :zx=>{:byte=>245, :cycles=>4},
           :zxr=>{:byte=>225, :cycles=>6},
           :zyr=>{:byte=>241, :cycles=>5, :page=>true},
           :a=>{:byte=>237, :cycles=>4},
           :ax=>{:byte=>253, :cycles=>4, :page=>true},
           :ay=>{:byte=>233, :cycles=>4, :page=>true}},
    :sec=>{:n=>{:byte=>56, :cycles=>2}},
    :sed=>{:n=>{:byte=>248, :cycles=>2}},
    :sei=>{:n=>{:byte=>120, :cycles=>2}},
    :sta=>{:z=>{:byte=>133, :cycles=>3},
           :zx=>{:byte=>149, :cycles=>4},
           :zxr=>{:byte=>129, :cycles=>6},
           :zyr=>{:byte=>145, :cycles=>6},
           :a=>{:byte=>141, :cycles=>4},
           :ax=>{:byte=>157, :cycles=>5},
           :ay=>{:byte=>153, :cycles=>5}},
    :stx=>{:z=>{:byte=>134, :cycles=>3},
           :zy=>{:byte=>150, :cycles=>4},
           :a=>{:byte=>142, :cycles=>4}},
    :sty=>{:z=>{:byte=>132, :cycles=>3},
           :zx=>{:byte=>148, :cycles=>4},
           :a=>{:byte=>140, :cycles=>4}},
    :tax=>{:n=>{:byte=>170, :cycles=>2}},
    :tay=>{:n=>{:byte=>168, :cycles=>2}},
    :tsx=>{:n=>{:byte=>186, :cycles=>2}},
    :txa=>{:n=>{:byte=>138, :cycles=>2}},
    :txs=>{:n=>{:byte=>154, :cycles=>2}},
    :tya=>{:n=>{:byte=>152, :cycles=>2}}}

  # Character map
  CHAR_MAP = {
    64=>0, 65=>1, 66=>2, 67=>3, 68=>4, 69=>5, 70=>6, 71=>7, 72=>8, 73=>9, 74=>10, 75=>11, 76=>12,
    77=>13, 78=>14, 79=>15, 80=>16, 81=>17, 82=>18, 83=>19, 84=>20, 85=>21, 86=>22, 87=>23, 88=>24,
    89=>25, 90=>26, 91=>27, 163=>28, 93=>29, 8593=>30, 8592=>31, 32=>32, 33=>33, 34=>34, 35=>35,
    36=>36, 37=>37, 38=>38, 39=>39, 40=>40, 41=>41, 42=>42, 43=>43, 44=>44, 45=>45, 46=>46, 47=>47,
    48=>48, 49=>49, 50=>50, 51=>51, 52=>52, 53=>53, 54=>54, 55=>55, 56=>56, 57=>57, 58=>58, 59=>59,
    60=>60, 61=>61, 62=>62, 63=>63
  }

  # PETSCII map
  PETSCII = {
    32=>32, 160=>224, 38=>38, 33=>33, 34=>34, 35=>35, 36=>36, 37=>37, 39=>39, 40=>40, 41=>41, 42=>42,
    43=>43, 44=>44, 45=>45, 46=>46, 47=>47, 48=>48, 49=>49, 50=>50, 51=>51, 52=>52, 53=>53, 54=>54,
    55=>55, 56=>56, 57=>57, 58=>58, 59=>59, 61=>61, 62=>62, 63=>63, 64=>64, 65=>65, 66=>66, 67=>67,
    68=>68, 69=>69, 70=>70, 71=>71, 72=>72, 73=>73, 74=>74, 75=>75, 76=>76, 77=>77, 78=>78, 79=>79,
    80=>80, 81=>81, 82=>82, 83=>83, 84=>84, 85=>85, 86=>86, 87=>87, 88=>88, 89=>89, 90=>90, 91=>91,
    92=>92, 93=>93, 94=>94, 95=>95, 96=>96, 97=>97, 98=>98, 99=>99, 100=>100, 101=>101, 102=>102,
    103=>103, 104=>104, 105=>105, 106=>106, 107=>107, 108=>108, 109=>109, 110=>110, 111=>111, 112=>112,
    113=>113, 114=>114, 115=>115, 116=>116, 117=>117, 118=>118, 119=>119, 120=>120, 121=>121, 122=>122,
    123=>123, 124=>124, 125=>125, 126=>126, 127=>127, 61700=>129, 61712=>133, 61714=>134, 61716=>135,
    61718=>136, 61713=>137, 61715=>138, 61717=>139, 61719=>140, 10=>141, 61701=>144, 61726=>145, 61723=>146,
    61729=>148, 61702=>149, 61703=>150, 61704=>151, 61705=>152, 61706=>153, 61707=>154, 61708=>155, 61709=>156,
    61725=>157, 61710=>158, 61711=>159, 9612=>225, 9604=>226, 9620=>227, 9601=>228, 9615=>229, 9618=>230,
    9621=>231, 61743=>232, 9700=>233, 61744=>234, 9500=>235, 61748=>236, 9492=>237, 9488=>238, 9602=>239,
    9484=>240, 9524=>241, 9516=>242, 9508=>243, 9614=>244, 9613=>245, 61745=>246, 61746=>247, 61747=>248,
    9603=>249, 61741=>250, 61749=>251, 61750=>252, 9496=>253, 61751=>254, 61752=>191, 9473=>195, 9824=>193,
    9474=>221, 61730=>196, 61731=>197, 61732=>198, 61734=>199, 61736=>200, 9582=>201, 9584=>202, 9583=>203,
    61738=>204, 9586=>205, 9585=>206, 61739=>207, 61740=>208, 9679=>209, 61733=>210, 9829=>211, 61735=>212,
    9581=>213, 9587=>214, 9675=>215, 9827=>216, 61737=>217, 9830=>218, 9532=>219, 61742=>220, 960=>255,
    9701=>223
  }

  # Basic commands
  BASIC = {
    "END"=>128, "FOR"=>129, "NEXT"=>130, "DATA"=>131, "INPUT#"=>132, "INPUT"=>133, "DIM"=>134, "READ"=>135,
    "LET"=>136, "GOTO"=>137, "RUN"=>138, "IF"=>139, "RESTORE"=>140, "GOSUB"=>141, "RETURN"=>142, "REM"=>143,
    "STOP"=>144, "ON"=>145, "WAIT"=>146, "LOAD"=>147, "SAVE"=>148, "VERIFY"=>149, "DEF"=>150, "POKE"=>151,
    "PRINT#"=>152, "PRINT"=>153, "CONT"=>154, "LIST"=>155, "CLR"=>156, "CMD"=>157, "SYS"=>158, "OPEN"=>159,
    "CLOSE"=>160, "GET"=>161, "NEW"=>162, "TAB("=>163, "TO"=>164, "FN"=>165, "SPC("=>166, "THEN"=>167,
    "NOT"=>168, "STEP"=>169, "+"=>170, "-"=>171, "*"=>172, "/"=>173, "^"=>174, "AND"=>175, "OR"=>176,
    ">"=>177, "="=>178, "<"=>179, "SGN"=>180, "INT"=>181, "ABS"=>182, "USR"=>183, "FRE"=>184, "POS"=>185,
    "SQR"=>186, "RND"=>187, "LOG"=>188, "EXP"=>189, "COS"=>190, "SIN"=>191, "TAN"=>192, "ATN"=>193,
    "PEEK"=>194, "LEN"=>195, "STR$"=>196, "VAL"=>197, "ASC"=>198, "CHR$"=>199, "LEFT$"=>200, "RIGHT$"=>201,
    "MID$"=>202, "GO"=>203
  }
end
