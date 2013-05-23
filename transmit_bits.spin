{
DAT
  buffer long
  bufbytes long
  counter long
  address long
  palette long
  half_frame long
        org 0
loop_asm
        mov counter,#0

:loop   mov address,buffer
        add address,counter
        rdlong half_frame,address
        waitvid palette,half_frame
        add counter,4
        cmpsub counter,bufbytes
        jmp #:loop                
'  counter := 0
'  repeat
'    waitvid($07_00,long[array][counter++ // length])
}

CON
  #0,CM_DISABLE,CM_PLLINT,CM_PLL,CM_PLLD,CM_NCO,CM_NCOD,CM_DUTY,CM_DUTYD,CM_POS,CM_POSF,CM_RISE,CM_RISEF,CM_NEG,CM_NEGF,CM_FALL,CM_FALLF

  #0,PLLD_1_8,PLLD_1_4,PLLD_1_2,PLLD_1,PLLD_2,PLLD_4,PLLD_8,PLLD_16

  #0,VM_NONE,VM_VGA,VM_COMP_BASELOW,VM_COMP_BASEHIGH

PUB init(symbol_rate,pin)
  frqa := calc_frq(symbol_rate)
  ctra := calc_ctr(CM_PLLINT,PLLD_1,0,0) 
  vscl := calc_vcsl(1,32)
  vcfg := calc_vcfg2(pin)
  dira[pin] := 1
  return

PUB send(data)
    waitvid($07_00,data)

PUB loop(array,length) | counter
'  palette:=$07_00
'  buffer:=array
'  bufbytes := 4*length
'  loop_asm
  counter := 0
  repeat
    waitvid($07_00,long[array][counter])
    ++counter
    counter//=length

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

PUB calc_vcfg2(pin) | vgroup,subgroup
  vgroup := pin/8
  pin//=8
  subgroup := pin/4
'  pin//=4

  if pin==3
    abort VM_NONE

  return calc_vcfg(VM_COMP_BASELOW+subgroup,0,0,0,0,vgroup,1<<pin)