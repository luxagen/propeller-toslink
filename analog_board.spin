analog_board_emulator

waitpeq im_mpx11,im_mux		' Wait for (!INH && MPXA && MPXB)

' Wait for S/PDIF encoder to be finished with the first sample
:encoder_wait
	rdlong samples_read,posptr
	cmp samples_read,#0 wz
if_e jmp encoder_wait

' Start loop at beginning of buffer with hub access synchronised to second half of each 16-cycle group
mov outptr,outbuf
nop

' CONSIDER SHIFTING SYNCHRONISATION TO READ DATA PIN ON THIRD INSTRUCTION

:loop
	test ina,im_sdata wc
	mov gathering,#0	' Clear previous sample
	addx gathering,#0
	nop

	test ina,im_sdata wc
	rcl gathering,#1
		mov temp,outbyte				' Calculate which long of each subcode table to use
		shr temp,#(2+5)

	test ina,im_sdata wc
	rcl gathering,#1
		add temp,buf_subcodes			' Calculate which long of cog memory contains the control bit for this sample
		movs #:scC,temp					' Modify read instruction to get it

	test ina,im_sdata wc
	rcl gathering,#1
		add temp,#6						' Calculate which long of cog memory contains the user bit for this sample
		movs #:scU,temp					' Modify read instruction to get it

	test ina,im_sdata wc
	rcl gathering,#1
:scC	mov tempC,0-0					' Get long containing control bit
:scU	mov tempU,0-0					' Get long containing user bit

	test ina,im_sdata wc
	rcl gathering,#1
		mov temp,outbyte
		shr temp,#2						' Place index of each subcode bit within its word in the low 5 bits of temp

	test ina,im_sdata wc
	rcl gathering,#1
		shr tempC,temp					' Shift the control bit for this sample into position 0
		shr tempU,temp					' Shift the user bit for this sample into position 0

	test ina,im_sdata wc
	rcl gathering,#1
		test tempC,#1 wc				' Copy the control bit to the carry flag...
		rcr gathered,#1					' ...and rotate it into position

	test ina,im_sdata wc
	rcl gathering,#1
		test tempU,#1 wc				' Copy the user bit to the carry flag...
		rcr gathered,#1					' ...and rotate it into position

	test ina,im_sdata wc
	rcl gathering,#1
		and gathered,mask_cuisample wc	' Zero the low byte of the sample...
		rcr gathered,#1					' ...and set the parity bit

	test ina,im_sdata wc
	rcl gathering,#1
		wrlong gathered,outptr			' Write the complete frame to the destination buffer

	test ina,im_sdata wc
	rcl gathering,#1
		nop
		nop

	test ina,im_sdata wc
	rcl gathering,#1
		nop
		nop

	test ina,im_sdata wc
	rcl gathering,#1
		add outbyte,#4					' Increment the write address in the destination buffer...
		cmpsub outbyte,bufbytes			' ...and wrap it if needed

	test ina,im_sdata wc
	rcl gathering,#1
		mov outptr,outbuf				' Set up the write address for the next post-processed frame...
		add outptr,outbyte				' ...by adding the buffer address and the wrapped offset

	test ina,im_sdata wc				' Complete the current 16-bit sample...
	rcl gathering,#15					' ...and rotate it into position with a zero 'I' bit, ready for UCP post-processing
	mov gathered,gathering				' Move it out of the way for post-processing before it gets overwritten
jmp :loop

gathered long 0
mask_sample long $0FFFFFF0
mask_parity long $10000000
im_mpx11 long $00000006
im_mux long $0000000E
im_sdata long $00000001
outidx long 0

outbuf res 1
outptr res 1
