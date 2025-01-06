; Miscellaneous CCD control routines
POWER_OFF
	JSR	<CLEAR_SWITCHES		; Clear all analog switches
	BSET	#LVEN,X:HDR 
	BSET	#HVEN,X:HDR 
	JMP	<FINISH

; Execute the power-on cycle, as a command
POWER_ON
	JSR	<CLEAR_SWITCHES		; Clear all analog switches
	JSR	<PON			; Turn on the power control board
	JCLR	#PWROK,X:HDR,PWR_ERR	; Test if the power turned on properly
	JSR	<SET_BIASES		; Turn on the DC bias supplies
	BSET	#3,X:PCRD		; Turn on the serial clock
	JSR	<PAL_DLY		; Delay for all this to happen
	JSR	<SEL_OS
	JSR	<PAL_DLY		; Delay for all this to happen
	BCLR	#3,X:PCRD		; Turn off the serial clock
	BSET	#IDLMODE,X:<STATUS	; Idle after readout
	MOVE	#IDLE,R0		; Put controller in IDLE state
	MOVE	R0,X:<IDL_ADR
	BSET	#ST_DITH,X:<STATUS	; Turn dithering on
	JMP	<FINISH

; Removed temporarily
;	MOVE	#$41064,X0
;	MOVE	X0,X:<STATUS


; The power failed to turn on because of an error on the power control board
PWR_ERR	BSET	#LVEN,X:HDR		; Turn off the low voltage emable line
	BSET	#HVEN,X:HDR		; Turn off the high voltage emable line
	JMP	<ERROR

; As a subroutine, turn on the low voltages (+/- 6.5V, +/- 16.5V) and delay
PON	BCLR	#LVEN,X:HDR		; Set these signals to DSP outputs 
	MOVE	#2000000,X0
	DO      X0,*+3			; Wait 20 millisec for settling
	NOP 	

; Turn on the high +36 volt power line and then delay
	BCLR	#HVEN,X:HDR		; HVEN = Low => Turn on +36V
	MOVE	#1000000,X0
	DO      X0,*+3			; Wait 100 millisec for settling
	NOP
	RTS

; Set all the DC bias voltages and video processor offset values, reading
;   them from the 'DACS' table
SET_BIASES
	BSET	#3,X:PCRD		; Turn on the serial clock
	BCLR	#1,X:<LATCH		; Separate updates of clock driver
	BSET	#CDAC,X:<LATCH		; Disable clearing of DACs
	BSET	#ENCK,X:<LATCH		; Enable clock and DAC output switches
	MOVEP	X:LATCH,Y:WRLATCH	; Write it to the hardware
	JSR	<PAL_DLY		; Delay for all this to happen

; Read DAC values from a table, and write them to the DACs
	MOVE	#DACS,R0		; Get starting address of DAC values
	NOP
	NOP
	DO      Y:(R0)+,L_DAC		; Repeat Y:(R0)+ times
	MOVE	Y:(R0)+,A		; Read the table entry
	JSR	<XMIT_A_WORD		; Transmit it to TIM-A-STD
	NOP
L_DAC

; Let the DAC voltages all ramp up before exiting
	MOVE	#400000,X0
	DO	X0,*+3			; 4 millisec delay
	NOP
	BCLR	#3,X:PCRD		; Turn the serial clock off
	RTS

; Read DAC values from a table, and write them to the DACs
WR_DACS	NOP
	DO      Y:(R0)+,L_DACS		; Repeat Y:(R0)+ times
	MOVE	Y:(R0)+,A		; Read the table entry
	JSR	<XMIT_A_WORD		; Transmit it to TIM-A-STD
	NOP
L_DACS
	RTS

SET_BIAS_VOLTAGES
	JSR	<SET_BIASES
	JMP	<FINISH

CLR_SWS	JSR	<CLEAR_SWITCHES
	JMP	<FINISH

; Clear all video processor analog switches to lower their power dissipation
CLEAR_SWITCHES
	BSET	#3,X:PCRD	; Turn the serial clock on
	CLR	B
	MOVE	#$100000,X0	; Increment over board numbers for DAC writes
	MOVE	#$001000,X1	; Increment over board numbers for WRSS writes
	DO	#15,L_VIDEO	; Fifteen video processor boards maximum
	MOVE	B,Y:WRSS
	JSR	<PAL_DLY	; Delay for the serial data transmission
	ADD	X1,B
L_VIDEO	
	BCLR	#CDAC,X:<LATCH		; Enable clearing of DACs
	BCLR	#ENCK,X:<LATCH		; Disable clock and DAC output switches
	MOVEP	X:LATCH,Y:WRLATCH 	; Execute these two operations
	BCLR	#3,X:PCRD		; Turn the serial clock off
	RTS

; Open the shutter by setting the backplane bit TIM-LATCH0
OSHUT	BSET    #ST_SHUT,X:<STATUS 	; Set status bit to mean shutter open
	BCLR	#SHUTTER,X:<LATCH	; Clear hardware shutter bit to open
	MOVEP	X:LATCH,Y:WRLATCH	; Write it to the hardware
        RTS

; Close the shutter by clearing the backplane bit TIM-LATCH0
CSHUT	BCLR    #ST_SHUT,X:<STATUS 	; Clear status to mean shutter closed
	BSET	#SHUTTER,X:<LATCH	; Set hardware shutter bit to close
	MOVEP	X:LATCH,Y:WRLATCH	; Write it to the hardware
        RTS

; Open the shutter from the timing board, executed as a command
OPEN_SHUTTER
	JSR	<OSHUT
	JMP	<FINISH

; Close the shutter from the timing board, executed as a command
CLOSE_SHUTTER
	JSR	<CSHUT
	JMP	<FINISH

; Clear the CCD, executed as a command
CLEAR	JSR	<CLR_CCD
	JMP     <FINISH

