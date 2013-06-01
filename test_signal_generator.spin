VAR
  long mycog

  ' Parameters passed to the assembly routine running in cog with ID 'mycog'
  long _buffer
  long _buffer_frames
  long _readsmp_ptr

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

        ' Get rid of this when proper waiting works
        mov nextcnt,delay
        shl nextcnt,#4
        add nextcnt,cnt

:gen_loop
        waitcnt nextcnt,delay
        ' keep reading posptr until it changes
'        rdlong read,posptr
'        cmp read,written wz,wc
'        if_ae jmp #:gen_loop

        add sample,#1
        mov temp2,sample
        shl temp2,#12
        andn temp2,mask_vucp
        
        mov temp,writebyte
        add temp,buffer
        wrlong temp2,temp
        add temp,#4
        wrlong temp2,temp
        add writebyte,#8
        cmpsub writebyte,buffer_bytes

'        add written,1

        jmp #:gen_loop

        delay long 833

        written long 0
        writebyte long 0

        sample long -50
        mask_vucp long $F0000000

        buffer res 1
        buffer_bytes res 1
        readsmp_ptr res 1

        temp res 1
        temp2 res 1
        read res 1

        nextcnt res 1

        fit

PUB start(__buffer,__buffer_frames,__readsmp_ptr)
  _buffer:=__buffer
  _buffer_frames:=__buffer_frames
  _readsmp_ptr:=__readsmp_ptr
  mycog:=cognew(@_gencog,@_buffer)

PUB stop
  cogstop(mycog)

