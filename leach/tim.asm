       COMMENT *

This file supports the ARC-22, ARC-32 and ARC-47 for operating an STA4150A 4k CCD. 
	It supports split serial and parallel readouts, readout from one or four 
	corners, 2x2 binning, multiple subarray, and selection of 100 kHz, 400 kHz
	or 1000 kHz pixel rates.

	*
	PAGE    132     ; Printronix page width - 132 columns

; Include the boot file so addressing is easy
	INCLUDE	"timboot.asm"
	
	ORG	P:,P:

CC	EQU	ARC22+ARC47+SHUTTER_CC+SPLIT_PARALLEL+SPLIT_SERIAL+SUBARRAY+BINNING+READOUT_SPEEDS

; Put number of words of application in P: for loading application from EEPROM
	DC	TIMBOOT_X_MEMORY-@LCV(L)-1

; Define CLOCK as a macro to produce in-line code to reduce execution time
CLOCK	MACRO
	JCLR	#SSFHF,X:HDR,*		; Don't overfill the WRSS FIFO
	REP	Y:(R0)+			; Repeat
	MOVEP	Y:(R0)+,Y:WRSS		; Write the waveform to the FIFO
	ENDM

PARALLEL_CLOCK
	JCLR	#SSFHF,X:HDR,*		; Don't overfill the WRSS FIFO
	DO	Y:(R0)+,L_LINE		; Repeat
	REP	#NUM_REPEATS
	MOVEP	Y:(R0),Y:WRSS		; Write the waveform to the FIFO
	MOVE	(R0)+
L_LINE
	RTS

; Set software to IDLE mode
START_IDLE_CLOCKING
	MOVE	#IDLE,R0		; Exercise clocks when idling
	MOVE	R0,X:<IDL_ADR
	BSET	#IDLMODE,X:<STATUS	; Idle after readout
	JMP     <FINISH			; Need to send header and 'DON'

; Keep the CCD idling when not reading out
IDLE	DO      Y:<NSR,IDL1     	; Loop over number of pixels per line
	MOVE    #<SERIAL_IDLE,R0 	; Serial transfer on pixel
	CLOCK  				; Go to it
	MOVE	#COM_BUF,R3
	JSR	<GET_RCV		; Check for FO or SSI commands
	JCC	<NO_COM			; Continue IDLE if no commands received
	ENDDO
	JMP     <PRC_RCV		; Go process header and command
NO_COM	NOP
IDL1
	MOVE    #<PARALLEL_SPLIT,R0	; Address of parallel clocking waveform
	JSR	<PARALLEL_CLOCK  	; Go clock out the CCD charge
	JMP     <IDLE

;  *****************  Exposure and readout routines  *****************
RDCCD	CLR	A
	JSET	#ST_SA,X:STATUS,SUB_IMG
	MOVE	A1,Y:<NP_SKIP		; Zero the subarray parameters
	MOVE	A1,Y:<NS_SKP1
	MOVE	A1,Y:<NS_SKP2
	MOVE	A1,Y:<N_BIAS
	MOVE	Y:<NSR,A
	JCLR	#SPLIT_S,X:STATUS,*+3
	ASR	A			; Split serials requires / 2
	NOP
	MOVE	A,Y:<N_COLS		; Number of columns in whole image
	MOVE	Y:<NPR,A		; NPARALLELS_READ = NPR
	JCLR	#SPLIT_P,X:STATUS,*+3
	ASR	A			; Split parallels requires / 2
	NOP
	MOVE	A,Y:<N_ROWS		; Number of rows in whole image
	JMP	<READOUT

; Enter the subarray readout parameters
SUB_IMG	MOVE	Y:<NS_READ,A
	JCLR	#SPLIT_S,X:STATUS,*+3	; Split serials requires / 2
	ASR	A
	NOP
	MOVE	A,Y:<N_COLS		; Number of columns in each subimage
	MOVE	Y:<NR_BIAS,A
	JCLR	#SPLIT_S,X:STATUS,*+3	; Split serials requires / 2
	ASR	A
	NOP
	MOVE	A,Y:<N_BIAS		; Number of columns in the bias region
	MOVE	Y:<NP_READ,A
	JCLR	#SPLIT_P,X:STATUS,*+3	; Split parallels requires / 2
	ASR	A
	NOP
	MOVE	A,Y:<N_ROWS		; Number of rows in each subimage