; Default clearing routine with serial clocks inactive
; Fast clear image before each exposure, executed as a subroutine
CLR_CCD	DO      Y:<NPCLR,LPCLR2		; Loop over number of lines in image
	MOVE    #PARALLEL_SPLIT,R0	; Address of parallel transfer waveform
	JSR	<PARALLEL_CLOCK
	JCLR    #EF,X:HDR,LPCLR1 	; Simple test for fast execution
	MOVE	#COM_BUF,R3
	JSR	<GET_RCV		; Check for FO command
	JCC	<LPCLR1			; Continue if no commands have been received

	MOVE	#LPCLR1,R0
	MOVE	R0,X:<IDL_ADR
	JMP	<PRC_RCV
LPCLR1	NOP
LPCLR2
	MOVE	Y:<EXPOSE_PARALLELS,R0	; Put the parallel clocks in the correct state to
	JSR	<PARALLEL_CLOCK		;   collect charge on only one parallel phase
	RTS 

; Start the exposure timer and monitor its progress
EXPOSE	MOVEP	#0,X:TLR0		; Load 0 into counter timer
	MOVE	#0,X0
	MOVE	X0,X:<ELAPSED_TIME	; Set elapsed exposure time to zero
	MOVE	X:<EXPOSURE_TIME,B
	TST	B			; Special test for zero exposure time
	JEQ	<END_EXP		; Don't even start an exposure
	SUB	#1,B			; Timer counts from X:TCPR0+1 to zero
	BSET	#TIM_BIT,X:TCSR0	; Enable the timer #0
	MOVE	B,X:TCPR0
CHK_RCV	JCLR    #EF,X:HDR,CHK_TIM	; Simple test for fast execution
	MOVE	#COM_BUF,R3		; The beginning of the command buffer
	JSR	<GET_RCV		; Check for an incoming command
	JCS	<PRC_RCV		; If command is received, go check it
CHK_TIM	JSSET	#ST_DITH,X:STATUS,DITHER ; Exercise the serial clocks during exposure
	JCLR	#TCF,X:TCSR0,CHK_RCV	; Wait for timer to equal compare value
END_EXP	BCLR	#TIM_BIT,X:TCSR0	; Disable the timer
	JMP	(R7)			; This contains the return address

; Start the exposure, expose, and initiate the CCD readout
START_EXPOSURE
	MOVE	#$020102,B
	JSR	<XMT_WRD
	MOVE	#'IIA',B		; Initialize the PCI image address
	JSR	<XMT_WRD
	JSR	<CLR_CCD
	MOVE	#TST_RCV,R0		; Process commands during the exposure
	MOVE	R0,X:<IDL_ADR
	JSR	<WAIT_TO_FINISH_CLOCKING
	
; Operate the shutter if needed and begin exposure
	JCLR	#SHUT,X:STATUS,L_SEX0
	JSR	<OSHUT
L_SEX0	MOVE	#L_SEX1,R7		; Return address at end of exposure
	JMP	<EXPOSE			; Delay for specified exposure time
L_SEX1

; Now we really start the CCD readout, alerting the PCI board, closing the 
;  shutter, waiting for it to close and then reading out
STR_RDC	JSR	<PCI_READ_IMAGE		; Get the PCI board reading the image
	BSET	#ST_RDC,X:<STATUS 	; Set status to reading out
	JCLR	#SHUT,X:STATUS,S_DEL0
	JSR	<CSHUT			; Close the shutter if necessary

; Delay readout until the shutter has fully closed
	MOVE	Y:<SHDEL,A
	TST	A
	JLE	<S_DEL0
	MOVE	#100000,X0
	DO	A,S_DEL0		; Delay by Y:SHDEL milliseconds
	DO	X0,S_DEL1
	NOP
S_DEL1	NOP
S_DEL0
	JSET	#TST_IMG,X:STATUS,SYNTHETIC_IMAGE
	JMP	<RDCCD			; Finally, go read out the CCD
	
; Set the desired exposure time
SET_EXPOSURE_TIME
	MOVE	X:(R3)+,Y0
	MOVE	Y0,X:EXPOSURE_TIME
	JCLR	#TIM_BIT,X:TCSR0,FINISH	; Return if the exposure is not occurring

	MOVEP	X:TCR0,A		; If the new exposure time is .LE. the elapsed time then
	CMP	Y0,A			;   set the new exposure time to 1 + elapsed time
	JLT	<SET_0			; Elapsed time is less than the new time, so don't bother
	ADD	#1,A			; Add a 1 millisec to avoid a race condition
	NOP
	MOVEP	A1,X:TCPR0
	JMP	<FINISH

SET_0	MOVEP	Y0,X:TCPR0		; Update timer if exposure in progress
	JMP	<FINISH

; Read the time remaining until the exposure ends
READ_EXPOSURE_TIME
	JSET	#TIM_BIT,X:TCSR0,RD_TIM	; Read DSP timer if its running
	MOVE	X:<ELAPSED_TIME,Y1
	JMP	<FINISH1
RD_TIM	MOVE	X:TCR0,Y1		; Read elapsed exposure time
	JMP	<FINISH1

; Pause the exposure - close the shutter and stop the timer
PAUSE_EXPOSURE
	MOVEP	X:TCR0,X:ELAPSED_TIME	; Save the elapsed exposure time
	BCLR    #TIM_BIT,X:TCSR0	; Disable the DSP exposure timer
	JSR	<CSHUT			; Close the shutter
	JMP	<FINISH

; Resume the exposure - open the shutter if needed and restart the timer
RESUME_EXPOSURE
	MOVEP	X:ELAPSED_TIME,X:TLR0	; Restore elapsed exposure time
	BSET	#TIM_BIT,X:TCSR0	; Re-enable the DSP exposure timer
	JCLR	#SHUT,X:STATUS,L_RES
	JSR	<OSHUT			; Open the shutter if necessary
L_RES	JMP	<FINISH

; Abort exposure - close the shutter, stop the timer and resume idle mode
ABORT_EXPOSURE
	JSR	<CSHUT			; Close the shutter
	BCLR    #TIM_BIT,X:TCSR0	; Disable the DSP exposure timer
	JCLR	#IDLMODE,X:<STATUS,NO_IDL2 ; Don't idle after readout
	MOVE	#IDLE,R0
	MOVE	R0,X:<IDL_ADR
	JMP	<RDC_E2
