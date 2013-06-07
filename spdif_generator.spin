' MINIMUM VALUE OF (CLKFREQ/SAMPLE_RATE) THAT WORKS IS ~655
' ADJACENT PINS ARE COMPLEMENTARY
' ARBITRARY MASK FOR MULTIPLE PINS

VAR
  long mycog

  ' Parameters passed to the assembly routine running in cog with ID 'mycog'
  long _buffer
  long _frqa
  long _ctra
  long _vscl
  long _posptr
  long _pinmask
  long _vcfg

CON
  #0,CM_DISABLE,CM_PLLINT,CM_PLL,CM_PLLD,CM_NCO,CM_NCOD,CM_DUTY,CM_DUTYD,CM_POS,CM_POSF,CM_RISE,CM_RISEF,CM_NEG,CM_NEGF,CM_FALL,CM_FALLF
  #0,PLLD_1_8,PLLD_1_4,PLLD_1_2,PLLD_1,PLLD_2,PLLD_4,PLLD_8,PLLD_16
'  #0,VM_NONE,VM_VGA,VM_COMP_BASELOW,VM_COMP_BASEHIGH

  preamble_Z=%00010111
  preamble_Y=%00100111
  preamble_X=%01000111

  preamble_Z_xor  =  preamble_Z ^ $33 ' %00100100
  preamble_Y_xor  =  preamble_Y ^ $33 ' %00010100
  preamble_X_xor  =  preamble_X ^ $33 ' %01110100

DAT
        org 0
_outcog2
        ' Load parameters into local memory
        mov temp,par
        rdlong buffer,temp
        add temp,#4
        rdlong frqa,temp
        add temp,#4
        rdlong ctra,temp
        add temp,#4
        rdlong vscl,temp
        add temp,#4
        rdlong posptr,temp
        add temp,#4
        rdlong out_mask,temp
        add temp,#4

        andn dira,out_mask      ' Quickly suppress all output from this cog

        rdlong vcfg,temp        ' Enable video generator
        waitvid palette,#0      ' Queue a buffer to keep generator output low until we have real data

        andn outa,out_mask      ' Suppress direct output too

        ' The last two instructions take 8 cycles, which is 1 more than the WAITVID handover time, so the video
        ' generator should now be safely outputting the zero word we queued above, so we can re-enable its output
        or dira,out_mask

        ' Assuming that the margins in the following loop are razor-thin, the previous 2 instructions might have used
        ' up some of the preceding WAITVID's breathing-room; if this is needed by the loop, the first output might
        ' stutter, so to be safe we must queue another one just before entering 
        waitvid palette,#0

        ' Generating 96 kHz S/PDIF at a clock rate of 32.768 MHz allows 341 cycles per stereo sample, and this loop has
        ' a worst-case runtime of 556 instructions, so that will never be achievable; 192 kHz is achievable with a
        ' custom 110 MHz clock, and might be possible at lower speeds with inlining/optimisation 
        :block_loop
              mov blk_counter,#192
              mov pattern,#preamble_Z_xor ' This is output for the first frame only

              mov inptr,buffer
         
              :frame_loop
                        ' Either a Z (first frame) or X (other channel-0 frames) preamble will already be in 'pattern'
                        rdlong sample,inptr
                        add inptr,#4
                         
                        ' //////////////////////////////////////////////////////
                        ' LEFT SUBFRAME
                         
                        ' Send low word with preamble
                        call #bmc_encode_word
                        waitvid palette,subframe
                        ' Send high word, no preamble
                        shr sample,#16
                        mov pattern,#0
                        call #bmc_encode_word
                        waitvid palette,subframe
                         
                        ' ////////
                         
                        rdlong sample,inptr
                        add inptr,#4
                         
                          ' We've just read the second sample, so we're done with the original frame in the input buffer
                        add pos,#1
                        wrlong pos,posptr
                         
                        mov pattern,#preamble_Y_xor
                         
                        ' //////////////////////////////////////////////////////
                        ' // RIGHT SUBFRAME
                         
                        ' Send low word with preamble
                        call #bmc_encode_word
                        waitvid palette,subframe
                        ' Send high word, no preamble
                        shr sample,#16
                        mov pattern,#0
                        call #bmc_encode_word
                        waitvid palette,subframe
                         
                        ' ////////
                         
                        mov pattern,#preamble_X_xor ' output X preamble for every even frame except frame 0
                         
              djnz blk_counter,#:frame_loop         
               
        jmp #:block_loop

