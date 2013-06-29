' This generates a 1kHz half-full-scale sawtooth regardless of sample-rate

DAT

org 0

_gencog
        ' Copy client-supplied subcode table into cog-local memory for speed 
        mov temp,par
        rdlong temp,temp
        call #copy_subcodes

        call #synchronise ' First synchronise with input

        ' Load by-value parameters into local registers 

        ' Get pointer to buffer
        mov temp,par
        add temp,#4
        rdlong buffer,temp
        ' Get buffer size in frames and convert it to bytes
        add temp,#4
        rdlong buffer_bytes,temp
        shl buffer_bytes,#3

        add temp,#4
        rdlong wordclock_mask,temp

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

        :loop
'              waitcnt cnt_frame_next,sample_period_1
'              waitcnt cnt_frame_next,sample_period_3

              mov temp,#256
              shl temp,#3
              waitcnt cnt_frame_next,temp

'              call #gather_frame

              
              mov spdif_sampleL,#3
              shl spdif_sampleL,#12
              mov spdif_sampleR,#5
              shl spdif_sampleR,#12
              
{
              mov temp,#1
              shl temp,#16

              add stereo_frame,temp
              rol stereo_frame,#16
              add stereo_frame,temp
              rol stereo_frame,#16
}

'              mov stereo_frame,#3
'              shl stereo_frame,#16
'              or stereo_frame,#5

'              call #format_spdif

              call #write_spdif

        ' Set up two subcode registers from table and emit 32 samples
{
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
}
        jmp #:loop

' This initialises by waiting for the input lines to reach a predetermined state; from there we can predict timing
' because the Prop is running off the PCM56 sample clock
synchronise
        ' Initialise pin-group masks
        mov im_ctrl,im_sclk
        or im_ctrl,im_mpxA
        or im_ctrl,im_mpxB
        mov im_start3,im_ctrl
        or im_ctrl,im_laen
'        or im_ctrl,im_inh      ' INH is used for deglitching at the multiplexer, so we can safely ignore it

        ' Set up the input pins         
        mov temp,im_ctrl
        or temp,im_sdata 
        andn dira,temp

        ' The state sequence for the PCM56 (starting with the last bit of a word) is:
        '       SCLK && LAEN
        '       !SCLK && LAEN
        '       !SCLK && !LAEN
        '       SDATA/MPX transition to first bit of new word
        '       SCLK && !LAEN
        '       SCLK && LAEN
         
        ' Wait for !INH && SCLK && !LAEN && MPX==%11 (first bit of channel 3)
        waitpeq im_start3,im_ctrl

        ' Calculate when channel 0 will start and add 2 clocks to read just after the edge 
        mov cnt_frame_next,cnt
        add cnt_frame_next,sample_period_1
        add cnt_frame_next,#2
        mov cnt_sample_next,cnt_frame_next

        ' We need to be able to start gathering in 244 clocks         
synchronise_ret ret

{
' Generating 96 kHz S/PDIF at a clock rate of 32.768 MHz allows 341 cycles per stereo sample, and this loop has a worst-
' case runtime of 176 cycles (156 cycles without the indicator-LED code), so this should never be a bottleneck 
gen_smp_group
        ' SDATA bits clock every 16 cycles, making 512 cycles for two 16-bit samples; gather_stereo burns an extra 16 
        ' cycles for call/sync/break/return overhead, making 528
        call #gather_frame
        ' Formatting the stereo sample into S/PDIF for transmission takes 112 cycles including call/return overhead
'        call #format_spdif
        ' Writing the stereo sample and updating state takes up to 64 cycles
'        call #write_spdif
               

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
         
'        add frames_written,#1 ' Inform the consumer that it has a new stereo sample

djnz counter,#gen_smp_group
gen_smp_group_ret ret
               
gather_frame
        mov temp,#16                            ' Set up now to capture 16 bits so we can sample immediately on sync
        waitcnt cnt_frame_next,sample_period_1  ' Wait for first bit of channel 0 and add sample interval for next sample wait

        ' Capture 16 bits - no need to clear the previous sample, it will just stay in the high half of the register
        :loopL test ina,im_sdata wc
              rcl stereo_frame,#1
              ' Out of 16 cycles per bit, we now have 8 cycles in which to loop, so use them all (sub/if_nz jmp instead of 
              ' djnz); the loop will finish in 4 cycles less that way, saving time for post-processing
              sub temp,#1 wz                   
        if_nz jmp #:loopL 

        mov temp,#16                            ' Set up now to capture 16 bits so we can sample immediately on sync
        waitcnt cnt_sample_next,sample_period_3 ' Wait for first bit of channel 0 and add 3-sample interval for next frame wait

        ' Capture 16 bits - no need to clear the previous sample, it will just stay in the high half of the register
        :loopR test ina,im_sdata wc
              rcl stereo_frame,#1
              ' Out of 16 cycles per bit, we now have 8 cycles in which to loop, so use them all (sub/if_nz jmp instead of 
              ' djnz); the loop will finish in 4 cycles less that way, saving time for post-processing
              sub temp,#1 wz                   
        if_nz jmp #:loopR 
gather_frame_ret       ret
' Finishing the loop and returning will burn the first 8 cycles of the 512 we have in which to flush the stereo sample to the consumer
}