NO_IDL2	MOVE	#TST_RCV,R0
	MOVE	R0,X:<IDL_ADR
RDC_E2	JSR	<WAIT_TO_FINISH_CLOCKING
	BCLR	#ST_RDC,X:<STATUS	; Set status to not reading out
	DO      #4000,*+3		; Wait 40 microsec for the fiber
	NOP				;  optic to clear out 
	JMP	<FINISH

; Generate a synthetic image by simply incrementing the pixel counts
SYNTHETIC_IMAGE
	CLR	A
	DO      Y:<NPR,LPR_TST      	; Loop over each line readout
	DO      Y:<NSR,LSR_TST		; Loop over number of pixels per line
	REP	#20			; #20 => 1.0 microsec per pixel
	NOP
	ADD	#1,A			; Pixel data = Pixel data + 1
	NOP
	MOVE	A,B
	JSR	<XMT_PIX		;  transmit them
	NOP
LSR_TST	
	NOP
LPR_TST	
        JMP     <RDC_END		; Normal exit

; Transmit the 16-bit pixel datum in B1 to the host computer
XMT_PIX	ASL	#16,B,B
	NOP
	MOVE	B2,X1
	ASL	#8,B,B
	NOP
	MOVE	B2,X0
	NOP
	MOVEP	X1,Y:WRFO
	MOVEP	X0,Y:WRFO
	RTS

; Test the hardware to read A/D values directly into the DSP instead
;   of using the SXMIT option, A/Ds #2 and 3.
READ_AD	MOVE	X:(RDAD+2),B
	ASL	#16,B,B
	NOP
	MOVE	B2,X1
	ASL	#8,B,B
	NOP
	MOVE	B2,X0
	NOP
	MOVEP	X1,Y:WRFO
	MOVEP	X0,Y:WRFO
	REP	#10
	NOP
	MOVE	X:(RDAD+3),B
	ASL	#16,B,B
	NOP
	MOVE	B2,X1
	ASL	#8,B,B
	NOP
	MOVE	B2,X0
	NOP
	MOVEP	X1,Y:WRFO
	MOVEP	X0,Y:WRFO
	REP	#10
	NOP
	RTS

; Alert the PCI interface board that images are coming soon
PCI_READ_IMAGE
	MOVE	#$020104,B		; Send header word to the FO xmtr
	JSR	<XMT_WRD
	MOVE	#'RDA',B
	JSR	<XMT_WRD
	MOVE	Y:NSR,B			; Number of columns to read
	JSR	<XMT_WRD
	MOVE	Y:NPR,B			; Number of rows to read
	JSR	<XMT_WRD
	RTS

; Wait for the clocking to be complete before proceeding
WAIT_TO_FINISH_CLOCKING
	JSET	#SSFEF,X:PDRD,*		; Wait for the SS FIFO to be empty
	RTS

; Delay for serial writes to the PALs and DACs by 8 microsec
PAL_DLY	DO	#800,*+3		; Wait 8 usec for serial data xmit
	NOP
	RTS

; Let the host computer read the controller configuration
READ_CONTROLLER_CONFIGURATION
	MOVE	Y:<CONFIG,Y1		; Just transmit the configuration
	JMP	<FINISH1

; Set the video processor gain:   SGN  #Board	#GAIN  #Time Constant	(0 TO 15)	
SET_GAIN
	BSET	#3,X:PCRD	; Turn on the serial clock
	JSR	<PAL_DLY
	MOVE	X:(R3)+,A	; Board number
	LSL	#20,A		
	MOVE	#$0D0000,X0
	MOVE	A1,X1
	OR	X0,A
	MOVE	X:(R3)+,X0	; Gain
	OR	X0,A
	JSR	<XMIT_A_WORD	; Transmit A to TIM-A-STD
	
	MOVE	X:(R3)+,A	; Time constant
	LSL	#4,A
	OR	X1,A1		; Board number is in bits #23-20
	MOVE	#$0C0100,X0
	OR	X0,A
	JSR	<XMIT_A_WORD	; Transmit A to TIM-A-STD
	JSR	<PAL_DLY
	BCLR	#3,X:PCRD	; Turn off the serial clock
	JMP	<FINISH

; **********************************************************************************************	
; Set a particular DAC numbers, for setting DC bias voltages, clock driver  
;   voltages and video processor offset
; This is code for the ARC32 clock driver and ARC47 CCD video processor
;
; SBN  #BOARD  #DAC  ['CLK' or 'VID'] voltage
;
;				#BOARD is from 0 to 15
;				#DAC number
;				#voltage is from 0 to 255 for ARC-32, to 16383 for ARC-47

SET_BIAS_NUMBER			; Set bias number
	BSET	#3,X:PCRD	; Turn on the serial clock
	MOVE	X:(R3)+,A	; First argument is board number, 0 to 15
	LSL	#20,A
	NOP
	MOVE	A,X1		; Board number is in X1 bits #23-20
	MOVE	X:(R3)+,A	; Second argument is DAC number
	MOVE	X:(R3)+,B	; Third argument is 'VID' or 'CLK' string
	CMP	#'VID',B
	JEQ	<VID_SBN
	CMP	#'CLK',B
	JNE	<ERR_SBN

; Clock driver board
	MOVE	A1,B		; DAC number, 0 to 23
	LSL	#14,A
	MOVE	#$0E0000,X0
	AND	X0,A
	MOVE	#>7,X0
	AND	X0,B		; Get 3 least significant bits of clock #
	CMP	#0,B
	JNE	<CLK_1
	BSET	#8,A
	JMP	<BD_SET
CLK_1	CMP	#1,B
	JNE	<CLK_2
	BSET	#9,A
	JMP	<BD_SET
CLK_2	CMP	#2,B
	JNE	<CLK_3
	BSET	#10,A
	JMP	<BD_SET
CLK_3	CMP	#3,B
	JNE	<CLK_4
	BSET	#11,A
	JMP	<BD_SET
CLK_4	CMP	#4,B
	JNE	<CLK_5
	BSET	#13,A
	JMP	<BD_SET
