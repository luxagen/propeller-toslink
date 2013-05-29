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

{
        mov frqa,frqa_tone
        mov ctra,ctra_tone
 }       

        mov frqa,frqa_vid
        mov ctra,ctra_vid
        mov vscl,vscl_vid
        mov vcfg,vcfg_vid

        mov temp,par
        add temp,#16
        rdlong temp,temp
        or dira,temp
        or outa,temp
'        or dira,out_mask
'        or outa,led_mask

':loop
'        mov temp,data1
        mov temp,#preamble_Z
{
        sub counter,#1 wz
        if_nz jmp :preamble_xy
        mov counter,#192
        or temp,#preamble_Z
        jmp :preamble_done
        :preamble_xy
        test counter,#1 wz
        if_z or temp,#preamble_X
        if_nz or temp,#preamble_Y
        :preamble_done
 }

        mov temp,#$AA
        shl temp,#8
        or temp,#$AA
        shl temp,#8
        or temp,#$AA
        shl temp,#8
        or temp,#$AA

        mov temp,#1
        test temp,#1 wc
        rcr temp,#16
        rcr temp,#16

        mov temp,#$0F
:loop
        waitvid palette,temp
        jmp #:loop         

        frame long -1
        temp long

        palette long $FF_00
        zeroes long 0
'        data1 long %00000000_00000000_11111111_11111111
'        data2 long %00000000_11111111_00000000_11111111
        data1 long %00110011_00110011_00110101_00000000
        data2 long %00110011_00110011_00110011_00110011

        frqa_tone long 53
        ctra_tone long %0_00101_000_00000000_010110_000_010111

        ' run the NCO at the intended output frequency of ~5 MHz - the PLL will multiply this to ~90 MHz, and the
        ' PLLDIV field will divide back to the intended rate
        frqa_vid long 303063888
        ctra_vid long %0_00001_011_00000000_000000_000_000000 
        vscl_vid long ((1 << 12) | 32)<<7 ' the 7 slows it to the audio rate for testing
        
        vcfg_vid long %0_01_0_0_0_000_00000000000_001_0_11111111

        out_mask long $0000FF00

        counter long 1

        fit 496
CON
  #0,CM_DISABLE,CM_PLLINT,CM_PLL,CM_PLLD,CM_NCO,CM_NCOD,CM_DUTY,CM_DUTYD,CM_POS,CM_POSF,CM_RISE,CM_RISEF,CM_NEG,CM_NEGF,CM_FALL,CM_FALLF

  #0,PLLD_1_8,PLLD_1_4,PLLD_1_2,PLLD_1,PLLD_2,PLLD_4,PLLD_8,PLLD_16

  #0,VM_NONE,VM_VGA,VM_COMP_BASELOW,VM_COMP_BASEHIGH

  preamble_Z=%00010111
  preamble_Y=%00100111
  preamble_X=%01000111

PUB write(subframeA,subframeB)
  subframes[0] := subframeA
  subframes[1] := subframeB

PUB start(carrier_rate,pin)
  _frqa := calc_frq(carrier_rate)
  _ctra := calc_ctr(CM_PLLINT,PLLD_1,0,0) 
  _vscl := calc_vscl(1,32)
  _vcfg := calc_vcfg2(pin)
  _pinmask := |<pin
  cognew(@_outcog2,@_frqa)

' /////////////////////////////////

PRI divround(x,y)
  return (x + (y/2))/y

PRI calc_frq(rate_hz) | cf_up
  ' calculate 2^32 * rate_hz/clkfreq
  cf_up:=divround(CLKFREQ,|<18)
  return divround(rate_hz<<14,cf_up)

PRI calc_ctr(mode,plldiv,apin,bpin)
  return ((mode << 3 + plldiv) << 14 + bpin) << 9 + apin

PRI calc_vscl(pclks,fclks)
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
    return preamble_Z
  elseif frame&1
    return preamble_Y
  else
    return preamble_X