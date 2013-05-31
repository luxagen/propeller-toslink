VAR
  long buffer[384]
CON
  _clkmode = xtal1+pll16x
  _xinfreq=5000000

  SPD_SR = 48000                ' Sample rate
  SPD_CR = SPD_SR*128           ' Symbol rate

  DEBUGGING=false
  SPD_PIN = 1-(DEBUGGING&1)
  LG_DIVIDER = (DEBUGGING&1)<<7
   
OBJ
  xmit : "spdif_generator"

PUB Main | count

  repeat count from 0 to 383
    buffer[count] := count<<8
  
'  xmit.write(patternA,patternB)
  xmit.start(SPD_CR,SPD_PIN,LG_DIVIDER)

PUB init_array(array,length,patternA,patternB) | idx
  idx:=0
  repeat while idx<length
    long[array][idx++] := patternA
    long[array][idx++] := patternB
                                                                