; Loop over each subarray box
	MOVE	#READ_TABLE,R7		; Parameter table for subimage readout
	DO	Y:<NBOXES,L_NBOXES	; Loop over number of boxes
	MOVE	Y:(R7)+,X0
	MOVE	X0,Y:<NP_SKIP
	MOVE	Y:(R7)+,X0	
	MOVE	X0,Y:<NS_SKP1
	MOVE	Y:(R7)+,X0	
	MOVE	X0,Y:<NS_SKP2

; Skip over the required number of rows for subimage readout
READOUT	JSR	<GENERATE_SERIAL_WAVEFORM
	JSR	<WAIT_TO_FINISH_CLOCKING

; Skip over rows to get a clean readout in binning mode
	DO	Y:<Y_PRESCAN,L_YPRESCAN
	MOVE    Y:<PARALLEL,R0
	JSR	<PARALLEL_CLOCK
	NOP
L_YPRESCAN

; Skip over rows in subarray mode
	DO      Y:<NP_SKIP,L_PSKP	
	DO	Y:<NPBIN,L_PSKIP
	MOVE    Y:<PARALLEL,R0
	JSR	<PARALLEL_CLOCK
	NOP
L_PSKIP	NOP
	DO	#NUM_CLEAN,L_CLEAN
	MOVE	Y:<SERIAL_SKIP,R0	; Waveform table starting address
	CLOCK  				; Go clock out the CCD charge
L_CLEAN	NOP
L_PSKP

; Finally, this is the start of the big readout loop
	DO	Y:<N_ROWS,LPR		; Loop over the number of rows in the image
	DO	Y:<NPBIN,L_PBIN
	MOVE    Y:<PARALLEL,R0
	JSR	<PARALLEL_CLOCK
	NOP
L_PBIN

	JSR	<SKIP_PRESCAN_PIXELS

; Check for a command once per line. Only the ABORT command should be issued.
	MOVE	#COM_BUF,R3
	JSR	<GET_RCV		; Was a command received?
	JCC	<CONTINUE_READ		; If no, continue reading out
	JMP	<PRC_RCV		; If yes, go process it

; Abort the readout currently underway
ABR_RDC	JCLR	#ST_RDC,X:<STATUS,ABORT_EXPOSURE
	ENDDO				; Properly terminate the readout loop
	JCLR	#ST_SA,X:STATUS,*+2
	ENDDO				; Properly terminate the subarray loop
	JMP	<ABORT_EXPOSURE
CONTINUE_READ

; Skip over NS_SKP1 columns if needed for subimage readout
	DO	Y:<NS_SKP1,L_SKP1	; Number of waveform entries total
	DO	Y:<NSBIN,L_SKIP1
	MOVE	Y:<SERIAL_SKIP,R0	; Waveform table starting address
	CLOCK  				; Go clock out the CCD charge
L_SKIP1	NOP
L_SKP1

; Finally, read some real pixels
	DO	Y:<N_COLS,L_READ
	MOVE	#PXL_TBL,R0
	CLOCK
L_READ	

; Skip over NS_SKP2 columns if needed for subimage readout
	DO	Y:<NS_SKP2,L_SKP2
	DO	Y:<NSBIN,L_SKIP2
	MOVE	Y:<SERIAL_SKIP,R0	; Waveform table starting address
	CLOCK  				; Go clock out the CCD charge
L_SKIP2	NOP
L_SKP2

; Read the bias pixels if in subimage readout mode
	DO      Y:<N_BIAS,END_ROW	; Number of pixels to read out
	MOVE	#PXL_TBL,R0
	CLOCK
END_ROW	NOP
LPR	NOP				; End of parallel loop
L_NBOXES				; End of subimage boxes loop

