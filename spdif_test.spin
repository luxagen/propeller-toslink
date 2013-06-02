VAR
  long buffer[384]
CON
  _clkmode = xtal1+pll16x
  _xinfreq=5000000

  SPD_SR = 48000                ' Sample rate
  SPD_CR = SPD_SR*128           ' Symbol rate

  DEBUGGING=false
  SPD_PIN = 0-(DEBUGGING&1)
  LG_DIVIDER = (DEBUGGING&1)<<7
   
OBJ
  spdif : "spdif_generator"
  gen : "test_signal_generator"

PUB Main | count,sample,samples_read,wpos

  sample := -50 

  repeat count from 0 to 191
    buffer[2*count] := mksmp16(sample)
    buffer[2*count + 1] := mksmp16(sample)

  buffer[382] := mksmp16(+500)
  buffer[383] := mksmp16(-500)
          
  samples_read:=192
  gen.start(@buffer,192,@samples_read)

  spdif.start(SPD_CR,SPD_PIN,LG_DIVIDER,@buffer,@samples_read)

  repeat
  repeat

  spdif.stop

PUB mksmp16(value)
  return (value<<12)&$0FFFFFF0

PUB init_array(array,length,patternA,patternB) | idx
  idx:=0
  repeat while idx<length
    long[array][idx++] := patternA
    long[array][idx++] := patternB
                                                                