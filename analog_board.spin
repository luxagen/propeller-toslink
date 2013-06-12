CON
  ' Pins 0-5 are reserved for SCLK, SDATA, LAEN, MPXA, MPXB, and INH respectively

  im_sclk =%000001
  im_sdata=%000010
  im_laen =%000100
  im_mpxA =%001000
  im_mpxB =%010000
  im_inh  =%100000

  im_ctrl  =  %111111 & !im_sdata 

  sample_period=256

VAR
  byte mycog

  long _buffer
  long _buffer_frames
  long _readsmp_ptr
  long _subcodes_ptr

DAT

org 0

copy_subcodes
        rdlong subcodes_buf+0,temp
        add temp,#4
        rdlong subcodes_buf+1,temp        
        add temp,#4
        rdlong subcodes_buf+2,temp        
        add temp,#4
        rdlong subcodes_buf+3,temp        
        add temp,#4
        rdlong subcodes_buf+4,temp        
        add temp,#4
        rdlong subcodes_buf+5,temp
        add temp,#4        
        rdlong subcodes_buf+6,temp
        add temp,#4
        rdlong subcodes_buf+7,temp        
        add temp,#4
        rdlong subcodes_buf+8,temp        
        add temp,#4
        rdlong subcodes_buf+9,temp        
        add temp,#4
        rdlong subcodes_buf+10,temp        
        add temp,#4
        rdlong subcodes_buf+11,temp
        add temp,#4        
copy_subcodes_ret ret

_emucog
        ' Load parameters into local registers 
         
        ' Get pointer to buffer
        mov temp,par
        rdlong buffer,temp
        add temp,#4
        ' Get buffer size in frames and convert it to bytes
        rdlong buffer_bytes,temp
        shl buffer_bytes,#3
        ' Get pointer to the consumer's samples-consumed counter 
        add temp,#4
        rdlong readsmp_ptr,temp
         
        ' Copy client-supplied subcode table into cog-local memory for speed 
        add temp,#4
        rdlong temp,temp
        call #copy_subcodes
         
        ' Get parameters
        mov temp,par
        rdlong buffer,temp
        add temp,#4
        rdlong readsmp_ptr,temp
         
        ' The state sequence for the PCM56 (starting with the last bit of a word) is:
        '       SCLK && LAEN
        '       !SCLK && LAEN
        '       !SCLK && !LAEN
        '       SDATA/MPX transition to first bit of new word
        '       SCLK && !LAEN
        '       SCLK && LAEN
         
        ' Wait for !INH && SCLK && !LAEN && MPX==%11 (first bit of channel 3)
        waitpeq im_ch3_first,#im_ctrl
         
        ' We now have only 256 cycles before channel 0 starts - calculate when that will happen and store it
        mov cnt_ch0,cnt
        add cnt_ch0,#sample_period
         
        ' Having synchronised, our first stereo S/PDIF frame will actually be written in <760 cycles (248 cycles plus 2x256 
        ' to gather the stereo sample); assuming conservatively that the S/PDIF encoder increments its position and reads 
        ' the next stereo sample immediately after we read the current position value (it won't), we have 1024 cycles 
        ' before it will read the one after that; we will therefore write our first sample two samples ahead of the 
        ' position measurement to minimise latency while avoiding catch-up
        rdlong frames_written,readsmp_ptr
        add frames_written,#2
         
        ' Calculate samples_written MOD 192
        mov outbyte,frames_written
        mov temp2,#192
        shl temp2,#24
        mov temp,#25
        :mod_loop
                cmpsub outbyte,temp2
                shr temp2,#1
        djnz temp,#:mod_loop
        shl outbyte,#3          ' Convert to a byte offset in the buffer
         
        :loop
              ' SDATA bits clock every 16 cycles, making 512 cycles for two 16-bit samples; gather_stereo burns an extra 16 
              ' cycles for call/sync/break/return overhead, making 528
              call #gather_stereo
              ' Formatting the stereo sample into S/PDIF for transmission takes 112 cycles including call/return overhead
              call #format_spdif
              ' Writing the stereo sample and updating state takes up to 64 cycles
              call #write_spdif
               
              ' With 4 cycles for looping, the grand total is 708 out of a total budget of 1024
        jmp :loop

