VAR
  long buffer[384]
  long subcodes[12]
CON
'  _clkmode = xtal1+pll16x
'  _xinfreq=5000000

  _clkmode = xinput+pll16x
  _xinfreq=4096000

  PIN_SPDIF=0
'  PIN_LED=1
  PIN_TOSLINK=2

  SPD_SR=96000              ' Sample rate
  SPD_PIN=PIN_TOSLINK
  SPD_PIN_WORDCLOCK=27

  DEBUGGING=false

  SR_32=%0011
  SR_44=%0000
  SR_48=%0010

  CQ_NORMAL=%00
  CQ_HIGH  =%01
  CQ_LOW   =%10
                         
  CC_CD      =%00000001
  CC_DAT     =%00000011                                                      
  CC_ORIGINAL=%00000000

  PIN_MPXA =10  ' LSb of channel number
  PIN_MPXB =12  ' MSb of channel number
  PIN_INH  =14  ' Inhibit signal from mainboard
  PIN_SCLK =18  ' Sample clock
  PIN_LAEN =22  ' Latch-enable signal for DAC
  PIN_SDATA=24  ' 4-channel serial sample data, MSb first   
  PIN_OD   =26  ' Cutout signal for level-shifter   
OBJ
  spdif : "spdif_generator"
'  gen   : "test_signal_generator"
  gen : "pcm56_emulator"

PUB Main | count,sample,samples_read,wpos,vgroup,vpins

  ' Set !OE line high to disable input
  outa[PIN_OD] := 0
  dira[PIN_OD] := 1

  ' Set other lines as inputs
'  dira &= !%00000001010101010101010000000000            ' Set 

  make_spdif_control_block(0,1,CC_ORIGINAL,0,SR_32,CQ_NORMAL)

  sample := -32 

  repeat count from 0 to 191
    buffer[2*count] := mksmp16(sample)
    buffer[2*count + 1] := mksmp16(sample)

  buffer[382] := mksmp16(+500)
  buffer[383] := mksmp16(-500)

  vgroup:=get_vgroup(SPD_PIN)
  vpins:=get_vpins(SPD_PIN)
          
  spdif.start(SPD_SR,@buffer,@samples_read,vgroup,vpins,SPD_PIN_WORDCLOCK,DEBUGGING)

  waitcnt(2*clkfreq + cnt)

  gen.start(@buffer,192,@subcodes,SPD_PIN_WORDCLOCK,@samples_read,4)

  ' Minimally busy wait
'  repeat
'    waitcnt(clkfreq+cnt)

  Toggler

  spdif.stop
  gen.stop

PRI Toggler
  dira[23] := 1

  repeat
    waitcnt(65536000+cnt)
    !outa[23]

PRI get_vgroup(pin)
  return pin/8

PRI get_vpins(pin)
  return |<(pin//8)     

PRI mksmp16(value)
  return (value<<12)&$0FFFFFF0

PRI init_array(array,length,patternA,patternB) | idx
  idx:=0
  repeat while idx<length
    long[array][idx++] := patternA
    long[array][idx++] := patternB

PRI make_spdif_control_block(digital_data,copy_permit,category_code,source_no,sr_code,clock_quality)
  subcodes[0] := 0|(digital_data<<1)|(copy_permit<<2)|(category_code<<8)|(source_no<<16)|(sr_code<<24)|(clock_quality<<28)
  subcodes[1] := 0
  subcodes[2] := 0
  subcodes[3] := 0
  subcodes[4] := 0
  subcodes[5] := 0

PRI make_aes_control_block(digital_data,pre_emphasis,not_lock,fs,channel_mode,user_bit_management,aux_use,word_length,reference,reliability,crc)
  subcodes[0] := 1|(digital_data<<1)|(pre_emphasis<<2)|(not_lock<<5)|(fs<<6)|(channel_mode<<8)|(user_bit_management<<12)|(aux_use<<16)|(word_length<<19)
  subcodes[1] := reference
  subcodes[2] := 0
  subcodes[3] := 0
  subcodes[4] := 0
  subcodes[5] := (reliability<<20)|(crc<<24)                                                              