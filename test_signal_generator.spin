VAR
  long mycog

  ' Parameters passed to the assembly routine running in cog with ID 'mycog'
  long _buffer
  long _buffer_frames
  long _readsmp_ptr
  long _subcodes_ptr

DAT
        org 0
_gencog
        ' load parameters into local registers 

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

        andn outa,mask_leds
        or dira,mask_leds

:new_loop
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
jmp #:new_loop

' Generating 96 kHz S/PDIF at a clock rate of 32.768 MHz allows 341 cycles per stereo sample, and this loop has a worst-
' case runtime of 176 cycles (156 cycles without the indicator-LED code), so this should never be a bottleneck 
gen_smp_group
        ' keep reading posptr until it changes
        rdlong frames_read,readsmp_ptr
        cmp frames_read,frames_written wz,wc
        if_e jmp #gen_smp_group
         
        ' Prevent the sample from incrementing for the first (leadin) frames
        cmp frames_written,leadin_frames wz,wc

        if_e mov sample,#0 ' First non-lead-in sample is zero...
        if_a add sample,increment ' ...and they increment from there
        mov temp2,sample
        sar temp2,#5

'        if_e mov sample,dummy
'        if_a neg sample,sample
'        mov temp2,sample
'        sar temp2,#4

        and temp2,mask_sample ' Clear special bits (the preamble will be left blank by the shift above)

        ' Set user and control bits from subcode table
        rcr reg_user,#1 wc
        if_c or temp2,mask_u
        rcr reg_ctrl,#1 wc
        if_c or temp2,mask_c wc ' Save overall parity...
        ' ...and encode it too
        if_c or temp2,mask_p

        ' Write the sample to the destination buffer twice for stereo
        mov temp,writebyte
        add temp,buffer
        wrlong temp2,temp
        add temp,#4
        wrlong temp2,temp
        add writebyte,#8
        cmpsub writebyte,buffer_bytes
         
        add frames_written,#1 ' Inform the consumer that it has a new stereo sample

        ' Show a visible indication         
'        mov temp,value_leds
'        and temp,mask_leds
'        andn outa,mask_leds
'        or outa,temp
'        rol value_leds,#1
         
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
copy_subcodes_ret ret

        leadin_frames long 384000

        mask_leds long $00FF0000
        value_leds long $01010101

        frames_written long 0
        writebyte long 0

        sample long -16384
        increment long 10<<17
'        dummy long 1<<16       

'        mask_iucp long $F0000000
        mask_sample long $0FFFFFF0
        mask_u long $20000000
        mask_c long $40000000
        mask_p long $80000000

        buffer res 1
        buffer_bytes res 1
        readsmp_ptr res 1

        temp res 1
        temp2 res 1
        frames_read res 1

        ' Local buffer for subcodes
        subcodes_buf
        buf_ctrl res 6
        buf_user res 6

        ' Counter and registers for shifting out one bit of each subcode per sample 
        counter res 1
        reg_ctrl res 1
        reg_user res 1

        fit

PUB start(__buffer,__buffer_frames,__readsmp_ptr,__subcodes_ptr)
  _buffer:=__buffer
  _buffer_frames:=__buffer_frames
  _readsmp_ptr:=__readsmp_ptr
  _subcodes_ptr:=__subcodes_ptr

  mycog:=cognew(@_gencog,@_buffer)

PUB stop
  cogstop(mycog)