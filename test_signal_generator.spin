' This generates a 1kHz half-full-scale sawtooth regardless of sample-rate

DAT

org 0

_gencog
        ' Load parameters into local registers 

        ' Get pointer to buffer
        mov temp,par
        rdlong buffer,temp
        ' Get buffer size in frames and convert it to bytes
        add temp,#4
        rdlong buffer_bytes,temp
        shl buffer_bytes,#3

        ' Get per-sample increment value, mask for wordclock pin, and initial write positon
        add temp,#4
        rdlong increment,temp

        add temp,#4
        rdlong wordclock_mask,temp
{
        call #erase_buffer
        call #erase_buffer2
        call #erase_buffer
        call #erase_buffer2
        call #erase_buffer
        call #erase_buffer2
        call #erase_buffer
        call #erase_buffer2
        call #erase_buffer
        call #erase_buffer2
        call #erase_buffer
        call #erase_buffer2

        mov temp,par
        add temp,#12
}
        ' Read a bang-up-to-date buffer position from the consumer, jump ahead a bit, wrap the value into the buffer,
        ' and convert it to a byte offset
        add temp,#4
        rdlong writebyte,temp
        rdlong writebyte,writebyte
        add temp,#4
        rdlong counter,temp     ' Using counter as a temporary for lead value
        add writebyte,counter
        cmpsub writebyte,#192
        shl writebyte,#3        

        ' Copy client-supplied subcode table into cog-local memory for speed 
        add temp,#4
        rdlong temp,temp
        call #copy_subcodes

        ' Set up the wordclock pin for input and capture its current state
        andn dira,wordclock_mask
        mov wordclock,ina
        and wordclock,wordclock_mask        

:loop
        ' Set up two subcode registers from table and emit 32 samples
        mov reg_ctrl,buf_ctrl+0
        mov reg_user,buf_user+0
        mov counter,#32
        call #gen_smp_group
        ' Set up two subcode registers from table and emit 32 samples
        mov reg_ctrl,buf_ctrl+1
        mov reg_user,buf_user+1
        mov counter,#32
        call #gen_smp_group
        ' Set up two subcode registers from table and emit 32 samples
        mov reg_ctrl,buf_ctrl+2
        mov reg_user,buf_user+2
        mov counter,#32
        call #gen_smp_group
        ' Set up two subcode registers from table and emit 32 samples
        mov reg_ctrl,buf_ctrl+3
        mov reg_user,buf_user+3
        mov counter,#32
        call #gen_smp_group
        ' Set up two subcode registers from table and emit 32 samples
        mov reg_ctrl,buf_ctrl+4
        mov reg_user,buf_user+4
        mov counter,#32
        call #gen_smp_group
        ' Set up two subcode registers from table and emit 32 samples
        mov reg_ctrl,buf_ctrl+5
        mov reg_user,buf_user+5
        mov counter,#32
        call #gen_smp_group
jmp #:loop

erase_buffer
        ' reg_ctrl gets number of longs to write at start of buffer
        ' counter gets number of longs to write at writebyte
         
        mov spdif_sample,#3
        shl spdif_sample,#22
         
        mov counter,#192

        mov temp,#192
        shl temp,#3
         
        :clear_loop1
              mov reg_user,writebyte
              add reg_user,buffer
         
              wrlong spdif_sample,reg_user
              add reg_user,#4
              wrlong spdif_sample,reg_user
              add writebyte,#8
              cmpsub writebyte,temp
        djnz counter,#:clear_loop1
erase_buffer_ret ret
         
erase_buffer2
        ' reg_ctrl gets number of longs to write at start of buffer
        ' counter gets number of longs to write at writebyte
         
        mov spdif_sample,#3
        shl spdif_sample,#22
        neg spdif_sample,spdif_sample
         
        mov counter,#192

        mov temp,#192
        shl temp,#3
         
        :clear_loop1
              mov reg_user,writebyte
              add reg_user,buffer
         
              wrlong spdif_sample,reg_user
              add reg_user,#4
              wrlong spdif_sample,reg_user
              add writebyte,#8
              cmpsub writebyte,temp
        djnz counter,#:clear_loop1
erase_buffer2_ret ret
         
