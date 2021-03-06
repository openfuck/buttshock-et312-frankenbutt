	# Early boxes use a different DAC chip which requires different
	# SPI commands, so old boxes use 1.5 firmware and new boxes use
	# 1.6 firmware. There isn't a huge amount of difference between
	# them.
	#
	# We can detect if we're an old box or a new box by the bootloader
	# that is installed.  The 1.5 bootloader jumps to 0x1476 in the
	# middle of some 1.6 code.  The 1.6 bootloader jumps to 0x14a6
	#
	# So we can move the code out of the way of 0x1476, use anything
	# jumping to 0x1476 as an indicator it's an old box.
	#
	# For old MAXDAC box we set memory 0x30f to 15(dec)
	#
	# not yet tested on 1.6bl/1.6box
	# not yet tested on 1.5bl/1.5box (doesn't work yet)
	
	# since 0x1476 is a jump point, we have to relocate all the
	# code before it too

	whatboxarewe = 0x30f
	
replace_0x1460:
	jmp Label_0x1460

Label_0x1460:
	cpi r26, 0x10
	brcc Label_0x1476
	inc r27
	cpi r27,0x40
	brcc Label_0x1492
	cpi r16, 0x00
	brne Label_0x1472
	std Y+11,r27 ; Memory[[r28:r29]+11] = r27;
	jmp 0x1432

Label_0x1472:
	std Y+12,r27 ; Memory[[r28:r29]+12] = r27;
	jmp 0x1432

Label_0x1476:
	cpi r27,0
	breq Label_0x1492
	cpi r16, 0
	brne Label_0x1484
	ldi r16,1
	clr r27
	jmp 0x1416

Label_0x1484:
	jmp 0x1484
	
Label_0x1492:
	jmp 0x1492
	
	# okay, real code is out of the way, so we can add a new start point for the 1.5bl
	# to jump to
	
replace_0x1476:
	ldi r26, 15
	sts whatboxarewe, r26
	jmp 0x14a6

	# Old box? set 0x500 to a 1 so we don't need to change other
	# things

replace_0x150e:
	jmp Label_0x150e

Label_0x150e:
	lds r27, whatboxarewe
	cpi r27, 15
	brne newbox
	ldi r26, 1
newbox:
	sts 0x500, r26 ; a0 93 00 05 this is what we overwrote 
	jmp 0x1512

	#
	# We measure the fet current and older boxes start differently....
	#

replace_0x1410:
	jmp Label_0x1410

Label_0x1410:
	push r30
	ldi r26, 100
	lds r30, whatboxarewe
	cpi r30, 15
	brne set_fet
	ldi r26, 83
set_fet:
	pop r30
	std Y+4, r26		; 1412:   ac 83           Memory[[r28:r29]+4] = r26;
	std Y+5, r26		; 1414:   ad 83           Memory[[r28:r29]+5] = r26;
	jmp 0x1416

	#
	# Replace the SPI transfer complete with a jump to our new code
	#
	# when a SPI transfer is complete check if we're a new box, if so
	# do the original 1.6 SPI transfer complete code, otherwise copy in
	# the old 1.5 SPI transfer code here and do that.
	
replace_0x28:
	jmp replacement_spi_transfer_complete

replacement_spi_transfer_complete:
	in r1, 0x3f	  ; 10f6:   1f b6           r1 = IO[SREG];
	lds r23, whatboxarewe
	cpi r23, 15
	breq oldbox
	jmp 0x10fa		; Old spi_transfer_complete

oldbox:
	lds r23, 0x208    ; 10f8:   70 91 08 02     r23 = Memory[0x0208];               ; 520
	cpi r23, 0x5	  ; 10fc:   75 30           cmp(r23, 0x05);                     ; 5
	brcc Label_0x114e
	dec r23		  ; 1102:   7a 95           r23--;
	sts 0x208, r23	  ; 1104:   70 93 08 02     Memory[0x0208] = r23;               ; 520
	breq Label_0x114e ; 1108:   11 f1           if (c1 == c2) goto Label_0x114e;
	cpi r23, 0x02	  ; 110a:   72 30           cmp(r23, 0x02);                     ; 2
	breq Label_0x1142 ; 110c:   d1 f0           if (c1 == c2) goto Label_0x1142;
	brlt Label_0x1118 ; 110e:   24 f0           if (c1 (signed)< c2) goto Label_0x1118;
	lds r23, 0x205	  ; 1110:   70 91 05 02     r23 = Memory[0x0205];               ; 517
	mov r24, r7	  ; 1114:   87 2d           r24 = r7;
	rjmp Label_0x111e ; 1116:   03 c0           goto Label_0x111e;

Label_0x1118:
	lds r23, 0x206	  ; 1118:   70 91 06 02     r23 = Memory[0x0206];               ; 518
	mov r24, r12	  ; 111c:   8c 2d           r24 = r12;

Label_0x111e:
	clr r3		  ; 111e:   33 24           r3 = 0x00;                          ; 0
	ldi r25, 8	  ; 1120:   98 e0           r25 = 8;                            ; 0x08
	lsr r24	 	  ; 1122:   86 95           r24 >>= 1;                          ; _BV(7) = 0, Carry = _BV(0) (logical shift)

Label_0x1124:
	brcc Label_0x1128 ; 1124:   08 f4           if (!Carry) goto Label_0x1128;
	add r3, r23	  ; 1126:   37 0e           r3 += r23;                          ; No carry

Label_0x1128:
	ror r3		  ; 1128:   37 94           r3 >>= 1;                           ; _BV(7) = Carry, Carry = _BV(0) (rotate right)
	ror r24		  ; 112a:   87 95           r24>>= 1;                          ; _BV(7) = Carry, Carry = _BV(0) (rotate right)
	dec r25		  ; 112c:   9a 95           r25--;
	brne Label_0x1124 ; 112e:   d1 f7           if (c1 != c2) goto Label_0x1124;
	ldi r25, 8	  ; 1130:   98 e0           r25 = 8;                            ; 0x08
	clc 	 	  ; 1132:   88 94           clc

Label_0x1134:
	ror r3		  ; 1134:   37 94           r3 >>= 1;                           ; _BV(7) = Carry, Carry = _BV(0) (rotate right)
	ror r24		  ; 1136:   87 95           r24 >>= 1;                          ; _BV(7) = Carry, Carry = _BV(0) (rotate right)
	dec r25		  ; 1138:   9a 95           r25--;
	brne Label_0x1134 ; 113a:   e1 f7           if (c1 != c2) goto Label_0x1134;
	com r24		  ; 113c:   80 95           com     r24
	out 0x0f, r24	  ; 113e:   8f b9           IO[SPDR] = r24;
	rjmp Label_0x1150

Label_0x1142:
	sbi 0x12, 4	  ; 1142:   94 9a           IO[PORTD[4]] = true;                ; 0x10 = 16
	nop 	  	  ; 1144:   00 00           nop
	cbi 0x12, 4	  ; 1146:   94 98           IO[PORTD[4]] = false;               ; 0x10 = 16
	ldi r23, 10	  ; 1148:   7a e0           r23 = 10;                           ; 0x0a
	out 0x0f, r23	  ; 114a:   7f b9           IO[SPDR] = r23;
	rjmp Label_0x1150 ; 114c:   01 c0           goto Label_0x1150;

Label_0x114e:
	sbi 0x12, 4	  ; 114e:   94 9a           IO[PORTD[4]] = true;                ; 0x10 = 16

Label_0x1150:
	out 0x3f, r1	  ; 1150:   1f be           IO[SREG] = r1;
	reti