gather_stereo
        waitcnt cnt_ch0,frame_period    ' Align with word clock

        ' Capture MSb of left sample
        test ina,im_sdata wc
        mov stereo_sample,#0                                                                 ' Clear previous sample
        addx stereo_sample,#0                                                ' Begin new sample

        mov temp,#31                                           ' Set up to capture 31 more bits (end of right sample)
        :loop
                test ina,im_sdata wc
                rcl stereo_sample,#1
                ' Out of 16 cycles per bit, we now have 8 cycles in which to loop, so use them all (sub/if_nz jmp instead of 
                ' djnz); the loop will finish in 4 cycles less that way, saving time for post-processing
                sub temp,#1 wz                   
        if_nz jmp #:loop
gather_stereo_ret       ret
' Finishing the loop and returning will burn the first 8 cycles of the 512 we have in which to flush the stereo sample to the consumer

format_spdif
        ' Calculate the addresses of the longs we want from the subcode tables and modify upcoming read instructions to address them
        mov temp,outbyte
        shr temp,#(2+5)
        add temp,subcodes_buf
        movs $+4,temp
        add temp,#6                                             ' Subcode tables are 6 longs long
        movs $+3,temp

        mov temp,outbyte                                ' Start calculating which bit to extract from each subcode long (buffer SMC)

        ' Read the longs
        mov tempC,0-0
        mov tempU,0-0

        ' Finish calculating which bit to extract from each subcode long and move them into the LSb position
        shr temp,#2
        shr tempC,temp                                  ' This should ignore all but the low 5 bits, so don't bother clearing the rest
        shr tempU,temp                                  ' This should ignore all but the low 5 bits, so don't bother clearing the rest

        ' Extract left 16-bit sample into bits 15..30
        mov spdif_sampleL,stereo_sample
        shr spdif_sampleL,#1

        ' Extract right 16-bit sample into bits 15..30
        mov spdif_sampleR,stereo_sample
        shl spdif_sampleR,#15

        ' Shift control and user bits into each sample
        test tempC,#1 wc
        rcr spdif_sampleL,#1
        rcr spdif_sampleR,#1
        test tempU,#1 wc
        rcr spdif_sampleL,#1
        rcr spdif_sampleR,#1

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
        add temp,outbyte

        wrlong spdif_sampleL,temp                              ' Write the left frame

        add temp,#4                                             ' Calculate right frame's address
        add frames_written,#1                  ' Prepare to update progress

        wrlong spdif_sampleR,temp                              ' Right the write frame

        add outbyte,#8                                  ' Update write offset in buffer...
        cmpsub outbyte,buf_bytes                 ' ...and wrap it if needed

        wrlong frames_written,writtensmp_ptr
write_spdif_ret ret

' This mask works on a parityless frame 1 bit left of its final position, and preserves CU bits, zeroes the I bit, 
' preserves the 16-bit sample, zeroes the low 8 bits of the 24-bit S/PDIF sample, zeroes the preamble, and the final 
' zero is because it's shifted left one bit from its final position
mask_cusample long %110_1111111111111111_00000000_0000_0

frame_period long 1024
buf_bytes long 192*2*4
im_ch3_first long im_sclk|im_mpxA|im_mpxB

' ======== PARAMETERS ========
 
buffer res 1
buffer_bytes res 1
readsmp_ptr res 1
 
' Local buffer for subcodes
subcodes_buf
buf_ctrl res 6
buf_user res 6
 
' ============================

' Working space  
frames_written res 1    ' Counter for frames generated - usually just ahead of S/PDIF generator's position
writtensmp_ptr res 1    ' Main-memory location to update from the above counter 

cnt_ch0 res 1           ' Counter for maintaining synchronisation with incoming data (removes need for constant clocking)

' Pointer to the next byte offset within the S/PDIF encoder's input buffer at which to write
outbyte res 1

temp res 1
temp2 res 1

stereo_sample res 1     ' Long into which a left/right sample pair is gathered (L high, R low)
tempC res 1             ' Control subcode for current frame in LSb
tempU res 1             ' User subcode for current frame in LSb
spdif_sampleL res 1     ' Processed left frame ready for S/PDIF encoding
spdif_sampleR res 1     ' Processed right frame ready for S/PDIF encoding


PUB start(__buffer,__buffer_frames,__readsmp_ptr,__subcodes_ptr)
  stop

  _buffer:=__buffer
  _buffer_frames:=__buffer_frames
  _readsmp_ptr:=__readsmp_ptr
  _subcodes_ptr:=__subcodes_ptr

  mycog := 1+cognew(@_emucog,@_buffer)

PUB stop
  if mycog
    cogstop(mycog~ - 1)