' Generating 96 kHz S/PDIF at a clock rate of 32.768 MHz allows 341 cycles per stereo sample, and this loop has a worst-
' case runtime of 176 cycles (156 cycles without the indicator-LED code), so this should never be a bottleneck 
gen_smp_group
        ' Waiting for wordclock allows us to save power by avoiding a busy RDLONG loop to check consumer's progress
        mov wordclock,ina
        and wordclock,wordclock_mask
        xor wordclock,wordclock_mask ' Calculate the next state (bit complement)
        ' Wait for it to happen
        test temp,#0 wc
        waitpeq wordclock,wordclock_mask
         
        ' Prevent the sample from incrementing for the first (leadin) frames
        cmp frames_written,leadin_frames wz,wc

        if_e mov sample,#0 ' First non-lead-in sample is zero...
        if_a add sample,increment ' ...and they increment from there
        mov spdif_sample,sample
        sar spdif_sample,#(28-SAW_BITS)

        and spdif_sample,mask_sample ' Clear special bits (the preamble will be left blank by the shift above)

        ' Set user and control bits from subcode table
        rcr reg_user,#1 wc
        if_c or spdif_sample,mask_u
        rcr reg_ctrl,#1 wc
        if_c or spdif_sample,mask_c wc ' Save overall parity...
        ' ...and encode it too
        if_c or spdif_sample,mask_p

        ' Write the sample to the destination buffer twice for stereo
        mov temp,writebyte
        add temp,buffer
        wrlong spdif_sample,temp
        add temp,#4
        wrlong spdif_sample,temp
        add writebyte,#8
        cmpsub writebyte,buffer_bytes
         
        add frames_written,#1 ' Inform the consumer that it has a new stereo sample

djnz counter,#gen_smp_group
gen_smp_group_ret ret
               
copy_subcodes
        rdlong buf_ctrl+0,temp
        add temp,#4
        rdlong buf_ctrl+1,temp        
        add temp,#4
        rdlong buf_ctrl+2,temp        
        add temp,#4
        rdlong buf_ctrl+3,temp        
        add temp,#4
        rdlong buf_ctrl+4,temp        
        add temp,#4
        rdlong buf_ctrl+5,temp
        add temp,#4        
        rdlong buf_user+0,temp
        add temp,#4
        rdlong buf_user+1,temp        
        add temp,#4
        rdlong buf_user+2,temp        
        add temp,#4
        rdlong buf_user+3,temp        
        add temp,#4
        rdlong buf_user+4,temp        
        add temp,#4
        rdlong buf_user+5,temp
        add temp,#4        
copy_subcodes_ret ret

' //////////////////////////////////////////////////////////////////////////////

leadin_frames long 96000
 
frames_written long 0
 
sample long -(1<<(SAW_BITS+8-2))
 
mask_sample long $0FFFFFF0
mask_u long $20000000
mask_c long $40000000
mask_p long $80000000
 
' ======== PARAMETERS ========
 
buffer res 1
buffer_bytes res 1
increment res 1
 
wordclock_mask res 1    ' Bit-mask highlighting a single pin used for double-edged frame clocking
writebyte res 1         ' Next write address in buffer
 
' Local buffer for subcodes
subcodes_buf
buf_ctrl res 6
buf_user res 6

' ============================
 
' Working space         
counter res 1           ' Controls 32-frame loop for outputting 1/6th of a block
reg_ctrl res 1          ' Shift register for current control-subcode word
reg_user res 1          ' Shift register for current user-subcode word
temp res 1              ' General-purpose temporary
spdif_sample res 1      ' Temporary for formatting S/PDIF data
wordclock res 1
 
fit

CON
  SAW_FREQ=1000 ' Number of sawtooth cycles per second
  SAW_BITS=20   ' The sawtooth will appear in the lowest SAW_BITS bits of the 24-bit sample, higher bits being sign-extended

  DEBUG_MODE=false

VAR
  long mycog

  ' Parameters passed to the assembly routine running in cog with ID 'mycog'
  long _buffer
  long _buffer_frames
  long _step
  long _wordclock_mask
  long _pos_ptr
  long _lead_frames
  long _subcodes_ptr

PUB start(__sample_rate,__buffer,__buffer_frames,__subcodes_ptr,__wordclock_pin,__pos_ptr,__lead_frames)
  stop

  _buffer:=__buffer
  _buffer_frames:=__buffer_frames

  if DEBUG_MODE
    _step := |<(32-SAW_BITS)
  else
    _step:=calc_step(SAW_FREQ,__sample_rate)

  _wordclock_mask := |<__wordclock_pin
  _pos_ptr:=__pos_ptr
  _lead_frames:=__lead_frames
  _subcodes_ptr:=__subcodes_ptr

  mycog := 1+cognew(@_gencog,@_buffer)

PUB stop
  if mycog
    cogstop(mycog~ - 1)

PRI divround(x,y)
  return (x + y>>1)/y

PRI calc_step(freq,sample_rate) | quotient,remainder
  freq<<=16

  quotient := freq/sample_rate
  remainder := freq//sample_rate

  quotient<<=8
  remainder<<=8

  quotient += remainder/sample_rate
  remainder//=sample_rate

  quotient<<=8
  remainder<<=8

  return quotient + divround(remainder,sample_rate)