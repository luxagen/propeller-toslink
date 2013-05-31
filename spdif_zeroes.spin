CON
  _clkmode = xtal1+pll16x
  _xinfreq=5000000

  SPD_SR = 48000                ' Sample rate
  SPD_CR = SPD_SR*128           ' Symbol rate

  ARRLEN=2

  DEBUGGING=false
  SPD_PIN = 1-(DEBUGGING&1)
   
OBJ
  xmit : "transmit_bits"
'  xmit : "transmit_bits_fake"

PUB Main | patternA,patternB,lg_div

  patternA := %000100010001_000001000001_00000000
  patternB := %00000000_01 0101010101_001001001001

  if DEBUGGING
    lg_div:=7  
  else
    lg_div:=0

  xmit.write(patternA,patternB)
  xmit.start(SPD_CR,SPD_PIN,lg_div)

PUB init_array(array,length,patternA,patternB) | idx
  idx:=0
  repeat while idx<length
    long[array][idx++] := patternA
    long[array][idx++] := patternB
                                                                