CON
'  _clkmode = xtal1+pll16x
'  _xinfreq=5000000

  TransPin=16
'  EdgePin=23

  SPD_SR = 1                    ' Sample rate
  SPD_BR = SPD_SR*64            ' Symbol rate
  SPD_CR = SPD_BR*2             ' Carrier rate

  #0,CM_DISABLE,CM_PLLINT,CM_PLL,CM_PLLD,CM_NCO,CM_NCOD,CM_DUTY,CM_DUTYD,CM_POS,CM_POSF,CM_RISE,CM_RISEF,CM_NEG,CM_NEGF,CM_FALL,CM_FALLF

  #0,PLLD_1_8,PLLD_1_4,PLLD_1_2,PLLD_1,PLLD_2,PLLD_4,PLLD_8,PLLD_16

  ARRLEN=4

VAR
  long list[ARRLEN]

preamble_b              long    %00010111
preamble_m              long    %01000111
preamble_w              long    %00100111

PUB Main | idx
  longfill(@list,0,ARRLEN)
'  list[0]:=1
  list[0] := %110011001100110011001100_00000000
  list[1] := %10110010_110011001100110011001100
  list[2] := (!list[0]) & $FFFFFF00
  list[3] := !list[1]

  frqa := calc_frq(1000)
  ctra := calc_ctr(CM_PLLINT,PLLD_1_8,23,22) 

  vscl := calc_vcsl(1,32)
  vcfg:=calc_vcfg(%11,0,0,0,0,%010,$FF)

  dira := $00FF0000

  idx:=0
  repeat
    waitvid($01_02,list[idx])
    idx := (idx+1)//ARRLEN

PUB divround(x,y)
  return (x + y/2)/y

PUB calc_frq(rate_hz) | cf_up
  cf_up:=divround(CLKFREQ,65536)
  return divround(65536*rate_hz,cf_up)

PUB calc_ctr(mode,plldiv,apin,bpin)
  return ((mode << 3 + plldiv) << 14 + bpin) << 9 + apin

PUB calc_vcsl(pclks,fclks)
  return pclks<<12 | fclks

PUB calc_vcfg(vmode,cmode,chroma1,chroma0,auralsub,vgroup,vpins)
  return (((((vmode << 1 + cmode) << 1 + chroma1) << 1 + chroma0) << 3 + auralsub) << 14 + vgroup) << 9 + vpins      