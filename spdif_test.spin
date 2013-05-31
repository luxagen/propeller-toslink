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
  spdif : "spdif_generator"

PUB Main | count,sample,pos

  sample := -50 

  repeat count from 0 to 191
    buffer[2*count] := mksmp16(sample)
    buffer[2*count + 1] := mksmp16(sample)

  ++sample
                                                                                             
  buffer[382] := mksmp16(+500)
  buffer[383] := mksmp16(-500)
  
  spdif.start(SPD_CR,SPD_PIN,LG_DIVIDER,@buffer,@pos)

'  repeat until (pos//384)>32
'  repeat until (pos//384)<32

  pos:=0

  repeat
'    repeat count from 0 to 191 
'      repeat until (pos//192)<>count
'      buffer[2*count] := mksmp16(sample)
'      buffer[2*count + 1] := mksmp16(sample)
'    ++sample 

  spdif.stop

PUB mksmp16(value)
  return (value<<12)&$0FFFFFF0

PUB init_array(array,length,patternA,patternB) | idx
  idx:=0
  repeat while idx<length
    long[array][idx++] := patternA
    long[array][idx++] := patternB
                                                                