CLK_5	CMP	#5,B
	JNE	<CLK_6
	BSET	#14,A
	JMP	<BD_SET
CLK_6	CMP	#6,B
	JNE	<CLK_7
	BSET	#15,A
	JMP	<BD_SET
CLK_7	CMP	#7,B
	JNE	<BD_SET
	BSET	#16,A

BD_SET	OR	X1,A		; Add on the board number
	NOP
	MOVE	A,X0
	MOVE	X:(R3)+,A	; Fourth argument is voltage value, 0 to $FF
	REP	#4
	LSR	A		; Convert 12 bits to 8 bits for ARC32
	MOVE	#>$FF,Y0	; Mask off just 8 bits
	AND	Y0,A
	OR	X0,A
	NOP
	MOVE	A1,Y:0		; Save the DAC number for a little while
	JSR	<XMIT_A_WORD	; Transmit A to TIM-A-STD
	JSR	<PAL_DLY	; Wait for the number to be sent
	BCLR	#3,X:PCRD	; Turn the serial clock off
	JMP	<FINISH
ERR_SBN	MOVE	X:(R3)+,A	; Read and discard the fourth argument
	BCLR	#3,X:PCRD	; Turn the serial clock off
	JMP	<ERROR

; DC bias supply on the ARC-47 video board, excluding video offsets
VID_SBN	CMP	#0,A
	JNE	<CMP1V
	MOVE	#$0E0000,A	; Magic number for channel #0, Vod0
	OR	X1,A		; Add on the board number
	JMP	<SVO_XMT	; Pin #52
CMP1V	CMP	#1,A
	JNE	<CMP2V
	MOVE	#$0E0004,A	; Magic number for channel #1, Vrd0
	OR	X1,A		; Pin #13
	JMP	<SVO_XMT
CMP2V	CMP	#2,A
	JNE	<CMP3V
	MOVE	#$0E0008,A	; Magic number for channel #2, Vog0
	OR	X1,A		; Pin #29
	JMP	<SVO_XMT
CMP3V	CMP	#3,A
	JNE	<CMP4V
	MOVE	#$0E000C,A	; Magic number for channel #3, Vrsv0
	OR	X1,A		; Pin #5
	JMP	<SVO_XMT

CMP4V	CMP	#4,A
	JNE	<CMP5V
	MOVE	#$0E0001,A	; Magic number for channel #4, Vod1
	OR	X1,A		; Pin #32
	JMP	<SVO_XMT
CMP5V	CMP	#5,A
	JNE	<CMP6V
	MOVE	#$0E0005,A	; Magic number for channel #5, Vrd1
	OR	X1,A		; Pin #55
	JMP	<SVO_XMT
CMP6V	CMP	#6,A
	JNE	<CMP7V
	MOVE	#$0E0009,A	; Magic number for channel #6, Vog1
	OR	X1,A		; Pin #8
	JMP	<SVO_XMT
CMP7V	CMP	#7,A
	JNE	<CMP8V
	MOVE	#$0E000D,A	; Magic number for channel #7, Vrsv1
	OR	X1,A		; Pin #47
	JMP	<SVO_XMT

CMP8V	CMP	#8,A
	JNE	<CMP9V
	MOVE	#$0E0002,A	; Magic number for channel #8, Vod2
	OR	X1,A		; Pin #11
	JMP	<SVO_XMT
CMP9V	CMP	#9,A
	JNE	<CMP10V
	MOVE	#$0E0006,A	; Magic number for channel #9, Vrd2
	OR	X1,A		; Pin #35
	JMP	<SVO_XMT
CMP10V	CMP	#10,A
	JNE	<CMP11V
	MOVE	#$0E000A,A	; Magic number for channel #10, Vog2
	OR	X1,A		; Pin #50
	JMP	<SVO_XMT
CMP11V	CMP	#11,A
	JNE	<CMP12V
	MOVE	#$0E000E,A	; Magic number for channel #11, Vrsv2
	OR	X1,A		; Pin #27
	JMP	<SVO_XMT
	
CMP12V	CMP	#12,A
	JNE	<CMP13V
	MOVE	#$0E0003,A	; Magic number for channel #12, Vod3
	OR	X1,A		; Pin #53
	JMP	<SVO_XMT
CMP13V	CMP	#13,A
	JNE	<CMP14V
	MOVE	#$0E0007,A	; Magic number for channel #13, Vrd3
	OR	X1,A		; Pin #14
	JMP	<SVO_XMT
CMP14V	CMP	#14,A
	JNE	<CMP15V
	MOVE	#$0E000B,A	; Magic number for channel #14, Vog3
	OR	X1,A		; Pin #30
	JMP	<SVO_XMT
CMP15V	CMP	#15,A
	JNE	<CMP12V
	MOVE	#$0E000F,A	; Magic number for channel #15, Vrsv3
	OR	X0,A		; Pin #6

CMP16V	CMP	#16,A
	JNE	<CMP17V
	MOVE	#$0E0003,A	; Magic number for channel #12, Vod3
	OR	X1,A		; Pin #33
	JMP	<SVO_XMT
CMP17V	CMP	#17,A
	JNE	<CMP18V
	MOVE	#$0E0007,A	; Magic number for channel #13, Vrd3
	OR	X1,A		; Pin #56
	JMP	<SVO_XMT
CMP18V	CMP	#18,A
	JNE	<CMP19V
	MOVE	#$0E000B,A	; Magic number for channel #14, Vog3
	OR	X1,A		; Pin #9
	JMP	<SVO_XMT
CMP19V	CMP	#19,A
	JNE	<ERR_SBN
	MOVE	#$0E000F,A	; Magic number for channel #15, Vrsv3
	OR	X0,A		; Pin #48

; Set the video offset for the ARC-47 4-channel CCD video board
; SVO  #Board  #Channel  #Voltage	Board number is from 0 to 15
;					DAC number from 0 to 7
;					Voltage number is from 0 to 16,383 (14 bits)