' input:
'       sample:         low word is what to encode
'       pattern:        either preamble or zero
'       subframe:       contains the result of the preceding bmc_output_word
' output:
'       subframe:       BMC-encoded word
' uses:
'       temp,pattern        
bmc_encode_word
                        ' Load the word's low byte
                        mov temp,sample
                        and temp,#$FF
                        ' Convert the byte into a BMC pattern
                        shr temp,#1 wc                  ' Generate the number of the long (pair of 16-bit entries) we want from the BMC table
                        add temp,#bmc_table             ' (temp) now contains the cog address of the entry we want
                        movs $+2,temp                   ' Set the read instruction to that source
                        test subframe,mask_bit31 wz     ' Use this buffering instruction slot to find out whether to invert the lookup result
                        xor pattern,0-0                 ' Perform the table read (modified by the MOVS 2 instructions ago), XORing to allow for preamble
                        if_nz xor pattern,mask_ones     ' Invert the pattern according to the state on which the previous pattern ended
                        ' Select one 16-bit entry from the pair to move into final position and clear the rest 
                        if_nc and pattern,mask_low16
                        if_c shr pattern,#16
                        mov subframe,pattern            ' Save the encoded lower half for merging 

                        ' Load the word's high byte 
                        mov temp,sample
                        shr temp,#8
                        and temp,#$FF
                        ' Convert the byte into a BMC pattern
                        shr temp,#1 wc                  ' Generate the number of the long (pair of 16-bit entries) we want from the BMC table
                        add temp,#bmc_table             ' (temp) now contains the cog address of the entry we want
                        movs $+2,temp                   ' Set the read instruction to that source
                        test subframe,mask_bit15 wz     ' Use this buffering instruction slot to find out whether to invert the lookup result
                        mov pattern,0-0                 ' Perform the table read (modified by the MOVS 2 instructions ago)
                        if_nz xor pattern,mask_ones     ' Invert the pattern according to the state on which the previous pattern ended
                        ' Select one 16-bit entry from the pair to move into final position and clear the rest 
                        if_nc shl pattern,#16
                        if_c andn pattern,mask_low16                        
                        or subframe,pattern             ' Merge the encoded upper half to produce a 32-bit BMC pattern for the 16-bit word
bmc_encode_word_ret     ret                        

        ' //////////////////////////////////////////////////////////////////////

        vcfg_vid long %0_01_0_0_0_000_00000000000_000_0_11111111

        mask_low16 long $0000FFFF
        mask_bit15 long $00008000
        mask_bit31 long $80000000
        mask_ones long $FFFFFFFF
         
        palette long $55_AA ' This ensures that adjacent pins in the group will be inverse to each other for differential signalling or power stabilisation
        
        pos long 0

        subframe long 0

        bmc_table
        ' 00000000..00001111
        word %0011001100110011,%1100110011001101,%1100110011001011,%0011001100110101,%1100110011010011,%0011001100101101,%0011001100101011,%1100110011010101
        word %1100110010110011,%0011001101001101,%0011001101001011,%1100110010110101,%0011001101010011,%1100110010101101,%1100110010101011,%0011001101010101
        ' 00010000..00011111
        word %1100110100110011,%0011001011001101,%0011001011001011,%1100110100110101,%0011001011010011,%1100110100101101,%1100110100101011,%0011001011010101
        word %0011001010110011,%1100110101001101,%1100110101001011,%0011001010110101,%1100110101010011,%0011001010101101,%0011001010101011,%1100110101010101
        ' 00100000..00101111
        word %1100101100110011,%0011010011001101,%0011010011001011,%1100101100110101,%0011010011010011,%1100101100101101,%1100101100101011,%0011010011010101
        word %0011010010110011,%1100101101001101,%1100101101001011,%0011010010110101,%1100101101010011,%0011010010101101,%0011010010101011,%1100101101010101
        ' 00110000..00111111
        word %0011010100110011,%1100101011001101,%1100101011001011,%0011010100110101,%1100101011010011,%0011010100101101,%0011010100101011,%1100101011010101
        word %1100101010110011,%0011010101001101,%0011010101001011,%1100101010110101,%0011010101010011,%1100101010101101,%1100101010101011,%0011010101010101
        ' 01000000..01001111
        word %1101001100110011,%0010110011001101,%0010110011001011,%1101001100110101,%0010110011010011,%1101001100101101,%1101001100101011,%0010110011010101
        word %0010110010110011,%1101001101001101,%1101001101001011,%0010110010110101,%1101001101010011,%0010110010101101,%0010110010101011,%1101001101010101
        ' 01010000..01011111
        word %0010110100110011,%1101001011001101,%1101001011001011,%0010110100110101,%1101001011010011,%0010110100101101,%0010110100101011,%1101001011010101
        word %1101001010110011,%0010110101001101,%0010110101001011,%1101001010110101,%0010110101010011,%1101001010101101,%1101001010101011,%0010110101010101
        ' 01100000..01101111
        word %0010101100110011,%1101010011001101,%1101010011001011,%0010101100110101,%1101010011010011,%0010101100101101,%0010101100101011,%1101010011010101
        word %1101010010110011,%0010101101001101,%0010101101001011,%1101010010110101,%0010101101010011,%1101010010101101,%1101010010101011,%0010101101010101
        ' 01110000..01111111
        word %1101010100110011,%0010101011001101,%0010101011001011,%1101010100110101,%0010101011010011,%1101010100101101,%1101010100101011,%0010101011010101
        word %0010101010110011,%1101010101001101,%1101010101001011,%0010101010110101,%1101010101010011,%0010101010101101,%0010101010101011,%1101010101010101
        ' 10000000..10001111
        word %1011001100110011,%0100110011001101,%0100110011001011,%1011001100110101,%0100110011010011,%1011001100101101,%1011001100101011,%0100110011010101
        word %0100110010110011,%1011001101001101,%1011001101001011,%0100110010110101,%1011001101010011,%0100110010101101,%0100110010101011,%1011001101010101
        ' 10010000..10011111
        word %0100110100110011,%1011001011001101,%1011001011001011,%0100110100110101,%1011001011010011,%0100110100101101,%0100110100101011,%1011001011010101
        word %1011001010110011,%0100110101001101,%0100110101001011,%1011001010110101,%0100110101010011,%1011001010101101,%1011001010101011,%0100110101010101
        ' 10100000..10101111
        word %0100101100110011,%1011010011001101,%1011010011001011,%0100101100110101,%1011010011010011,%0100101100101101,%0100101100101011,%1011010011010101
        word %1011010010110011,%0100101101001101,%0100101101001011,%1011010010110101,%0100101101010011,%1011010010101101,%1011010010101011,%0100101101010101
        ' 10110000..10111111
        word %1011010100110011,%0100101011001101,%0100101011001011,%1011010100110101,%0100101011010011,%1011010100101101,%1011010100101011,%0100101011010101
        word %0100101010110011,%1011010101001101,%1011010101001011,%0100101010110101,%1011010101010011,%0100101010101101,%0100101010101011,%1011010101010101
        ' 11000000..11001111
        word %0101001100110011,%1010110011001101,%1010110011001011,%0101001100110101,%1010110011010011,%0101001100101101,%0101001100101011,%1010110011010101
        word %1010110010110011,%0101001101001101,%0101001101001011,%1010110010110101,%0101001101010011,%1010110010101101,%1010110010101011,%0101001101010101
        ' 11010000..11011111
        word %1010110100110011,%0101001011001101,%0101001011001011,%1010110100110101,%0101001011010011,%1010110100101101,%1010110100101011,%0101001011010101
        word %0101001010110011,%1010110101001101,%1010110101001011,%0101001010110101,%1010110101010011,%0101001010101101,%0101001010101011,%1010110101010101
        ' 11100000..11101111
        word %1010101100110011,%0101010011001101,%0101010011001011,%1010101100110101,%0101010011010011,%1010101100101101,%1010101100101011,%0101010011010101
        word %0101010010110011,%1010101101001101,%1010101101001011,%0101010010110101,%1010101101010011,%0101010010101101,%0101010010101011,%1010101101010101
        ' 11110000..11111111
        word %0101010100110011,%1010101011001101,%1010101011001011,%0101010100110101,%1010101011010011,%0101010100101101,%0101010100101011,%1010101011010101
        word %1010101010110011,%0101010101001101,%0101010101001011,%1010101010110101,%0101010101010011,%1010101010101101,%1010101010101011,%0101010101010101         

        ' uninitialised assembly variables
        out_mask res 1
        blk_counter res 1
        sample res 1
        temp res 1
        pattern res 1
        buffer res 1
        inptr res 1
        posptr res 1

        fit

