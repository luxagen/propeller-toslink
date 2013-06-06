VAR
  long buffer[384]
  long subcodes[12]
CON
  _clkmode = xtal1+pll16x
  _xinfreq=5000000

  SPD_SR = 32000                ' Sample rate
  SPD_VGROUP=0
  SPD_VPINS=%00000001

  DEBUGGING=false
  LG_DIVIDER = (DEBUGGING&1)<<7

  SR_32=%0011
  SR_44=%0000
  SR_48=%0010

  CQ_NORMAL=%00
  CQ_HIGH  =%01
  CQ_LOW   =%10

  CC_CD      =%00000001
  CC_DAT     =%00000011
  CC_ORIGINAL=%00000000   
OBJ
  spdif : "spdif_generator"
  gen : "test_signal_generator"

PUB Main | count,sample,samples_read,wpos

  make_spdif_control_block(0,1,CC_ORIGINAL,0,SR_32,CQ_NORMAL)

  sample := -50 

  repeat count from 0 to 191
    buffer[2*count] := mksmp16(sample)
    buffer[2*count + 1] := mksmp16(sample)

  buffer[382] := mksmp16(+500)
  buffer[383] := mksmp16(-500)
          
  samples_read:=192
  gen.start(@buffer,192,@samples_read,@subcodes)

  spdif.start(SPD_SR,LG_DIVIDER,@buffer,@samples_read,SPD_VGROUP,SPD_VPINS)

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

PUB make_spdif_control_block(digital_data,copy_permit,category_code,source_no,sr_code,clock_quality)
  subcodes[0] := 0|(digital_data<<1)|(copy_permit<<2)|(category_code<<8)|(source_no<<16)|(sr_code<<24)|(clock_quality<<28)
  subcodes[1] := 0
  subcodes[2] := 0
  subcodes[3] := 0
  subcodes[4] := 0
  subcodes[5] := 0

PUB make_aes_control_block(digital_data,pre_emphasis,not_lock,fs,channel_mode,user_bit_management,aux_use,word_length,reference,reliability,crc)
  subcodes[0] := 1|(digital_data<<1)|(pre_emphasis<<2)|(not_lock<<5)|(fs<<6)|(channel_mode<<8)|(user_bit_management<<12)|(aux_use<<16)|(word_length<<19)
  subcodes[1] := reference
  subcodes[2] := 0
  subcodes[3] := 0
  subcodes[4] := 0
  subcodes[5] := (reliability<<20)|(crc<<24)                                                              