SET_VIDEO_OFFSET
	BSET	#3,X:PCRD	; Turn on the serial clock
	MOVE	X:(R3)+,A	; First argument is board number, 0 to 15
	TST	A
	JLT	<ERR_SV1
	CMP	#15,A
	JGT	<ERR_SV1
	LSL	#20,A
	NOP
	MOVE	A,X1		; Board number is in bits #23-20
	MOVE	X:(R3)+,A	; Second argument is the video channel number
	CMP	#0,A
	JNE	<CMP1
	MOVE	#$0E0014,A	; Magic number for channel #0
	OR	X1,A
	JMP	<SVO_XMT
CMP1	CMP	#1,A
	JNE	<CMP2
	MOVE	#$0E0015,A	; Magic number for channel #1
	OR	X1,A
	JMP	<SVO_XMT
CMP2	CMP	#2,A
	JNE	<CMP3
	MOVE	#$0E0016,A	; Magic number for channel #2
	OR	X1,A
	JMP	<SVO_XMT
CMP3	CMP	#3,A
	JNE	<CMP4
	MOVE	#$0E0017,A	; Magic number for channel #3
	OR	X1,A
	JMP	<SVO_XMT
CMP4	CMP	#4,A
	JNE	<ERR_SV3

SVO_XMT	MOVE	A1,Y:0

	JSR	<XMIT_A_WORD	; Transmit A to TIM-A-STD
	JSR	<PAL_DLY	; Wait for the number to be sent	
	MOVE	X:(R3)+,A	; Third argument is the DAC voltage number
	TST	A
	JLT	<ERR_SV3	; Voltage number needs to be positive
	CMP	#$3FFF,A	; Voltage number needs to be 14 bits
	JGT	<ERR_SV3
	OR	X1,A		; Add in the board number
	OR	#$0FC000,A
	NOP
	MOVE	A1,Y:1
	JSR	<XMIT_A_WORD	; Transmit A to TIM-A-STD
	JSR	<PAL_DLY
	BCLR	#3,X:PCRD	; Turn off the serial clock
	JMP	<FINISH	
ERR_SV1	BCLR	#3,X:PCRD	; Turn off the serial clock
	MOVE	X:(R3)+,A
	MOVE	X:(R3)+,A
	JMP	<ERROR
ERR_SV2	BCLR	#3,X:PCRD	; Turn off the serial clock
	MOVE	X:(R3)+,A
	JMP	<ERROR
ERR_SV3	BCLR	#3,X:PCRD	; Turn off the serial clock
	JMP	<ERROR

; Specify the MUX value to be output on the clock driver board
; Command syntax is  SMX  #clock_driver_board #MUX1 #MUX2
;				#clock_driver_board from 0 to 15
;				#MUX1, #MUX2 from 0 to 23

SET_MUX	BSET	#3,X:PCRD	; Turn on the serial clock
	MOVE	X:(R3)+,A	; Clock driver board number
	REP	#20
	LSL	A
	MOVE	#$001000,X0	; Bits to select MUX on ARC32 board
	OR	X0,A
	NOP
	MOVE	A1,X1		; Move here for later use
	
; Get the first MUX number
	MOVE	X:(R3)+,A	; Get the first MUX number
	TST	A
	JLT	<ERR_SM1
	MOVE	#>24,X0		; Check for argument less than 32
	CMP	X0,A
	JGE	<ERR_SM1
	MOVE	A,B
	MOVE	#>7,X0
	AND	X0,B
	MOVE	#>$18,X0
	AND	X0,A
	JNE	<SMX_1		; Test for 0 <= MUX number <= 7
	BSET	#3,B1
	JMP	<SMX_A
SMX_1	MOVE	#>$08,X0
	CMP	X0,A		; Test for 8 <= MUX number <= 15
	JNE	<SMX_2
	BSET	#4,B1
	JMP	<SMX_A
SMX_2	MOVE	#>$10,X0
	CMP	X0,A		; Test for 16 <= MUX number <= 23
	JNE	<ERR_SM1
	BSET	#5,B1
SMX_A	OR	X1,B1		; Add prefix to MUX numbers
	NOP
	MOVE	B1,Y1

; Add on the second MUX number
	MOVE	X:(R3)+,A	; Get the next MUX number
	TST	A
	JLT	<ERR_SM2
	MOVE	#>24,X0		; Check for argument less than 32
	CMP	X0,A
	JGE	<ERR_SM2
	REP	#6
	LSL	A
	NOP
	MOVE	A,B
	MOVE	#$1C0,X0
	AND	X0,B
	MOVE	#>$600,X0
	AND	X0,A
	JNE	<SMX_3		; Test for 0 <= MUX number <= 7
	BSET	#9,B1
	JMP	<SMX_B
SMX_3	MOVE	#>$200,X0
	CMP	X0,A		; Test for 8 <= MUX number <= 15
	JNE	<SMX_4
	BSET	#10,B1
	JMP	<SMX_B
SMX_4	MOVE	#>$400,X0
	CMP	X0,A		; Test for 16 <= MUX number <= 23
	JNE	<ERR_SM2
	BSET	#11,B1
SMX_B	ADD	Y1,B		; Add prefix to MUX numbers
	NOP
	MOVE	B1,A
	AND	#$F01FFF,A	; Just to be sure
	JSR	<XMIT_A_WORD	; Transmit A to TIM-A-STD
	JSR	<PAL_DLY	; Delay for all this to happen
	BCLR	#3,X:PCRD	; Turn the serial clock off
	JMP	<FINISH
ERR_SM1	MOVE	X:(R3)+,A	; Throw off the last argument
ERR_SM2	BCLR	#3,X:PCRD	; Turn the serial clock off
	JMP	<ERROR

; Specify subarray readout coordinates, one rectangle only
SET_SUBARRAY_SIZES
	CLR	A
	NOP	
	MOVE	A,Y:<NBOXES		; Number of subimage boxes = 0 to start
	MOVE    X:(R3)+,X0
	MOVE	X0,Y:<NR_BIAS		; Number of bias pixels to read
	MOVE    X:(R3)+,X0
	MOVE	X0,Y:<NS_READ		; Number of columns in subimage read
	MOVE    X:(R3)+,X0
	MOVE	X0,Y:<NP_READ		; Number of rows in subimage read	
	BCLR	#ST_SA,X:STATUS		; Not in subarray mode until 'SSP'
	JMP	<FINISH			;   is executed

