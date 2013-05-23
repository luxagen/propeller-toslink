CON
  _clkmode = xtal1+pll16x
  _xinfreq=5000000

  SPD_SR = 48000                ' Sample rate
  SPD_CR = SPD_SR*128           ' Symbol rate

  ARRLEN=384

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
'  xmit : "transmit_bits_fake"

VAR
  long list[ARRLEN]

DAT
  frame long -1

PUB Main | patternA,patternB,idx

  patternA := %110011001100110011001101_00000000
  patternB := %00110010_110011001100110011001100

  init_array(@list,192,patternA,patternB)

  xmit.init(SPD_CR,16)

'  repeat
'    xmit.send(list[0]|get_preamble)
'    xmit.send(list[1])

  xmit.loop(@list,ARRLEN)

PUB get_preamble
  ++frame

  ifnot frame//192
    return preamble_b
  elseif frame&1
    return preamble_w
  else
    return preamble_m

PUB init_array(array,length,patternA,patternB) | idx
  idx:=0
  repeat while idx<384
    long[array][idx++] := patternA|get_preamble
    long[array][idx++] := patternB
  