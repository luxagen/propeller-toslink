VAR
  long oc_stack[128]
  long subframes[2]

  long _frqa
  long _ctra
  long _vscl
  long _vcfg
  long _pinmask

DAT
        org 0
_outcog2
        ' load parameters into special registers 
{        mov temp,par
        rdlong frqa,temp
        add temp,#4
        rdlong ctra,temp
        add temp,#4
        rdlong vscl,temp
        add temp,#4
        rdlong vcfg,temp
        add temp,#4
        rdlong temp,temp
        or dira,temp ' set pin direction
}

        mov frqa,frqa_preset
        mov ctra,ctra_preset
'        mov vscl,vscl_preset
'        mov vcfg,vcfg_preset

        mov temp,#1
        shl temp,#8
        sub temp,#1
        shl temp,#16
        or dira,temp
'        or outa,temp

        :bizzle
{        mov temp,#0
        mov phsa,temp
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        sub temp,#1
        mov phsa,temp
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
}        jmp :bizzle

'        or outa,temp
'        jmp #_outcog2
{
        mov temp,#1
        shl temp,#14

        or dira,temp
        or outa,temp

        jmp #_outcog2
}
        ' set up pattern
        mov data,#1
        shl data,#16
        sub data,#1

        ' set up palette
        mov palette,#$FF
        shl palette,8

:loop   waitvid palette,data
        jmp :loop         

        frame long -1
        temp long

        palette long
        data long

        frqa_preset long 53'27487791
        ctra_preset long %0_00101_000_00000000_010110_000_010111 
        vscl_preset long (1 << 12) | 32   
        vcfg_preset long %0_01_0_0_0_000_00000000000_010_0_11111111

        fit 496
CON
  #0,CM_DISABLE,CM_PLLINT,CM_PLL,CM_PLLD,CM_NCO,CM_NCOD,CM_DUTY,CM_DUTYD,CM_POS,CM_POSF,CM_RISE,CM_RISEF,CM_NEG,CM_NEGF,CM_FALL,CM_FALLF

  #0,PLLD_1_8,PLLD_1_4,PLLD_1_2,PLLD_1,PLLD_2,PLLD_4,PLLD_8,PLLD_16

  #0,VM_NONE,VM_VGA,VM_COMP_BASELOW,VM_COMP_BASEHIGH

  preamble_b=%00010111
  preamble_m=%01000111
  preamble_w=%00100111

PUB write(subframeA,subframeB)
  subframes[0] := subframeA
  subframes[1] := subframeB

PRI _outcog(carrier_rate,pin) | tempA,tempB
  frqa := _frqa
  ctra := _ctra
  vscl := _vscl
  vcfg := _vcfg
  dira |= _pinmask

  repeat
    tempA := subframes[0]
    tempB := subframes[1]
    waitvid($07_00,tempA)'get_preamble|tempA)
    waitvid($07_00,tempB)

PUB start(carrier_rate,pin)
  init2(carrier_rate,pin)
'  cognew(_outcog(carrier_rate,pin),@oc_stack)
  cognew(@_outcog2,@_frqa)

' /////////////////////////////////

PRI init2(symbol_rate,pin)
  _frqa := calc_frq(symbol_rate)
  _ctra := calc_ctr(CM_PLLINT,PLLD_1,0,0) 
  _vscl := calc_vcsl(1,32)
  _vcfg := calc_vcfg2(pin)
  _pinmask := |<pin

PRI divround(x,y)
  return (x + (y/2))/y

PRI calc_frq(rate_hz) | cf_up
  ' calculate 2^32 * rate_hz/clkfreq
  cf_up:=divround(CLKFREQ,|<18)
  return divround(rate_hz<<14,cf_up)

PRI calc_ctr(mode,plldiv,apin,bpin)
  return ((mode << 3 + plldiv) << 14 + bpin) << 9 + apin

PRI calc_vcsl(pclks,fclks)
  return pclks<<12 | fclks

PRI calc_vcfg(vmode,cmode,chroma1,chroma0,auralsub,vgroup,vpins)
  return (((((((((((vmode<<1) + cmode)<<1) + chroma1)<<1) + chroma0)<<3) + auralsub)<<14) + vgroup)<<9) + vpins

PRI calc_vcfg2(pin) | vgroup,subgroup
  vgroup := pin/8
  pin//=8
  subgroup := pin/4
'  pin//=4

  if pin==3
    abort VM_NONE

  return calc_vcfg(VM_COMP_BASELOW+subgroup,0,0,0,0,vgroup,1<<pin)

PRI get_preamble
  ++frame

  ifnot frame//384
    return preamble_b
  elseif frame&1
    return preamble_w
  else
    return preamble_m