PUB start(sample_rate,lg_div,buffer_in,posptr_out,vgroup,vpins)
  ' Initialising the position pointer here guarantees that it will be initialised to a sane value (i.e. 0) by the time
  ' this function returns - if we initialised it inside the worker cog, there's a slim possibility that the caller
  ' could read it before that point 
  long[posptr_out] := 0

  ' Pass parameters and start new cog
  _buffer := buffer_in
  _frqa := calc_frq(sample_rate)
  _ctra := calc_ctr(CM_PLLINT,PLLD_1,0,0) 
  _vscl := calc_vscl(1,32,lg_div)
  _vcfg := vcfg_vid|(vgroup<<9)|vpins
  _posptr := posptr_out
  _pinmask := vpins<<(vgroup<<3)
  mycog:=cognew(@_outcog2,@_buffer)

PUB stop
  cogstop(mycog)

' /////////////////////////////////

PRI divround(x,y)
  return (x + y>>1)/y

PRI calc_frq(sample_rate) | cf_up,divisor,quotient,remainder
  ' This calculates ((2^32)/CLKFREQ)*rate_hz in 32-bit signed arithmetic using involved overflow-dodging tricks

  divisor := CLKFREQ/400

  quotient := $40000000/divisor     
  remainder := $40000000//divisor

  ' Remaining coefficient: 128*sample_rate*(4/400)

  quotient *= sample_rate/100
  remainder *= sample_rate/100

  quotient += remainder/divisor
  remainder//=divisor

  ' Remaining coefficient: 128*100*(4/400) = 128

  quotient<<=7       
  remainder<<=7

  ' Process the remainder to give the integer FRQA value nearest to the correct one
  return quotient + divround(remainder,divisor)

PRI calc_ctr(mode,plldiv,apin,bpin)
  return ((mode << 3 + plldiv) << 14 + bpin) << 9 + apin

PRI calc_vscl(pclks,fclks,lg_div)
  return (fclks<<lg_div)&((1<<12)-1) | (pclks<<(12+lg_div))