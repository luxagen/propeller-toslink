VAR
'  long oc_stack[128]
  long subframes[2]

  long _frqa
  long _ctra
  long _vscl
  long _pinmask
  long _vcfg

DAT
        org 0
_outcog2
        ' load parameters into special registers 
        mov temp,par
        rdlong frqa,temp
        add temp,#4
        rdlong ctra,temp
        add temp,#4
        rdlong vscl,temp
        add temp,#4
        rdlong out_mask,temp
        add temp,#4

        andn dira,out_mask ' quickly suppress output
        rdlong vcfg,temp ' enable video generator
        waitvid palette,#0 'immediately queue a buffer to keep output suppressed until we have real data

        mov counter,#1 ' initialise loop variables
        andn outa,out_mask ' suppress direct output from this cog just in case

        ' the previosu two instructions take 8 cycles, which is the WAITVID handover time; this means that the video
        ' generator should now be safely outputting the zero word we queued above, so we can re-enable its output
        or dira,out_mask

        ' Assuming that the margins in the following loop are razor-thin, we might not be able to afford the 3 extra
        ' instructions since the zero word was written, so to be safe we must queue another one just before entering
        waitvid palette,#0 

:loop
        mov temp,data1

        sub counter,#1 wz
        if_nz jmp #:preamble_xy
        mov counter,#192
        or temp,#preamble_Z
        jmp #:preamble_done
        :preamble_xy
        test counter,#1 wz
        if_z or temp,#preamble_X
        if_nz or temp,#preamble_Y
        :preamble_done
 
        waitvid palette,temp
        waitvid palette,data2
        jmp #:loop         

        data1 long %001101010011001100110011_00000000
        data2 long %00110011_001100110011001100110011

        frame long -1

        palette long $FF_00
        
        vcfg_vid long %0_01_0_0_0_000_00000000000_000_0_11111111 ' REMOVE THIS?

        ' uninitialised assembly variables
        out_mask res 1
        counter res 1
        temp res 1

        fit 496
CON
  SLOWDOWN_P2=7 ' slow down clocking by a factor of 128

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
'  _frqa := frqa_vid
'  _ctra := ctra_vid
'  _vscl := vscl_vid
'  _vcfg  := vcfg_vid
'  _pinmask := $00FF0000
  cognew(@_outcog2,@_frqa)

' /////////////////////////////////

PRI divround(x,y)
  return (x + (y/2))/y

PRI calc_frq(rate_hz) | cf_up
  return 329860360
  ' calculate 2^32 * rate_hz/clkfreq
  cf_up:=divround(CLKFREQ,|<18)
  return divround(rate_hz<<14,cf_up)

PRI calc_ctr(mode,plldiv,apin,bpin)
  return ((mode << 3 + plldiv) << 14 + bpin) << 9 + apin

PRI calc_vscl(pclks,fclks)
  return (fclks<<SLOWDOWN_P2)&((1<<12)-1) | (pclks<<(12+SLOWDOWN_P2))

PRI calc_vcfg(vmode,cmode,chroma1,chroma0,auralsub,vgroup,vpins)
  if vpins&$8
    abort VM_NONE

  return vcfg_vid|(vgroup<<9)
  return (((((((((((vmode<<1) + cmode)<<1) + chroma1)<<1) + chroma0)<<3) + auralsub)<<14) + vgroup)<<9) + vpins

PRI calc_vcfg2(pin) | vgroup,subgroup
  vgroup := pin/8
  pin//=8
  subgroup := pin/4
'  pin//=4

  return calc_vcfg(VM_COMP_BASELOW+subgroup,0,0,0,0,vgroup,1<<pin)

PRI get_preamble
  ++frame

  ifnot frame//384
    return preamble_Z
  elseif frame&1
    return preamble_Y
  else
    return preamble_X