; Call this routine once for every subarray to be added to the table
SET_SUBARRAY_POSITIONS
	MOVE	Y:<NBOXES,A
	MOVE	#>10,X0
	CMP	X0,A
	JGE	<ERROR		; Error if number of boxes > 10
	MOVE	A1,X0
	MOVE	X:<THREE,X1
	MPY	X0,X1,A
	ASR	A
	MOVE	A0,A1

	MOVE	#READ_TABLE,X0
	ADD	X0,A
	NOP
	MOVE	A1,R7
	MOVE	X:(R3)+,X0
	NOP
	NOP
	MOVE	X0,Y:(R7)+	; Number of rows (parallels) to clear
	MOVE	X:(R3)+,X0
	MOVE	X0,Y:(R7)+	; Number of columns (serials) clears before
	MOVE	X:(R3)+,X0	;  the box readout
	MOVE	X0,Y:(R7)+	; Number of columns (serials) clears after	
	MOVE	Y:<NBOXES,A
	MOVE	X:<ONE,X0
	ADD	X0,A
	NOP
	MOVE	A1,Y:<NBOXES
	BSET	#ST_SA,X:STATUS
	JMP	<FINISH

; Generate the serial readout waveform table for the chosen
;   value of readout and serial binning.

GENERATE_SERIAL_WAVEFORM	; Generate the serial waveform table
	MOVE	#(PXL_TBL+1),R1
	MOVE	Y:<NSBIN,A
	SUB	#1,A
	JLE	<NO_BIN		
	DO	A1,L_BIN
	MOVE	Y:CLOCK_LINE,R0
	NOP
	NOP
	MOVE	Y:(R0)+,A
	NOP
	DO	A1,L_CLOCK_LINE
	MOVE	Y:(R0)+,X0
	MOVE	X0,Y:(R1)+
L_CLOCK_LINE
	NOP
L_BIN

; Generate the rest of the waveform table
NO_BIN	MOVE	Y:<SERIAL_READ,R0
	NOP
	NOP
	NOP
	MOVE	Y:(R0)+,A
	NOP
	DO	A1,L_RD
	MOVE	Y:(R0)+,X0
	JSR	<SEARCH_FOR_SXMIT
	MOVE	X0,Y:(R1)+
L_RD

; Finally, calculate the number of entries in the waveform table just generated
	MOVE	#PXL_TBL,X0
	MOVE	X0,R0
	MOVE	R1,A
	SUB	X0,A
	SUB	#1,A
	NOP
	MOVE	A1,Y:(R0)
	RTS
	
; Search for SXMIT in the PXL_TBL for use in processing the PRESCAN columns
SEARCH_FOR_SXMIT
	MOVE	X0,A
	AND	#$00F000,A
	CMP	#$00F000,A
	JNE	<NOT_SX
	MOVE	R1,Y:<SXMIT_ADR
NOT_SX	RTS
	
; Select the amplifier and readout mode
;   'SOS'  Amplifier_name = '__C', '__D', '__B', '__A' or 'ALL'
;   			 or 0 (LL), 1 (LR), 2 (UR) or 3 (UL)
;			 or '_LL', '_LR', '_UR' or '_UL'
		
SELECT_OUTPUT_SOURCE
	MOVE    X:(R3)+,Y0
	MOVE	Y0,Y:<OS
	BSET	#3,X:PCRD			; Turn on the serial clock
	JSR	<PAL_DLY			; Delay for all this to happen
	JSR	<SEL_OS
	JSR	<PAL_DLY
	BCLR	#3,X:PCRD			; Turn off the serial clock
	JMP	<FINISH

SEL_OS
;	MOVE	#DC_DEFAULT,R0			; See DC_CH2 below
;	JSR	<WR_DACS	
	MOVE	Y:<OS,A
	CMP	#'ALL',A			; All Amplifiers = readout #0 to #3
	JNE	<CMP_LL

	MOVE	#PARALLEL_SPLIT,X0
	MOVE	X0,Y:PARALLEL
	MOVE	#EXPOSE_SPLIT,X0
	MOVE	X0,Y:<EXPOSE_PARALLELS

	MOVE	#SERIAL_SKIP_SPLIT,X0
	MOVE	X0,Y:SERIAL_SKIP
	MOVE	#CLOCK_LINE_SPLIT,X0
	MOVE	X0,Y:CLOCK_LINE
	MOVE	#$00F0C0,X0
	MOVE	X0,Y:SXMIT
	BSET	#SPLIT_S,X:STATUS
	BSET	#SPLIT_P,X:STATUS
	MOVE	Y:<PXL_SPEED,A
	CMP	#'FST',A			; Fast reaout, ~1 MHz
	JNE	<CMP_MEDIUM_SPLIT
	MOVE	#SERIAL_READ_SPLIT_FAST,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_SPLIT_FAST,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_FAST,A
	JSR	<XMIT_A_WORD

	MOVE	#DAC_ADDR+$000014,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LL_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000015,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LR_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000016,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UR_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000017,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UL_FAST,A
	JSR	<XMIT_A_WORD
	RTS
	
CMP_MEDIUM_SPLIT
	MOVE	Y:<PXL_SPEED,A
	CMP	#'MED',A			; Value for medium readout, 400 kHz 
	JNE	<SLOW_SPLIT
	MOVE	#SERIAL_READ_SPLIT_MED,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_SPLIT_MED,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000014,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LL_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000015,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LR_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000016,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UR_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000017,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UL_MED,A
	JSR	<XMIT_A_WORD

	RTS
		
SLOW_SPLIT					; Value for slow readout, 100 kHz
	MOVE	#SERIAL_READ_SPLIT_SLOW,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_SPLIT_SLOW,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000014,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LL_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000015,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LR_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000016,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UR_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000017,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UL_SLOW,A
	JSR	<XMIT_A_WORD

	RTS

