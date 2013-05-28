CON
  _clkmode = xtal1+pll16x
  _xinfreq=5000000

  SPD_SR = 1000                ' Sample rate
  SPD_CR = SPD_SR*128           ' Symbol rate

  ARRLEN=2

  preamble_b=%00010111
  preamble_m=%01000111
  preamble_w=%00100111

  LED_BLUE=16
  LED_RED=14
   
OBJ
'  xmit : "transmit_bits"
  xmit : "transmit_bits_fake"

VAR
'  long list[ARRLEN]

DAT
  frame long -1

PUB Main | patternA,patternB,idx

  patternA := %001100110011001100110101_00000000
  patternB := %00110011_001100110011001100110011

  xmit.write(patternA,patternB)
  xmit.start(SPD_CR,LED_BLUE)

PUB get_preamble
  ++frame

  ifnot frame//384
    return preamble_b
  elseif frame&1
    return preamble_w
  else
    return preamble_m

PUB init_array(array,length,patternA,patternB) | idx
  idx:=0
  repeat while idx<length
    long[array][idx++] := patternA
    long[array][idx++] := patternB
  