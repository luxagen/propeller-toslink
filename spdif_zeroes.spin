CON
  _clkmode = xtal1+pll16x
  _xinfreq=5000000

  SPD_SR = 48000                ' Sample rate
  SPD_CR = SPD_SR*128           ' Symbol rate

  ARRLEN=2

  preamble_b=%00010111
  preamble_m=%01000111
  preamble_w=%00100111

  SPD_PIN=0
   
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
  xmit.start(SPD_CR,SPD_PIN)

PUB init_array(array,length,patternA,patternB) | idx
  idx:=0
  repeat while idx<length
    long[array][idx++] := patternA
    long[array][idx++] := patternB
  