CMP_LL	MOVE	Y:<OS,A				; Lower left readout, #0	
	CMP	#'__C',A
	JEQ	<EQ_LL
	CMP	#'_LL',A
	JEQ	<EQ_LL
	CMP	#0,A
	JNE	<CMP_LR
EQ_LL	MOVE	#PARALLEL_DOWN_LEFT,X0
	MOVE	X0,Y:PARALLEL
	MOVE	#EXPOSE_DOWN,X0
	MOVE	X0,Y:<EXPOSE_PARALLELS

	MOVE	#SERIAL_SKIP_LEFT,X0
	MOVE	X0,Y:SERIAL_SKIP
	MOVE	#CLOCK_LINE_LEFT,X0
	MOVE	X0,Y:CLOCK_LINE
	MOVE	#$00F000,X0
	MOVE	X0,Y:SXMIT
	MOVE	X0,Y:SXMIT_LEFT_SLOW
	MOVE	X0,Y:SXMIT_LEFT_MED
	MOVE	X0,Y:SXMIT_LEFT_FAST
	
	BCLR	#SPLIT_S,X:STATUS
	BCLR	#SPLIT_P,X:STATUS

	MOVE	Y:<PXL_SPEED,A
	CMP	#'FST',A
	JNE	<CMP_MEDIUM_LL
	MOVE	#SERIAL_READ_LEFT_FAST,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_LEFT_FAST,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000014,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LL_FAST,A
	JSR	<XMIT_A_WORD
	RTS
		
CMP_MEDIUM_LL
	MOVE	Y:<PXL_SPEED,A
	CMP	#'MED',A
	JNE	<SLOW_LL
	MOVE	#SERIAL_READ_LEFT_MED,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_LEFT_MED,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000014,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LL_MED,A
	JSR	<XMIT_A_WORD
	RTS

SLOW_LL	MOVE	#SERIAL_READ_LEFT_SLOW,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_LEFT_SLOW,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000014,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LL_SLOW,A
	JSR	<XMIT_A_WORD
	RTS

CMP_LR	MOVE	Y:<OS,A				; Lower right readout, #1
	CMP	#'__D',A
	JEQ	<EQ_LR
	CMP	#'_LR',A
	JEQ	<EQ_LR
	CMP	#1,A
	JNE	<CMP_UR
EQ_LR	MOVE	#PARALLEL_DOWN_RIGHT,X0
	MOVE	X0,Y:PARALLEL
	MOVE	#EXPOSE_DOWN,X0
	MOVE	X0,Y:<EXPOSE_PARALLELS
	
	MOVE	#SERIAL_SKIP_RIGHT,X0
	MOVE	X0,Y:SERIAL_SKIP
	MOVE	#CLOCK_LINE_RIGHT,X0
	MOVE	X0,Y:CLOCK_LINE
	MOVE	#$00F041,X0
	MOVE	X0,Y:SXMIT
	MOVE	X0,Y:SXMIT_RIGHT_FAST
	MOVE	X0,Y:SXMIT_RIGHT_MED
	MOVE	X0,Y:SXMIT_RIGHT_SLOW
	
	BCLR	#SPLIT_S,X:STATUS
	BCLR	#SPLIT_P,X:STATUS

	MOVE	Y:<PXL_SPEED,A
	CMP	#'FST',A
	JNE	<CMP_MEDIUM_LR
	MOVE	#SERIAL_READ_RIGHT_FAST,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_RIGHT_FAST,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000015,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LR_FAST,A
	JSR	<XMIT_A_WORD
	RTS
	
CMP_MEDIUM_LR
	MOVE	Y:<PXL_SPEED,A
	CMP	#'MED',A
	JNE	<SLOW_LR
	MOVE	#SERIAL_READ_RIGHT_MED,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_RIGHT_MED,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000015,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LR_MED,A
	JSR	<XMIT_A_WORD
	RTS
	
SLOW_LR	MOVE	#SERIAL_READ_RIGHT_SLOW,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_RIGHT_SLOW,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000015,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_LR_SLOW,A
	JSR	<XMIT_A_WORD
	RTS
	
CMP_UR	MOVE	Y:<OS,A				; Upper right readout, #2
	CMP	#'__B',A
	JEQ	<EQ_UR
	CMP	#'_UR',A
	JEQ	<EQ_UR
	CMP	#2,A
	JNE	<CMP_UL
EQ_UR	MOVE	#PARALLEL_UP_RIGHT,X0
	MOVE	X0,Y:PARALLEL
	MOVE	#EXPOSE_UP,X0
	MOVE	X0,Y:<EXPOSE_PARALLELS
	
	MOVE	#SERIAL_SKIP_RIGHT,X0
	MOVE	X0,Y:SERIAL_SKIP
	MOVE	#CLOCK_LINE_RIGHT,X0
	MOVE	X0,Y:CLOCK_LINE
	MOVE	#$00F082,X0
	MOVE	X0,Y:SXMIT
	MOVE	X0,Y:SXMIT_RIGHT_FAST
	MOVE	X0,Y:SXMIT_RIGHT_MED
	MOVE	X0,Y:SXMIT_RIGHT_SLOW
;	MOVE	#DC_CH2,R0			; Special serial low value for Channel 2
;	JSR	<WR_DACS
	BCLR	#SPLIT_S,X:STATUS
	BCLR	#SPLIT_P,X:STATUS

	MOVE	Y:<PXL_SPEED,A
	CMP	#'FST',A
	JNE	<CMP_MEDIUM_UR
	MOVE	#SERIAL_READ_RIGHT_FAST,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_RIGHT_FAST,X0
	MOVE	X0,Y:<ADR_SXMIT

	MOVE	#GAIN_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_FAST,A
	JSR	<XMIT_A_WORD

	MOVE	#DAC_ADDR+$000016,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UR_FAST,A
	JSR	<XMIT_A_WORD
	RTS
	
CMP_MEDIUM_UR
	MOVE	Y:<PXL_SPEED,A
	CMP	#'MED',A
	JNE	<SLOW_UR
	MOVE	#SERIAL_READ_RIGHT_MED,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_RIGHT_MED,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000016,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UR_MED,A
	JSR	<XMIT_A_WORD
	RTS
	
