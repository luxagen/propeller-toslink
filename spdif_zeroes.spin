CON
  _clkmode = xtal1+pll16x
  _xinfreq=5000000

  SPD_SR = 1                    ' Sample rate
  SPD_CR = SPD_SR*128           ' Symbol rate

  ARRLEN=2

  preamble_b=%00010111
  preamble_m=%01000111
  preamble_w=%00100111

{
DAT
        org

GetPreamble
        cmp frame_no,0 wz
        if_z   

frame_no      byte      0
preambles     word      %0010011100010111,%0010011101000111[95]                 ' Preamble sequence for one block   
}

OBJ
  xmit : "transmit_bits"

VAR
  long list[ARRLEN]

PUB Main | idx,vmode,symbol_rate,pin

'  longfill(@list,0,ARRLEN)
'  list[0] := %110011001100110011001101_00000000
'  list[1] := %00110010_110011001100110011001100

  list[0] := 1
  list[1] := 0

  xmit.init(1000,16)

  idx:=0
  repeat
    xmit.send(list[0]|get_preamble(idx))
    xmit.send(list[1])
    idx := (idx+1)//ARRLEN

PUB get_preamble(idx)
  ifnot idx//192
    return preamble_b
  elseif idx&1
    return preamble_w
  else
    return preamble_m