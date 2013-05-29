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
  xmit : "transmit_bits"
'  xmit : "transmit_bits_fake"

VAR
'  long list[ARRLEN]

DAT
  frame long -1

PUB Main | patternA,patternB,idx

  patternA := %000100010001_000001000001_00000000
  patternB := %00000000_010101010101_001001001001

  xmit.write(patternA,patternB)
  xmit.start(4000,LED_BLUE)

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
  