; Restore the controller to non-image data transfer and idling if necessary
RDC_END	JCLR	#IDLMODE,X:<STATUS,NO_IDL
	MOVE	#IDLE,R0
	MOVE	R0,X:<IDL_ADR
	JMP	<RDC_E
NO_IDL	MOVE	#TST_RCV,R0	 	; Don't idle after readout
	MOVE	R0,X:<IDL_ADR
RDC_E	JSR	<WAIT_TO_FINISH_CLOCKING
	BCLR	#ST_RDC,X:<STATUS	; Set status to not reading out
        JMP     <START

; Move the image up or down a set number of lines
MOVE_PARALLEL		; arg0 = '_UP', 'DWN' or 'SPT', arg1 = number of lines
	MOVE	X:(R3)+,A
	CMP	#'_UP',A
	JNE	<C_DOWN
	MOVE	#PARALLEL_UP_LEFT,X0
	MOVE	X0,Y:<MV_ADDR
	JMP	<CLOCK_PARALLEL
	
C_DOWN	CMP	#'DWN',A
	JNE	<C_SPLIT
	MOVE	#PARALLEL_DOWN_LEFT,X0
	MOVE	X0,Y:<MV_ADDR
	JMP	<CLOCK_PARALLEL
	
C_SPLIT	CMP	#'SPT',A
	JNE	<ERROR
	MOVE	#PARALLEL_SPLIT,X0
	MOVE	X0,Y:<MV_ADDR
	
CLOCK_PARALLEL
	DO	X:(R3)+,L_CLOCK_PARALLEL
	MOVE	Y:<MV_ADDR,R0
	CLOCK
L_CLOCK_PARALLEL

	JMP	<FINISH
	
; ******  Include many routines not directly needed for readout  *******
	INCLUDE "timCCDmisc.asm"


TIMBOOT_X_MEMORY	EQU	@LCV(L)

;  ****************  Setup memory tables in X: space ********************

; Define the address in P: space where the table of constants begins

	IF	@SCP("DOWNLOAD","HOST")
	ORG     X:END_COMMAND_TABLE,X:END_COMMAND_TABLE
	ENDIF

	IF	@SCP("DOWNLOAD","ROM")
	ORG     X:END_COMMAND_TABLE,P:
	ENDIF

; Application commands
	DC	'PON',POWER_ON
	DC	'POF',POWER_OFF
	DC	'SBV',SET_BIAS_VOLTAGES
	DC	'IDL',START_IDLE_CLOCKING
	DC	'OSH',OPEN_SHUTTER
	DC	'CSH',CLOSE_SHUTTER
	DC	'RDC',RDCCD    
	DC	'CLR',CLEAR  

; Exposure and readout control routines
	DC	'SET',SET_EXPOSURE_TIME
	DC	'RET',READ_EXPOSURE_TIME
	DC	'SEX',START_EXPOSURE
	DC	'PEX',PAUSE_EXPOSURE
	DC	'REX',RESUME_EXPOSURE
	DC	'AEX',ABORT_EXPOSURE
	DC	'ABR',ABR_RDC
	DC	'CRD',CONTINUE_READ

; Support routines
	DC	'SGN',SET_GAIN      
	DC	'SBN',SET_BIAS_NUMBER
	DC	'SMX',SET_MUX
	DC	'SVO',SET_VIDEO_OFFSET
	DC	'CSW',CLR_SWS
	DC	'SOS',SELECT_OUTPUT_SOURCE
	DC	'SSS',SET_SUBARRAY_SIZES
	DC	'SSP',SET_SUBARRAY_POSITIONS
	DC	'RCC',READ_CONTROLLER_CONFIGURATION
	DC	'SPS',SELECT_PIXEL_SPEED
	DC	'DTH',SET_DITHER
	DC	'SXY',SKIP_X_Y

; Control lines one by one
	DC	'PUP',MOVE_PARALLEL_UP
	DC	'PDN',MOVE_PARALLEL_DOWN
	DC	'PSL',MOVE_PARALLEL_SPLIT