SLOW_UR	MOVE	#SERIAL_READ_RIGHT_SLOW,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_RIGHT_SLOW,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000016,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UR_SLOW,A
	JSR	<XMIT_A_WORD
	RTS
	
CMP_UL	MOVE	Y:<OS,A					; Upper left readout, #3
	CMP	#'__A',A
	JEQ	<EQ_UL
	CMP	#'_UL',A
	JEQ	<EQ_UL
	CMP	#3,A
	JNE	<ERROR
EQ_UL	MOVE	#PARALLEL_UP_LEFT,X0
	MOVE	X0,Y:PARALLEL
	MOVE	#EXPOSE_UP,X0
	MOVE	X0,Y:<EXPOSE_PARALLELS
	
	MOVE	#SERIAL_SKIP_LEFT,X0
	MOVE	X0,Y:SERIAL_SKIP
	MOVE	#CLOCK_LINE_LEFT,X0
	MOVE	X0,Y:CLOCK_LINE
	MOVE	#$00F0C3,X0
	MOVE	X0,Y:SXMIT
	MOVE	X0,Y:SXMIT_LEFT_FAST
	MOVE	X0,Y:SXMIT_LEFT_MED
	MOVE	X0,Y:SXMIT_LEFT_SLOW
	BCLR	#SPLIT_S,X:STATUS
	BCLR	#SPLIT_P,X:STATUS

	MOVE	Y:<PXL_SPEED,A
	CMP	#'FST',A
	JNE	<CMP_MEDIUM_UL
	MOVE	#SERIAL_READ_LEFT_FAST,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_LEFT_FAST,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_FAST,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000017,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UL_FAST,A
	JSR	<XMIT_A_WORD
	RTS
	
CMP_MEDIUM_UL
	MOVE	Y:<PXL_SPEED,A
	CMP	#'MED',A
	JNE	<SLOW_UL
	MOVE	#SERIAL_READ_LEFT_MED,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_LEFT_MED,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_MED,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000017,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UL_MED,A
	JSR	<XMIT_A_WORD
	RTS
	
SLOW_UL	MOVE	#SERIAL_READ_LEFT_SLOW,X0
	MOVE	X0,Y:SERIAL_READ
	MOVE	#SXMIT_LEFT_SLOW,X0
	MOVE	X0,Y:<ADR_SXMIT
	MOVE	#GAIN_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#TIME_CONSTANT_SLOW,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_ADDR+$000017,A
	JSR	<XMIT_A_WORD
	MOVE	#DAC_RegD+OFFSET_UL_SLOW,A
	JSR	<XMIT_A_WORD
	RTS

SELECT_PIXEL_SPEED			; 'SLW', 'MED' or 'FST'
	MOVE	X:(R3)+,A 
	CMP	#'SLW',A
	JEQ	<SPS_END
	CMP	#'MED',A
	JEQ	<SPS_END
	CMP	#'FST',A
	JEQ	<SPS_END
	JMP	<ERROR

SPS_END	MOVE	A1,Y:<PXL_SPEED
	BSET	#3,X:PCRD		; Turn on the serial clock
	JSR	<PAL_DLY		; Delay for all this to happen
	JSR	<SEL_OS
	JSR	<PAL_DLY
	BCLR	#3,X:PCRD		; Turn off the serial clock
	JMP	<FINISH

; Move the image UP by the indicated number of lines
MOVE_PARALLEL_UP
	MOVE	X:(R3)+,X0
	DO	X0,L_UP
	MOVE	#PARALLEL_UP_LEFT,R0
	CLOCK
L_UP

; Move the image DOWN by the indicated number of lines
MOVE_PARALLEL_DOWN
	MOVE	X:(R3)+,X0
	DO	X0,L_DOWN
	MOVE	#PARALLEL_DOWN_LEFT,R0
	CLOCK
L_DOWN

; Move the image both up and down by the indicated number of lines
MOVE_PARALLEL_SPLIT
	DO	X:(R3)+,L_SPLIT
	MOVE	#PARALLEL_SPLIT,R0
	CLOCK
L_SPLIT

; Skip over the pre-scan pixels by not transmitting A/D data in PXL_TBL
SKIP_PRESCAN_PIXELS
	MOVE	Y:<ADR_SXMIT,R5	
	NOP
	MOVE	#>%0011000,X0
	MOVE	X0,Y:(R5)		; Overwrite SXMIT with a benign value

; Now clock the CCD prescan pixels
	DO	Y:<X_PRESCAN,L_XPRESCAN
	MOVE	Y:SERIAL_READ,R0
	CLOCK
L_XPRESCAN
	MOVE	Y:<SXMIT,X0		; Restore SXMIT
	MOVE	X0,Y:(R5)
	RTS

; Warm up the video processor by not transmitting A/D data in PXL_TBL
WARM_UP_VP
	MOVE	Y:<SXMIT_ADR,R5	
	NOP
	MOVE	#>%0011000,X0
	MOVE	X0,Y:(R5)		; Overwrite SXMIT with a benign value
	MOVE	#WARM_UP,X0
	DO	X0,L_WARM_UP
	MOVE	#PXL_TBL,R0	
	CLOCK
L_WARM_UP
	MOVE	Y:<SXMIT,X0		; Restore SXMIT
	MOVE	X0,Y:(R5)
	RTS

DITHER	MOVE	Y:<SERIAL_DITHER,R0
	CLOCK
	RTS

SET_DITHER
	MOVE	X:(R3)+,X0
	JCLR	#0,X0,NO_DITH
	BSET	#ST_DITH,X:<STATUS
	JMP	<FINISH
NO_DITH	BCLR	#ST_DITH,X:<STATUS
	JMP	<FINISH

; Skip X rows and Y columns. Zero = 0 indicates no skipping
SKIP_X_Y
	MOVE	X:(R3)+,X0
	MOVE	X0,Y:<X_PRESCAN
	MOVE	X:(R3)+,X0
	MOVE	X0,Y:<Y_PRESCAN
	JMP	<FINISH