format_spdif
        ' Calculate the addresses of the longs we want from the subcode tables and modify upcoming read instructions to address them
        mov temp,writebyte
        shr temp,#(2+5)
        add temp,subcodes_buf
        movs $+4,temp
        add temp,#6                                     ' Subcode tables are 6 longs long
        movs $+3,temp

        mov temp,writebyte                              ' Start calculating which bit to extract from each subcode long (buffer SMC)

        ' Read the longs
        mov tempC,0-0
        mov tempU,0-0

        ' Finish calculating which bit to extract from each subcode long and move them into the LSb position
        shr temp,#2
        shr tempC,temp                                  ' This should ignore all but the low 5 bits, so don't bother clearing the rest
        shr tempU,temp                                  ' This should ignore all but the low 5 bits, so don't bother clearing the rest

        ' Extract left 16-bit sample into bits 15..30
        mov spdif_sampleL,stereo_frame
        shr spdif_sampleL,#1

        ' Extract right 16-bit sample into bits 15..30
        mov spdif_sampleR,stereo_frame
        shl spdif_sampleR,#15

        test temp,#0 wc

        shr spdif_sampleL,#2
        shr spdif_sampleR,#2

{
        ' Shift control and user bits into each sample
        test tempC,#1 wc
        rcr spdif_sampleL,#1
        rcr spdif_sampleR,#1
        test tempU,#1 wc
        rcr spdif_sampleL,#1
        rcr spdif_sampleR,#1
}
        ' Zero I bit and unused sample/preamble bits and rotate parity in (left)
        and spdif_sampleL,mask_cusample wc
        rcr spdif_sampleL,#1

        ' Zero I bit and unused sample/preamble bits and rotate parity in (right)
        and spdif_sampleR,mask_cusample wc
        rcr spdif_sampleR,#1
format_spdif_ret ret

write_spdif
        ' Calculate the address of the buffer location (in main memory) to write the left frame to
        mov temp,buffer
        add temp,writebyte

        wrlong spdif_sampleL,temp                              ' Write the left frame

        add temp,#4                                             ' Calculate right frame's address
        add writebyte,#8                                  ' Update write offset in buffer...

        wrlong spdif_sampleR,temp                              ' Right the write frame

        cmpsub writebyte,buffer_bytes                 ' ...and wrap it if needed
write_spdif_ret ret

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

stereo_frame long $00030005

sample_period_1 long 512
sample_period_3 long 3*512

'frames_written long 0
 
mask_sample long $0FFFFFF0
mask_u long $20000000
mask_c long $40000000
mask_p long $80000000

mask_cusample long %11011111111111111110000000000000

' Input lines
im_mpxA       long |<PIN_MPXA
im_mpxB       long |<PIN_MPXB
im_inh        long |<PIN_INH
im_sclk       long |<PIN_SCLK
im_laen       long |<PIN_LAEN
im_sdata      long |<PIN_SDATA
 
' ======== PARAMETERS ========
 
' Local buffer for subcodes
subcodes_buf
buf_ctrl res 6
buf_user res 6

buffer res 1
buffer_bytes res 1
 
wordclock_mask res 1    ' Bit-mask highlighting a single pin used for double-edged frame clocking
writebyte res 1         ' Next write address in buffer
 
' ============================
 
' Working space
im_ctrl res 1           ' Pin mask for control lines (everything but SDATA)
im_start3 res 1         ' Pin-state mask  for the start of a sample on channel 3         
cnt_sample_next res 1   ' Used to synchronise before reading each frame
cnt_frame_next res 1    ' Used to synchronise to the first bit of a frame
counter res 1           ' Controls 32-frame loop for outputting 1/6th of a block
reg_ctrl res 1          ' Shift register for current control-subcode word
reg_user res 1          ' Shift register for current user-subcode word
temp res 1              ' General-purpose temporary
temp2 res 1
spdif_sampleL res 1     ' Temporary for formatting S/PDIF data
spdif_sampleR res 1     ' Temporary for formatting S/PDIF data
'stereo_frame res 1      ' Used to accumulate a left/right 16-bit pair

tempC res 1
tempU res 1
 
fit

CON
  PIN_MPXA =10  ' LSb of channel number
  PIN_MPXB =12  ' MSb of channel number
  PIN_INH  =14  ' Inhibit signal from mainboard
  PIN_SCLK =18  ' Sample clock
  PIN_LAEN =22  ' Latch-enable signal for DAC
  PIN_SDATA=24  ' 4-channel serial sample data, MSb first   

VAR
  long mycog

  ' Parameters passed to the assembly routine running in cog with ID 'mycog'
  long _subcodes_ptr
  long _buffer
  long _buffer_frames
  long _wordclock_mask
  long _pos_ptr
  long _lead_frames

PUB start(__buffer,__buffer_frames,__subcodes_ptr,__wordclock_pin,__pos_ptr,__lead_frames)
  stop

  _buffer:=__buffer
  _buffer_frames:=__buffer_frames

  _wordclock_mask := |<__wordclock_pin
  _pos_ptr:=__pos_ptr
  _lead_frames:=__lead_frames
  _subcodes_ptr:=__subcodes_ptr

  mycog := 1+cognew(@_gencog,@_buffer)

PUB stop
  if mycog
    cogstop(mycog~ - 1)

'PRI divround(x,y)
'  return (x + y>>1)/y