END_APPLICATON_COMMAND_TABLE	EQU	@LCV(L)

	IF	@SCP("DOWNLOAD","HOST")
NUM_COM			EQU	(@LCV(R)-COM_TBL_R)/2	; Number of boot + 
							;  application commands
EXPOSING		EQU	CHK_TIM			; Address if exposing
CONTINUE_READING	EQU	RDCCD	 		; Address if reading out
	ENDIF

	IF	@SCP("DOWNLOAD","ROM")
	ORG     Y:0,P:
	ENDIF

; Now let's go for the timing waveform tables
	IF	@SCP("DOWNLOAD","HOST")
        ORG     Y:0,Y:0
	ENDIF

GAIN	DC	END_APPLICATON_Y_MEMORY-@LCV(L)-1

NSR     	DC      2200 	 	; Number Serial Read, set by host computer
NPR     	DC      2200	     	; Number Parallel Read, set by host computer
NPCLR		DC	NP_CLR		; Lines to clear, quadrant mode
NSCLR		DC	NS_CLR
NSBIN   	DC      1       	; Serial binning parameter
NPBIN   	DC      1       	; Parallel binning parameter
CONFIG		DC	CC		; Controller configuration
OS		DC	'ALL'		; Name of the output source(s)
SXMIT		DC	$00F0C0
SXMIT_ADR 	DC	0		; Address of SXMIT value in PXL_TBL
ADR_SXMIT 	DC	SXMIT_SPLIT_MED	 ; Address of SXMIT value in waveform table
SYN_DAT		DC	0		; Synthetic image mode pixel count
TST_DATA 	DC	0		; For synthetic image
SHDEL		DC	SH_DEL		; Delay from shutter close to start of readout
PRE_SCAN	DC	PRESCAN		; Number of prescan pixels, corrected for
					;   binning
PXL_SPEED	DC	DEFAULT_SPEED	; Pixel readout speed; default is 400 KHZ
X_PRESCAN	DC	0		; Number of columns to skip before readout
Y_PRESCAN	DC	0		; Number of rows to skip before readout

; Waveform table addresses
PARALLEL 	DC	PARALLEL_SPLIT
CLOCK_LINE	DC	CLOCK_LINE_SPLIT
SERIAL_READ	DC	SERIAL_READ_SPLIT_MED
SERIAL_SKIP	DC	SERIAL_SKIP_SPLIT
MV_ADDR		DC	PARALLEL_SPLIT
EXPOSE_PARALLELS DC	EXPOSE_SPLIT
SERIAL_DITHER	DC	SERIAL_SPLIT_DITHER_MED

; Subarray readout parameters
NP_SKIP	DC	0	; Number of rows to skip
NS_SKP1	DC	0	; Number of serials to clear before read
NS_SKP2	DC	0	; Number of serials to clear after read
NR_BIAS	DC	0	; Number of bias pixels to read
NS_READ	DC	0	; Number of columns in subimage read
NP_READ	DC	0	; Number of rows in subimage read
N_ROWS	DC	0	; Number of rows to actually read	
N_COLS	DC	0	; Number of columns to actually read
N_BIAS	DC	0	; Number of columns to read in the bias region

; Subimage readout parameters. Ten subimage boxes maximum.
NBOXES	DC	0		; Number of boxes to read
READ_TABLE 
	DC	0,0,0		; #1 = Number of rows to clear 
	DC	0,0,0		; #2 = Number of columns to skip before 
	DC	0,0,0		;   subimage read 
	DC	0,0,0		; #3 = Number of columns to skip after 
	DC	0,0,0		;   subimage clear
	DC	0,0,0
	DC	0,0,0
	DC	0,0,0
	DC	0,0,0
	DC	0,0,0

; Include the waveform table for the designated type of CCD
	INCLUDE "WAVEFORM_FILE" ; Readout and clocking waveform file

END_APPLICATON_Y_MEMORY	EQU	@LCV(L)

; End of program
	END

