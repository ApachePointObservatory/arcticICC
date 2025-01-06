Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  tim.asm  Page 1



1                                 COMMENT *
2      
3                          This file supports the ARC-22, ARC-32 and ARC-47 for operating an STA4150A 4k CCD.
4                                  It supports split serial and parallel readouts, readout from one or four
5                                  corners, 2x2 binning, multiple subarray, and selection of 100 kHz, 400 kHz
6                                  or 1000 kHz pixel rates.
7      
8                                  *
9                                    PAGE    132                               ; Printronix page width - 132 columns
10     
11                         ; Include the boot file so addressing is easy
12                                   INCLUDE "timboot.asm"
13                         ;  This file is used to generate boot DSP code for the Gen III 250 MHz fiber
14                         ;       optic timing board = ARC22 using a DSP56303 as its main processor.
15     
16                         ; Various addressing control registers
17        FFFFFB           BCR       EQU     $FFFFFB                           ; Bus Control Register
18        FFFFF9           AAR0      EQU     $FFFFF9                           ; Address Attribute Register, channel 0
19        FFFFF8           AAR1      EQU     $FFFFF8                           ; Address Attribute Register, channel 1
20        FFFFF7           AAR2      EQU     $FFFFF7                           ; Address Attribute Register, channel 2
21        FFFFF6           AAR3      EQU     $FFFFF6                           ; Address Attribute Register, channel 3
22        FFFFFD           PCTL      EQU     $FFFFFD                           ; PLL control register
23        FFFFFE           IPRP      EQU     $FFFFFE                           ; Interrupt Priority register - Peripheral
24        FFFFFF           IPRC      EQU     $FFFFFF                           ; Interrupt Priority register - Core
25     
26                         ; Port E is the Synchronous Communications Interface (SCI) port
27        FFFF9F           PCRE      EQU     $FFFF9F                           ; Port Control Register
28        FFFF9E           PRRE      EQU     $FFFF9E                           ; Port Direction Register
29        FFFF9D           PDRE      EQU     $FFFF9D                           ; Port Data Register
30        FFFF9C           SCR       EQU     $FFFF9C                           ; SCI Control Register
31        FFFF9B           SCCR      EQU     $FFFF9B                           ; SCI Clock Control Register
32     
33        FFFF9A           SRXH      EQU     $FFFF9A                           ; SCI Receive Data Register, High byte
34        FFFF99           SRXM      EQU     $FFFF99                           ; SCI Receive Data Register, Middle byte
35        FFFF98           SRXL      EQU     $FFFF98                           ; SCI Receive Data Register, Low byte
36     
37        FFFF97           STXH      EQU     $FFFF97                           ; SCI Transmit Data register, High byte
38        FFFF96           STXM      EQU     $FFFF96                           ; SCI Transmit Data register, Middle byte
39        FFFF95           STXL      EQU     $FFFF95                           ; SCI Transmit Data register, Low byte
40     
41        FFFF94           STXA      EQU     $FFFF94                           ; SCI Transmit Address Register
42        FFFF93           SSR       EQU     $FFFF93                           ; SCI Status Register
43     
44        000009           SCITE     EQU     9                                 ; X:SCR bit set to enable the SCI transmitter
45        000008           SCIRE     EQU     8                                 ; X:SCR bit set to enable the SCI receiver
46        000000           TRNE      EQU     0                                 ; This is set in X:SSR when the transmitter
47                                                                             ;  shift and data registers are both empty
48        000001           TDRE      EQU     1                                 ; This is set in X:SSR when the transmitter
49                                                                             ;  data register is empty
50        000002           RDRF      EQU     2                                 ; X:SSR bit set when receiver register is full
51        00000F           SELSCI    EQU     15                                ; 1 for SCI to backplane, 0 to front connector
52     
53     
54                         ; ESSI Flags
55        000006           TDE       EQU     6                                 ; Set when transmitter data register is empty
56        000007           RDF       EQU     7                                 ; Set when receiver is full of data
57        000010           TE        EQU     16                                ; Transmitter enable
58     
59                         ; Phase Locked Loop initialization
60        050003           PLL_INIT  EQU     $050003                           ; PLL = 25 MHz x 2 = 100 MHz
61     
62                         ; Port B general purpose I/O
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 2



63        FFFFC4           HPCR      EQU     $FFFFC4                           ; Control register (bits 1-6 cleared for GPIO)
64        FFFFC9           HDR       EQU     $FFFFC9                           ; Data register
65        FFFFC8           HDDR      EQU     $FFFFC8                           ; Data Direction Register bits (=1 for output)
66     
67                         ; Port C is Enhanced Synchronous Serial Port 0 = ESSI0
68        FFFFBF           PCRC      EQU     $FFFFBF                           ; Port C Control Register
69        FFFFBE           PRRC      EQU     $FFFFBE                           ; Port C Data direction Register
70        FFFFBD           PDRC      EQU     $FFFFBD                           ; Port C GPIO Data Register
71        FFFFBC           TX00      EQU     $FFFFBC                           ; Transmit Data Register #0
72        FFFFB8           RX0       EQU     $FFFFB8                           ; Receive data register
73        FFFFB7           SSISR0    EQU     $FFFFB7                           ; Status Register
74        FFFFB6           CRB0      EQU     $FFFFB6                           ; Control Register B
75        FFFFB5           CRA0      EQU     $FFFFB5                           ; Control Register A
76     
77                         ; Port D is Enhanced Synchronous Serial Port 1 = ESSI1
78        FFFFAF           PCRD      EQU     $FFFFAF                           ; Port D Control Register
79        FFFFAE           PRRD      EQU     $FFFFAE                           ; Port D Data direction Register
80        FFFFAD           PDRD      EQU     $FFFFAD                           ; Port D GPIO Data Register
81        FFFFAC           TX10      EQU     $FFFFAC                           ; Transmit Data Register 0
82        FFFFA7           SSISR1    EQU     $FFFFA7                           ; Status Register
83        FFFFA6           CRB1      EQU     $FFFFA6                           ; Control Register B
84        FFFFA5           CRA1      EQU     $FFFFA5                           ; Control Register A
85     
86                         ; Timer module addresses
87        FFFF8F           TCSR0     EQU     $FFFF8F                           ; Timer control and status register
88        FFFF8E           TLR0      EQU     $FFFF8E                           ; Timer load register = 0
89        FFFF8D           TCPR0     EQU     $FFFF8D                           ; Timer compare register = exposure time
90        FFFF8C           TCR0      EQU     $FFFF8C                           ; Timer count register = elapsed time
91        FFFF83           TPLR      EQU     $FFFF83                           ; Timer prescaler load register => milliseconds
92        FFFF82           TPCR      EQU     $FFFF82                           ; Timer prescaler count register
93        000000           TIM_BIT   EQU     0                                 ; Set to enable the timer
94        000009           TRM       EQU     9                                 ; Set to enable the timer preloading
95        000015           TCF       EQU     21                                ; Set when timer counter = compare register
96     
97                         ; Board specific addresses and constants
98        FFFFF1           RDFO      EQU     $FFFFF1                           ; Read incoming fiber optic data byte
99        FFFFF2           WRFO      EQU     $FFFFF2                           ; Write fiber optic data replies
100       FFFFF3           WRSS      EQU     $FFFFF3                           ; Write switch state
101       FFFFF5           WRLATCH   EQU     $FFFFF5                           ; Write to a latch
102       010000           RDAD      EQU     $010000                           ; Read A/D values into the DSP
103       000009           EF        EQU     9                                 ; Serial receiver empty flag
104    
105                        ; DSP port A bit equates
106       000000           PWROK     EQU     0                                 ; Power control board says power is OK
107       000001           LED1      EQU     1                                 ; Control one of two LEDs
108       000002           LVEN      EQU     2                                 ; Low voltage power enable
109       000003           HVEN      EQU     3                                 ; High voltage power enable
110       00000E           SSFHF     EQU     14                                ; Switch state FIFO half full flag
111       00000A           EXT_IN0   EQU     10                                ; External digital I/O to the timing board
112       00000B           EXT_IN1   EQU     11
113       00000C           EXT_OUT0  EQU     12
114       00000D           EXT_OUT1  EQU     13
115    
116                        ; Port D equate
117       000001           SSFEF     EQU     1                                 ; Switch state FIFO empty flag
118    
119                        ; Other equates
120       000002           WRENA     EQU     2                                 ; Enable writing to the EEPROM
121    
122                        ; Latch U25 bit equates
123       000000           CDAC      EQU     0                                 ; Clear the analog board DACs
124       000002           ENCK      EQU     2                                 ; Enable the clock outputs
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 3



125       000004           SHUTTER   EQU     4                                 ; Control the shutter
126       000005           TIM_U_RST EQU     5                                 ; Reset the utility board
127    
128                        ; Software status bits, defined at X:<STATUS = X:0
129       000000           ST_RCV    EQU     0                                 ; Set to indicate word is from SCI = utility board
130       000002           IDLMODE   EQU     2                                 ; Set if need to idle after readout
131       000003           ST_SHUT   EQU     3                                 ; Set to indicate shutter is closed, clear for open
132       000004           ST_RDC    EQU     4                                 ; Set if executing 'RDC' command - reading out
133       000005           SPLIT_S   EQU     5                                 ; Set if split serial
134       000006           SPLIT_P   EQU     6                                 ; Set if split parallel
135       000007           MPP       EQU     7                                 ; Set if parallels are in MPP mode
136       000008           NOT_CLR   EQU     8                                 ; Set if not to clear CCD before exposure
137       00000A           TST_IMG   EQU     10                                ; Set if controller is to generate a test image
138       00000B           SHUT      EQU     11                                ; Set if opening shutter at beginning of exposure
139       00000C           ST_DITH   EQU     12                                ; Set if to dither during exposure
140       00000D           ST_SYNC   EQU     13                                ; Set if starting exposure on SYNC = high signal
141       00000E           ST_CNRD   EQU     14                                ; Set if in continous readout mode
142       00000F           ST_DIRTY  EQU     15                                ; Set if waveform tables need to be updated
143       000010           ST_SA     EQU     16                                ; Set if in subarray readout mode
144    
145                        ; Address for the table containing the incoming SCI words
146       000400           SCI_TABLE EQU     $400
147    
148    
149                        ; Specify controller configuration bits of the X:STATUS word
150                        ;   to describe the software capabilities of this application file
151                        ; The bit is set (=1) if the capability is supported by the controller
152    
153    
154                                COMMENT *
155    
156                        BIT #'s         FUNCTION
157                        2,1,0           Video Processor
158                                                000     ARC41, CCD Rev. 3
159                                                001     CCD Gen I
160                                                010     ARC42, dual readout CCD
161                                                011     ARC44, 4-readout IR coadder
162                                                100     ARC45. dual readout CCD
163                                                101     ARC46 = 8-channel IR
164                                                110     ARC48 = 8 channel CCD
165                                                111     ARC47 = 4-channel CCD
166    
167                        4,3             Timing Board
168                                                00      ARC20, Rev. 4, Gen II
169                                                01      Gen I
170                                                10      ARC22, Gen III, 250 MHz
171    
172                        6,5             Utility Board
173                                                00      No utility board
174                                                01      ARC50
175    
176                        7               Shutter
177                                                0       No shutter support
178                                                1       Yes shutter support
179    
180                        9,8             Temperature readout
181                                                00      No temperature readout
182                                                01      Polynomial Diode calibration
183                                                10      Linear temperature sensor calibration
184    
185                        10              Subarray readout
186                                                0       Not supported
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 4



187                                                1       Yes supported
188    
189                        11              Binning
190                                                0       Not supported
191                                                1       Yes supported
192    
193                        12              Split-Serial readout
194                                                0       Not supported
195                                                1       Yes supported
196    
197                        13              Split-Parallel readout
198                                                0       Not supported
199                                                1       Yes supported
200    
201                        14              MPP = Inverted parallel clocks
202                                                0       Not supported
203                                                1       Yes supported
204    
205                        16,15           Clock Driver Board
206                                                00      ARC30 or ARC31
207                                                01      ARC32, CCD and IR
208                                                11      No clock driver board (Gen I)
209    
210                        19,18,17        Special implementations
211                                                000     Somewhere else
212                                                001     Mount Laguna Observatory
213                                                010     NGST Aladdin
214                                                xxx     Other
215                        20              Continuous readout
216                                                0       Not supported
217                                                1       Supported
218                        21              Selectable readout speed
219                                                0       Not supported
220                                                1       Supported
221                                        *
222    
223                        CCDVIDREV3B
224       000000                     EQU     $000000                           ; CCD Video Processor Rev. 3
225       000000           ARC41     EQU     $000000
226       000001           VIDGENI   EQU     $000001                           ; CCD Video Processor Gen I
227       000002           IRREV4    EQU     $000002                           ; IR Video Processor Rev. 4
228       000002           ARC42     EQU     $000002
229       000003           COADDER   EQU     $000003                           ; IR Coadder
230       000003           ARC44     EQU     $000003
231       000004           CCDVIDREV5 EQU    $000004                           ; Differential input CCD video Rev. 5
232       000004           ARC45     EQU     $000004
233       000005           ARC46     EQU     $000005                           ; 8-channel IR video board
234       000006           ARC48     EQU     $000006                           ; 8-channel CCD video board
235       000007           ARC47     EQU     $000007                           ; 4-channel CCD video board
236       000000           TIMREV4   EQU     $000000                           ; Timing Revision 4 = 50 MHz
237       000000           ARC20     EQU     $000000
238       000008           TIMGENI   EQU     $000008                           ; Timing Gen I = 40 MHz
239       000010           TIMREV5   EQU     $000010                           ; Timing Revision 5 = 250 MHz
240       000010           ARC22     EQU     $000010
241       008000           ARC32     EQU     $008000                           ; CCD & IR clock driver board
242       000020           UTILREV3  EQU     $000020                           ; Utility Rev. 3 supported
243       000020           ARC50     EQU     $000020
244       000080           SHUTTER_CC EQU    $000080                           ; Shutter supported
245       000100           TEMP_POLY EQU     $000100                           ; Polynomial calibration
246                        TEMP_LINEAR
247       000200                     EQU     $000200                           ; Linear calibration
248       000400           SUBARRAY  EQU     $000400                           ; Subarray readout supported
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 5



249       000800           BINNING   EQU     $000800                           ; Binning supported
250                        SPLIT_SERIAL
251       001000                     EQU     $001000                           ; Split serial supported
252                        SPLIT_PARALLEL
253       002000                     EQU     $002000                           ; Split parallel supported
254       004000           MPP_CC    EQU     $004000                           ; Inverted clocks supported
255       018000           CLKDRVGENI EQU    $018000                           ; No clock driver board - Gen I
256       020000           MLO       EQU     $020000                           ; Set if Mount Laguna Observatory
257       040000           NGST      EQU     $040000                           ; NGST Aladdin implementation
258       100000           CONT_RD   EQU     $100000                           ; Continuous readout implemented
259                        READOUT_SPEEDS
260       200000                     EQU     $200000                           ; Selectable readout speeds
261    
262                        ; Special address for two words for the DSP to bootstrap code from the EEPROM
263                                  IF      @SCP("HOST","ROM")
270                                  ENDIF
271    
272                                  IF      @SCP("HOST","HOST")
273       P:000000 P:000000                   ORG     P:0,P:0
274       P:000000 P:000000 0C0190            JMP     <INIT
275       P:000001 P:000001 000000            NOP
276                                           ENDIF
277    
278                                 ;  This ISR receives serial words a byte at a time over the asynchronous
279                                 ;    serial link (SCI) and squashes them into a single 24-bit word
280       P:000002 P:000002 602400  SCI_RCV   MOVE              R0,X:<SAVE_R0           ; Save R0
281       P:000003 P:000003 052139            MOVEC             SR,X:<SAVE_SR           ; Save Status Register
282       P:000004 P:000004 60A700            MOVE              X:<SCI_R0,R0            ; Restore R0 = pointer to SCI receive regist
er
283       P:000005 P:000005 542300            MOVE              A1,X:<SAVE_A1           ; Save A1
284       P:000006 P:000006 452200            MOVE              X1,X:<SAVE_X1           ; Save X1
285       P:000007 P:000007 54A600            MOVE              X:<SCI_A1,A1            ; Get SRX value of accumulator contents
286       P:000008 P:000008 45E000            MOVE              X:(R0),X1               ; Get the SCI byte
287       P:000009 P:000009 0AD041            BCLR    #1,R0                             ; Test for the address being $FFF6 = last by
te
288       P:00000A P:00000A 000000            NOP
289       P:00000B P:00000B 000000            NOP
290       P:00000C P:00000C 000000            NOP
291       P:00000D P:00000D 205862            OR      X1,A      (R0)+                   ; Add the byte into the 24-bit word
292       P:00000E P:00000E 0E0013            JCC     <MID_BYT                          ; Not the last byte => only restore register
s
293       P:00000F P:00000F 545C00  END_BYT   MOVE              A1,X:(R4)+              ; Put the 24-bit word into the SCI buffer
294       P:000010 P:000010 60F400            MOVE              #SRXL,R0                ; Re-establish first address of SCI interfac
e
                            FFFF98
295       P:000012 P:000012 2C0000            MOVE              #0,A1                   ; For zeroing out SCI_A1
296       P:000013 P:000013 602700  MID_BYT   MOVE              R0,X:<SCI_R0            ; Save the SCI receiver address
297       P:000014 P:000014 542600            MOVE              A1,X:<SCI_A1            ; Save A1 for next interrupt
298       P:000015 P:000015 05A139            MOVEC             X:<SAVE_SR,SR           ; Restore Status Register
299       P:000016 P:000016 54A300            MOVE              X:<SAVE_A1,A1           ; Restore A1
300       P:000017 P:000017 45A200            MOVE              X:<SAVE_X1,X1           ; Restore X1
301       P:000018 P:000018 60A400            MOVE              X:<SAVE_R0,R0           ; Restore R0
302       P:000019 P:000019 000004            RTI                                       ; Return from interrupt service
303    
304                                 ; Clear error condition and interrupt on SCI receiver
305       P:00001A P:00001A 077013  CLR_ERR   MOVEP             X:SSR,X:RCV_ERR         ; Read SCI status register
                            000025
306       P:00001C P:00001C 077018            MOVEP             X:SRXL,X:RCV_ERR        ; This clears any error
                            000025
307       P:00001E P:00001E 000004            RTI
308    
309       P:00001F P:00001F                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 6



310       P:000030 P:000030                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
311       P:000040 P:000040                   DC      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
312    
313                                 ; Tune the table so the following instruction is at P:$50 exactly.
314       P:000050 P:000050 0D0002            JSR     SCI_RCV                           ; SCI receive data interrupt
315       P:000051 P:000051 000000            NOP
316       P:000052 P:000052 0D001A            JSR     CLR_ERR                           ; SCI receive error interrupt
317       P:000053 P:000053 000000            NOP
318    
319                                 ; *******************  Command Processing  ******************
320    
321                                 ; Read the header and check it for self-consistency
322       P:000054 P:000054 609F00  START     MOVE              X:<IDL_ADR,R0
323       P:000055 P:000055 018FA0            JSET    #TIM_BIT,X:TCSR0,EXPOSING         ; If exposing go check the timer
                            00037B
324       P:000057 P:000057 0A00A4            JSET    #ST_RDC,X:<STATUS,CONTINUE_READING
                            00024A
325       P:000059 P:000059 0AE080            JMP     (R0)
326    
327       P:00005A P:00005A 330700  TST_RCV   MOVE              #<COM_BUF,R3
328       P:00005B P:00005B 0D00A5            JSR     <GET_RCV
329       P:00005C P:00005C 0E005B            JCC     *-1
330    
331                                 ; Check the header and read all the remaining words in the command
332       P:00005D P:00005D 0C00FF  PRC_RCV   JMP     <CHK_HDR                          ; Update HEADER and NWORDS
333       P:00005E P:00005E 578600  PR_RCV    MOVE              X:<NWORDS,B             ; Read this many words total in the command
334       P:00005F P:00005F 000000            NOP
335       P:000060 P:000060 01418C            SUB     #1,B                              ; We've already read the header
336       P:000061 P:000061 000000            NOP
337       P:000062 P:000062 06CF00            DO      B,RD_COM
                            00006A
338       P:000064 P:000064 205B00            MOVE              (R3)+                   ; Increment past what's been read already
339       P:000065 P:000065 0B0080  GET_WRD   JSCLR   #ST_RCV,X:STATUS,CHK_FO
                            0000A9
340       P:000067 P:000067 0B00A0            JSSET   #ST_RCV,X:STATUS,CHK_SCI
                            0000D5
341       P:000069 P:000069 0E0065            JCC     <GET_WRD
342       P:00006A P:00006A 000000            NOP
343       P:00006B P:00006B 330700  RD_COM    MOVE              #<COM_BUF,R3            ; Restore R3 = beginning of the command
344    
345                                 ; Is this command for the timing board?
346       P:00006C P:00006C 448500            MOVE              X:<HEADER,X0
347       P:00006D P:00006D 579B00            MOVE              X:<DMASK,B
348       P:00006E P:00006E 459A4E            AND     X0,B      X:<TIM_DRB,X1           ; Extract destination byte
349       P:00006F P:00006F 20006D            CMP     X1,B                              ; Does header = timing board number?
350       P:000070 P:000070 0EA080            JEQ     <COMMAND                          ; Yes, process it here
351       P:000071 P:000071 0E909D            JLT     <FO_XMT                           ; Send it to fiber optic transmitter
352    
353                                 ; Transmit the command to the utility board over the SCI port
354       P:000072 P:000072 060600            DO      X:<NWORDS,DON_XMT                 ; Transmit NWORDS
                            00007E
355       P:000074 P:000074 60F400            MOVE              #STXL,R0                ; SCI first byte address
                            FFFF95
356       P:000076 P:000076 44DB00            MOVE              X:(R3)+,X0              ; Get the 24-bit word to transmit
357       P:000077 P:000077 060380            DO      #3,SCI_SPT
                            00007D
358       P:000079 P:000079 019381            JCLR    #TDRE,X:SSR,*                     ; Continue ONLY if SCI XMT is empty
                            000079
359       P:00007B P:00007B 445800            MOVE              X0,X:(R0)+              ; Write to SCI, byte pointer + 1
360       P:00007C P:00007C 000000            NOP                                       ; Delay for the status flag to be set
361       P:00007D P:00007D 000000            NOP
362                                 SCI_SPT
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 7



363       P:00007E P:00007E 000000            NOP
364                                 DON_XMT
365       P:00007F P:00007F 0C0054            JMP     <START
366    
367                                 ; Process the receiver entry - is it in the command table ?
368       P:000080 P:000080 0203DF  COMMAND   MOVE              X:(R3+1),B              ; Get the command
369       P:000081 P:000081 205B00            MOVE              (R3)+
370       P:000082 P:000082 205B00            MOVE              (R3)+                   ; Point R3 to the first argument
371       P:000083 P:000083 302800            MOVE              #<COM_TBL,R0            ; Get the command table starting address
372       P:000084 P:000084 062680            DO      #NUM_COM,END_COM                  ; Loop over the command table
                            00008B
373       P:000086 P:000086 47D800            MOVE              X:(R0)+,Y1              ; Get the command table entry
374       P:000087 P:000087 62E07D            CMP     Y1,B      X:(R0),R2               ; Does receiver = table entries address?
375       P:000088 P:000088 0E208B            JNE     <NOT_COM                          ; No, keep looping
376       P:000089 P:000089 00008C            ENDDO                                     ; Restore the DO loop system registers
377       P:00008A P:00008A 0AE280            JMP     (R2)                              ; Jump execution to the command
378       P:00008B P:00008B 205800  NOT_COM   MOVE              (R0)+                   ; Increment the register past the table addr
ess
379                                 END_COM
380       P:00008C P:00008C 0C008D            JMP     <ERROR                            ; The command is not in the table
381    
382                                 ; It's not in the command table - send an error message
383       P:00008D P:00008D 479D00  ERROR     MOVE              X:<ERR,Y1               ; Send the message - there was an error
384       P:00008E P:00008E 0C0090            JMP     <FINISH1                          ; This protects against unknown commands
385    
386                                 ; Send a reply packet - header and reply
387       P:00008F P:00008F 479800  FINISH    MOVE              X:<DONE,Y1              ; Send 'DON' as the reply
388       P:000090 P:000090 578500  FINISH1   MOVE              X:<HEADER,B             ; Get header of incoming command
389       P:000091 P:000091 469C00            MOVE              X:<SMASK,Y0             ; This was the source byte, and is to
390       P:000092 P:000092 330700            MOVE              #<COM_BUF,R3            ;     become the destination byte
391       P:000093 P:000093 46935E            AND     Y0,B      X:<TWO,Y0
392       P:000094 P:000094 0C1ED1            LSR     #8,B                              ; Shift right eight bytes, add it to the
393       P:000095 P:000095 460600            MOVE              Y0,X:<NWORDS            ;     header, and put 2 as the number
394       P:000096 P:000096 469958            ADD     Y0,B      X:<SBRD,Y0              ;     of words in the string
395       P:000097 P:000097 200058            ADD     Y0,B                              ; Add source board's header, set Y1 for abov
e
396       P:000098 P:000098 000000            NOP
397       P:000099 P:000099 575B00            MOVE              B,X:(R3)+               ; Put the new header on the transmitter stac
k
398       P:00009A P:00009A 475B00            MOVE              Y1,X:(R3)+              ; Put the argument on the transmitter stack
399       P:00009B P:00009B 570500            MOVE              B,X:<HEADER
400       P:00009C P:00009C 0C006B            JMP     <RD_COM                           ; Decide where to send the reply, and do it
401    
402                                 ; Transmit words to the host computer over the fiber optics link
403       P:00009D P:00009D 63F400  FO_XMT    MOVE              #COM_BUF,R3
                            000007
404       P:00009F P:00009F 060600            DO      X:<NWORDS,DON_FFO                 ; Transmit all the words in the command
                            0000A3
405       P:0000A1 P:0000A1 57DB00            MOVE              X:(R3)+,B
406       P:0000A2 P:0000A2 0D00EB            JSR     <XMT_WRD
407       P:0000A3 P:0000A3 000000            NOP
408       P:0000A4 P:0000A4 0C0054  DON_FFO   JMP     <START
409    
410                                 ; Check for commands from the fiber optic FIFO and the utility board (SCI)
411       P:0000A5 P:0000A5 0D00A9  GET_RCV   JSR     <CHK_FO                           ; Check for fiber optic command from FIFO
412       P:0000A6 P:0000A6 0E80A8            JCS     <RCV_RTS                          ; If there's a command, check the header
413       P:0000A7 P:0000A7 0D00D5            JSR     <CHK_SCI                          ; Check for an SCI command
414       P:0000A8 P:0000A8 00000C  RCV_RTS   RTS
415    
416                                 ; Because of FIFO metastability require that EF be stable for two tests
417       P:0000A9 P:0000A9 0A8989  CHK_FO    JCLR    #EF,X:HDR,TST2                    ; EF = Low,  Low  => CLR SR, return
                            0000AC
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 8



418       P:0000AB P:0000AB 0C00AF            JMP     <TST3                             ;      High, Low  => try again
419       P:0000AC P:0000AC 0A8989  TST2      JCLR    #EF,X:HDR,CLR_CC                  ;      Low,  High => try again
                            0000D1
420       P:0000AE P:0000AE 0C00A9            JMP     <CHK_FO                           ;      High, High => read FIFO
421       P:0000AF P:0000AF 0A8989  TST3      JCLR    #EF,X:HDR,CHK_FO
                            0000A9
422    
423       P:0000B1 P:0000B1 08F4BB            MOVEP             #$028FE2,X:BCR          ; Slow down RDFO access
                            028FE2
424       P:0000B3 P:0000B3 000000            NOP
425       P:0000B4 P:0000B4 000000            NOP
426       P:0000B5 P:0000B5 5FF000            MOVE                          Y:RDFO,B
                            FFFFF1
427       P:0000B7 P:0000B7 2B0000            MOVE              #0,B2
428       P:0000B8 P:0000B8 0140CE            AND     #$FF,B
                            0000FF
429       P:0000BA P:0000BA 0140CD            CMP     #>$AC,B                           ; It must be $AC to be a valid word
                            0000AC
430       P:0000BC P:0000BC 0E20D1            JNE     <CLR_CC
431       P:0000BD P:0000BD 4EF000            MOVE                          Y:RDFO,Y0   ; Read the MS byte
                            FFFFF1
432       P:0000BF P:0000BF 0C1951            INSERT  #$008010,Y0,B
                            008010
433       P:0000C1 P:0000C1 4EF000            MOVE                          Y:RDFO,Y0   ; Read the middle byte
                            FFFFF1
434       P:0000C3 P:0000C3 0C1951            INSERT  #$008008,Y0,B
                            008008
435       P:0000C5 P:0000C5 4EF000            MOVE                          Y:RDFO,Y0   ; Read the LS byte
                            FFFFF1
436       P:0000C7 P:0000C7 0C1951            INSERT  #$008000,Y0,B
                            008000
437       P:0000C9 P:0000C9 000000            NOP
438       P:0000CA P:0000CA 516300            MOVE              B0,X:(R3)               ; Put the word into COM_BUF
439       P:0000CB P:0000CB 0A0000            BCLR    #ST_RCV,X:<STATUS                 ; Its a command from the host computer
440       P:0000CC P:0000CC 000000  SET_CC    NOP
441       P:0000CD P:0000CD 0AF960            BSET    #0,SR                             ; Valid word => SR carry bit = 1
442       P:0000CE P:0000CE 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
443       P:0000D0 P:0000D0 00000C            RTS
444       P:0000D1 P:0000D1 0AF940  CLR_CC    BCLR    #0,SR                             ; Not valid word => SR carry bit = 0
445       P:0000D2 P:0000D2 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
446       P:0000D4 P:0000D4 00000C            RTS
447    
448                                 ; Test the SCI (= synchronous communications interface) for new words
449       P:0000D5 P:0000D5 44F000  CHK_SCI   MOVE              X:(SCI_TABLE+33),X0
                            000421
450       P:0000D7 P:0000D7 228E00            MOVE              R4,A
451       P:0000D8 P:0000D8 209000            MOVE              X0,R0
452       P:0000D9 P:0000D9 200045            CMP     X0,A
453       P:0000DA P:0000DA 0EA0D1            JEQ     <CLR_CC                           ; There is no new SCI word
454       P:0000DB P:0000DB 44D800            MOVE              X:(R0)+,X0
455       P:0000DC P:0000DC 446300            MOVE              X0,X:(R3)
456       P:0000DD P:0000DD 220E00            MOVE              R0,A
457       P:0000DE P:0000DE 0140C5            CMP     #(SCI_TABLE+32),A                 ; Wrap it around the circular
                            000420
458       P:0000E0 P:0000E0 0EA0E4            JEQ     <INIT_PROCESSED_SCI               ;   buffer boundary
459       P:0000E1 P:0000E1 547000            MOVE              A1,X:(SCI_TABLE+33)
                            000421
460       P:0000E3 P:0000E3 0C00E9            JMP     <SCI_END
461                                 INIT_PROCESSED_SCI
462       P:0000E4 P:0000E4 56F400            MOVE              #SCI_TABLE,A
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 9



                            000400
463       P:0000E6 P:0000E6 000000            NOP
464       P:0000E7 P:0000E7 567000            MOVE              A,X:(SCI_TABLE+33)
                            000421
465       P:0000E9 P:0000E9 0A0020  SCI_END   BSET    #ST_RCV,X:<STATUS                 ; Its a utility board (SCI) word
466       P:0000EA P:0000EA 0C00CC            JMP     <SET_CC
467    
468                                 ; Transmit the word in B1 to the host computer over the fiber optic data link
469                                 XMT_WRD
470       P:0000EB P:0000EB 08F4BB            MOVEP             #$028FE2,X:BCR          ; Slow down RDFO access
                            028FE2
471       P:0000ED P:0000ED 60F400            MOVE              #FO_HDR+1,R0
                            000002
472       P:0000EF P:0000EF 060380            DO      #3,XMT_WRD1
                            0000F3
473       P:0000F1 P:0000F1 0C1D91            ASL     #8,B,B
474       P:0000F2 P:0000F2 000000            NOP
475       P:0000F3 P:0000F3 535800            MOVE              B2,X:(R0)+
476                                 XMT_WRD1
477       P:0000F4 P:0000F4 60F400            MOVE              #FO_HDR,R0
                            000001
478       P:0000F6 P:0000F6 61F400            MOVE              #WRFO,R1
                            FFFFF2
479       P:0000F8 P:0000F8 060480            DO      #4,XMT_WRD2
                            0000FB
480       P:0000FA P:0000FA 46D800            MOVE              X:(R0)+,Y0              ; Should be MOVEP  X:(R0)+,Y:WRFO
481       P:0000FB P:0000FB 4E6100            MOVE                          Y0,Y:(R1)
482                                 XMT_WRD2
483       P:0000FC P:0000FC 08F4BB            MOVEP             #$028FE1,X:BCR          ; Restore RDFO access
                            028FE1
484       P:0000FE P:0000FE 00000C            RTS
485    
486                                 ; Check the command or reply header in X:(R3) for self-consistency
487       P:0000FF P:0000FF 46E300  CHK_HDR   MOVE              X:(R3),Y0
488       P:000100 P:000100 579600            MOVE              X:<MASK1,B              ; Test for S.LE.3 and D.LE.3 and N.LE.7
489       P:000101 P:000101 20005E            AND     Y0,B
490       P:000102 P:000102 0E208D            JNE     <ERROR                            ; Test failed
491       P:000103 P:000103 579700            MOVE              X:<MASK2,B              ; Test for either S.NE.0 or D.NE.0
492       P:000104 P:000104 20005E            AND     Y0,B
493       P:000105 P:000105 0EA08D            JEQ     <ERROR                            ; Test failed
494       P:000106 P:000106 579500            MOVE              X:<SEVEN,B
495       P:000107 P:000107 20005E            AND     Y0,B                              ; Extract NWORDS, must be > 0
496       P:000108 P:000108 0EA08D            JEQ     <ERROR
497       P:000109 P:000109 44E300            MOVE              X:(R3),X0
498       P:00010A P:00010A 440500            MOVE              X0,X:<HEADER            ; Its a correct header
499       P:00010B P:00010B 550600            MOVE              B1,X:<NWORDS            ; Number of words in the command
500       P:00010C P:00010C 0C005E            JMP     <PR_RCV
501    
502                                 ;  *****************  Boot Commands  *******************
503    
504                                 ; Test Data Link - simply return value received after 'TDL'
505       P:00010D P:00010D 47DB00  TDL       MOVE              X:(R3)+,Y1              ; Get the data value
506       P:00010E P:00010E 0C0090            JMP     <FINISH1                          ; Return from executing TDL command
507    
508                                 ; Read DSP or EEPROM memory ('RDM' address): read memory, reply with value
509       P:00010F P:00010F 47DB00  RDMEM     MOVE              X:(R3)+,Y1
510       P:000110 P:000110 20EF00            MOVE              Y1,B
511       P:000111 P:000111 0140CE            AND     #$0FFFFF,B                        ; Bits 23-20 need to be zeroed
                            0FFFFF
512       P:000113 P:000113 21B000            MOVE              B1,R0                   ; Need the address in an address register
513       P:000114 P:000114 20EF00            MOVE              Y1,B
514       P:000115 P:000115 000000            NOP
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 10



515       P:000116 P:000116 0ACF14            JCLR    #20,B,RDX                         ; Test address bit for Program memory
                            00011A
516       P:000118 P:000118 07E087            MOVE              P:(R0),Y1               ; Read from Program Memory
517       P:000119 P:000119 0C0090            JMP     <FINISH1                          ; Send out a header with the value
518       P:00011A P:00011A 0ACF15  RDX       JCLR    #21,B,RDY                         ; Test address bit for X: memory
                            00011E
519       P:00011C P:00011C 47E000            MOVE              X:(R0),Y1               ; Write to X data memory
520       P:00011D P:00011D 0C0090            JMP     <FINISH1                          ; Send out a header with the value
521       P:00011E P:00011E 0ACF16  RDY       JCLR    #22,B,RDR                         ; Test address bit for Y: memory
                            000122
522       P:000120 P:000120 4FE000            MOVE                          Y:(R0),Y1   ; Read from Y data memory
523       P:000121 P:000121 0C0090            JMP     <FINISH1                          ; Send out a header with the value
524       P:000122 P:000122 0ACF17  RDR       JCLR    #23,B,ERROR                       ; Test address bit for read from EEPROM memo
ry
                            00008D
525       P:000124 P:000124 479400            MOVE              X:<THREE,Y1             ; Convert to word address to a byte address
526       P:000125 P:000125 220600            MOVE              R0,Y0                   ; Get 16-bit address in a data register
527       P:000126 P:000126 2000B8            MPY     Y0,Y1,B                           ; Multiply
528       P:000127 P:000127 20002A            ASR     B                                 ; Eliminate zero fill of fractional multiply
529       P:000128 P:000128 213000            MOVE              B0,R0                   ; Need to address memory
530       P:000129 P:000129 0AD06F            BSET    #15,R0                            ; Set bit so its in EEPROM space
531       P:00012A P:00012A 0D0178            JSR     <RD_WORD                          ; Read word from EEPROM
532       P:00012B P:00012B 21A700            MOVE              B1,Y1                   ; FINISH1 transmits Y1 as its reply
533       P:00012C P:00012C 0C0090            JMP     <FINISH1
534    
535                                 ; Program WRMEM ('WRM' address datum): write to memory, reply 'DON'.
536       P:00012D P:00012D 47DB00  WRMEM     MOVE              X:(R3)+,Y1              ; Get the address to be written to
537       P:00012E P:00012E 20EF00            MOVE              Y1,B
538       P:00012F P:00012F 0140CE            AND     #$0FFFFF,B                        ; Bits 23-20 need to be zeroed
                            0FFFFF
539       P:000131 P:000131 21B000            MOVE              B1,R0                   ; Need the address in an address register
540       P:000132 P:000132 20EF00            MOVE              Y1,B
541       P:000133 P:000133 46DB00            MOVE              X:(R3)+,Y0              ; Get datum into Y0 so MOVE works easily
542       P:000134 P:000134 0ACF14            JCLR    #20,B,WRX                         ; Test address bit for Program memory
                            000138
543       P:000136 P:000136 076086            MOVE              Y0,P:(R0)               ; Write to Program memory
544       P:000137 P:000137 0C008F            JMP     <FINISH
545       P:000138 P:000138 0ACF15  WRX       JCLR    #21,B,WRY                         ; Test address bit for X: memory
                            00013C
546       P:00013A P:00013A 466000            MOVE              Y0,X:(R0)               ; Write to X: memory
547       P:00013B P:00013B 0C008F            JMP     <FINISH
548       P:00013C P:00013C 0ACF16  WRY       JCLR    #22,B,WRR                         ; Test address bit for Y: memory
                            000140
549       P:00013E P:00013E 4E6000            MOVE                          Y0,Y:(R0)   ; Write to Y: memory
550       P:00013F P:00013F 0C008F            JMP     <FINISH
551       P:000140 P:000140 0ACF17  WRR       JCLR    #23,B,ERROR                       ; Test address bit for write to EEPROM
                            00008D
552       P:000142 P:000142 013D02            BCLR    #WRENA,X:PDRC                     ; WR_ENA* = 0 to enable EEPROM writing
553       P:000143 P:000143 460E00            MOVE              Y0,X:<SV_A1             ; Save the datum to be written
554       P:000144 P:000144 479400            MOVE              X:<THREE,Y1             ; Convert word address to a byte address
555       P:000145 P:000145 220600            MOVE              R0,Y0                   ; Get 16-bit address in a data register
556       P:000146 P:000146 2000B8            MPY     Y1,Y0,B                           ; Multiply
557       P:000147 P:000147 20002A            ASR     B                                 ; Eliminate zero fill of fractional multiply
558       P:000148 P:000148 213000            MOVE              B0,R0                   ; Need to address memory
559       P:000149 P:000149 0AD06F            BSET    #15,R0                            ; Set bit so its in EEPROM space
560       P:00014A P:00014A 558E00            MOVE              X:<SV_A1,B1             ; Get the datum to be written
561       P:00014B P:00014B 060380            DO      #3,L1WRR                          ; Loop over three bytes of the word
                            000154
562       P:00014D P:00014D 07588D            MOVE              B1,P:(R0)+              ; Write each EEPROM byte
563       P:00014E P:00014E 0C1C91            ASR     #8,B,B
564       P:00014F P:00014F 469E00            MOVE              X:<C100K,Y0             ; Move right one byte, enter delay = 1 msec
565       P:000150 P:000150 06C600            DO      Y0,L2WRR                          ; Delay by 12 milliseconds for EEPROM write
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 11



                            000153
566       P:000152 P:000152 060CA0            REP     #12                               ; Assume 100 MHz DSP56303
567       P:000153 P:000153 000000            NOP
568                                 L2WRR
569       P:000154 P:000154 000000            NOP                                       ; DO loop nesting restriction
570                                 L1WRR
571       P:000155 P:000155 013D22            BSET    #WRENA,X:PDRC                     ; WR_ENA* = 1 to disable EEPROM writing
572       P:000156 P:000156 0C008F            JMP     <FINISH
573    
574                                 ; Load application code from P: memory into its proper locations
575       P:000157 P:000157 47DB00  LDAPPL    MOVE              X:(R3)+,Y1              ; Application number, not used yet
576       P:000158 P:000158 0D015A            JSR     <LOAD_APPLICATION
577       P:000159 P:000159 0C008F            JMP     <FINISH
578    
579                                 LOAD_APPLICATION
580       P:00015A P:00015A 60F400            MOVE              #$8000,R0               ; Starting EEPROM address
                            008000
581       P:00015C P:00015C 0D0178            JSR     <RD_WORD                          ; Number of words in boot code
582       P:00015D P:00015D 21A600            MOVE              B1,Y0
583       P:00015E P:00015E 479400            MOVE              X:<THREE,Y1
584       P:00015F P:00015F 2000B8            MPY     Y0,Y1,B
585       P:000160 P:000160 20002A            ASR     B
586       P:000161 P:000161 213000            MOVE              B0,R0                   ; EEPROM address of start of P: application
587       P:000162 P:000162 0AD06F            BSET    #15,R0                            ; To access EEPROM
588       P:000163 P:000163 0D0178            JSR     <RD_WORD                          ; Read number of words in application P:
589       P:000164 P:000164 61F400            MOVE              #(X_BOOT_START+1),R1    ; End of boot P: code that needs keeping
                            00022B
590       P:000166 P:000166 06CD00            DO      B1,RD_APPL_P
                            000169
591       P:000168 P:000168 0D0178            JSR     <RD_WORD
592       P:000169 P:000169 07598D            MOVE              B1,P:(R1)+
593                                 RD_APPL_P
594       P:00016A P:00016A 0D0178            JSR     <RD_WORD                          ; Read number of words in application X:
595       P:00016B P:00016B 61F400            MOVE              #END_COMMAND_TABLE,R1
                            000036
596       P:00016D P:00016D 06CD00            DO      B1,RD_APPL_X
                            000170
597       P:00016F P:00016F 0D0178            JSR     <RD_WORD
598       P:000170 P:000170 555900            MOVE              B1,X:(R1)+
599                                 RD_APPL_X
600       P:000171 P:000171 0D0178            JSR     <RD_WORD                          ; Read number of words in application Y:
601       P:000172 P:000172 310100            MOVE              #1,R1                   ; There is no Y: memory in the boot code
602       P:000173 P:000173 06CD00            DO      B1,RD_APPL_Y
                            000176
603       P:000175 P:000175 0D0178            JSR     <RD_WORD
604       P:000176 P:000176 5D5900            MOVE                          B1,Y:(R1)+
605                                 RD_APPL_Y
606       P:000177 P:000177 00000C            RTS
607    
608                                 ; Read one word from EEPROM location R0 into accumulator B1
609       P:000178 P:000178 060380  RD_WORD   DO      #3,L_RDBYTE
                            00017B
610       P:00017A P:00017A 07D88B            MOVE              P:(R0)+,B2
611       P:00017B P:00017B 0C1C91            ASR     #8,B,B
612                                 L_RDBYTE
613       P:00017C P:00017C 00000C            RTS
614    
615                                 ; Come to here on a 'STP' command so 'DON' can be sent
616                                 STOP_IDLE_CLOCKING
617       P:00017D P:00017D 305A00            MOVE              #<TST_RCV,R0            ; Execution address when idle => when not
618       P:00017E P:00017E 601F00            MOVE              R0,X:<IDL_ADR           ;   processing commands or reading out
619       P:00017F P:00017F 0A0002            BCLR    #IDLMODE,X:<STATUS                ; Don't idle after readout
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 12



620       P:000180 P:000180 0C008F            JMP     <FINISH
621    
622                                 ; Routines executed after the DSP boots and initializes
623       P:000181 P:000181 305A00  STARTUP   MOVE              #<TST_RCV,R0            ; Execution address when idle => when not
624       P:000182 P:000182 601F00            MOVE              R0,X:<IDL_ADR           ;   processing commands or reading out
625       P:000183 P:000183 44F400            MOVE              #50000,X0               ; Delay by 500 milliseconds
                            00C350
626       P:000185 P:000185 06C400            DO      X0,L_DELAY
                            000188
627       P:000187 P:000187 06E8A3            REP     #1000
628       P:000188 P:000188 000000            NOP
629                                 L_DELAY
630       P:000189 P:000189 57F400            MOVE              #$020002,B              ; Normal reply after booting is 'SYR'
                            020002
631       P:00018B P:00018B 0D00EB            JSR     <XMT_WRD
632       P:00018C P:00018C 57F400            MOVE              #'SYR',B
                            535952
633       P:00018E P:00018E 0D00EB            JSR     <XMT_WRD
634    
635       P:00018F P:00018F 0C0054            JMP     <START                            ; Start normal command processing
636    
637                                 ; *******************  DSP  INITIALIZATION  CODE  **********************
638                                 ; This code initializes the DSP right after booting, and is overwritten
639                                 ;   by application code
640       P:000190 P:000190 08F4BD  INIT      MOVEP             #PLL_INIT,X:PCTL        ; Initialize PLL to 100 MHz
                            050003
641       P:000192 P:000192 000000            NOP
642    
643                                 ; Set operation mode register OMR to normal expanded
644       P:000193 P:000193 0500BA            MOVEC             #$0000,OMR              ; Operating Mode Register = Normal Expanded
645       P:000194 P:000194 0500BB            MOVEC             #0,SP                   ; Reset the Stack Pointer SP
646    
647                                 ; Program the AA = address attribute pins
648       P:000195 P:000195 08F4B9            MOVEP             #$FFFC21,X:AAR0         ; Y = $FFF000 to $FFFFFF asserts commands
                            FFFC21
649       P:000197 P:000197 08F4B8            MOVEP             #$008909,X:AAR1         ; P = $008000 to $00FFFF accesses the EEPROM
                            008909
650       P:000199 P:000199 08F4B7            MOVEP             #$010C11,X:AAR2         ; X = $010000 to $010FFF reads A/D values
                            010C11
651       P:00019B P:00019B 08F4B6            MOVEP             #$080621,X:AAR3         ; Y = $080000 to $0BFFFF R/W from SRAM
                            080621
652    
653       P:00019D P:00019D 0A0F00            BCLR    #CDAC,X:<LATCH                    ; Enable clearing of DACs
654       P:00019E P:00019E 0A0F02            BCLR    #ENCK,X:<LATCH                    ; Disable clock and DAC output switches
655       P:00019F P:00019F 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Execute these two operations
                            00000F
656    
657                                 ; Program the DRAM memory access and addressing
658       P:0001A1 P:0001A1 08F4BB            MOVEP             #$028FE1,X:BCR          ; Bus Control Register
                            028FE1
659    
660                                 ; Program the Host port B for parallel I/O
661       P:0001A3 P:0001A3 08F484            MOVEP             #>1,X:HPCR              ; All pins enabled as GPIO
                            000001
662       P:0001A5 P:0001A5 08F489            MOVEP             #$810C,X:HDR
                            00810C
663       P:0001A7 P:0001A7 08F488            MOVEP             #$B10E,X:HDDR           ; Data Direction Register
                            00B10E
664                                                                                     ;  (1 for Output, 0 for Input)
665    
666                                 ; Port B conversion from software bits to schematic labels
667                                 ;       PB0 = PWROK             PB08 = PRSFIFO*
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 13



668                                 ;       PB1 = LED1              PB09 = EF*
669                                 ;       PB2 = LVEN              PB10 = EXT-IN0
670                                 ;       PB3 = HVEN              PB11 = EXT-IN1
671                                 ;       PB4 = STATUS0           PB12 = EXT-OUT0
672                                 ;       PB5 = STATUS1           PB13 = EXT-OUT1
673                                 ;       PB6 = STATUS2           PB14 = SSFHF*
674                                 ;       PB7 = STATUS3           PB15 = SELSCI
675    
676                                 ; Program the serial port ESSI0 = Port C for serial communication with
677                                 ;   the utility board
678       P:0001A9 P:0001A9 07F43F            MOVEP             #>0,X:PCRC              ; Software reset of ESSI0
                            000000
679       P:0001AB P:0001AB 07F435            MOVEP             #$180809,X:CRA0         ; Divide 100 MHz by 20 to get 5.0 MHz
                            180809
680                                                                                     ; DC[4:0] = 0 for non-network operation
681                                                                                     ; WL0-WL2 = 3 for 24-bit data words
682                                                                                     ; SSC1 = 0 for SC1 not used
683       P:0001AD P:0001AD 07F436            MOVEP             #$020020,X:CRB0         ; SCKD = 1 for internally generated clock
                            020020
684                                                                                     ; SCD2 = 0 so frame sync SC2 is an output
685                                                                                     ; SHFD = 0 for MSB shifted first
686                                                                                     ; FSL = 0, frame sync length not used
687                                                                                     ; CKP = 0 for rising clock edge transitions
688                                                                                     ; SYN = 0 for asynchronous
689                                                                                     ; TE0 = 1 to enable transmitter #0
690                                                                                     ; MOD = 0 for normal, non-networked mode
691                                                                                     ; TE0 = 0 to NOT enable transmitter #0 yet
692                                                                                     ; RE = 1 to enable receiver
693       P:0001AF P:0001AF 07F43F            MOVEP             #%111001,X:PCRC         ; Control Register (0 for GPIO, 1 for ESSI)
                            000039
694       P:0001B1 P:0001B1 07F43E            MOVEP             #%000110,X:PRRC         ; Data Direction Register (0 for In, 1 for O
ut)
                            000006
695       P:0001B3 P:0001B3 07F43D            MOVEP             #%000100,X:PDRC         ; Data Register - WR_ENA* = 1
                            000004
696    
697                                 ; Port C version = Analog boards
698                                 ;       MOVEP   #$000809,X:CRA0 ; Divide 100 MHz by 20 to get 5.0 MHz
699                                 ;       MOVEP   #$000030,X:CRB0 ; SCKD = 1 for internally generated clock
700                                 ;       MOVEP   #%100000,X:PCRC ; Control Register (0 for GPIO, 1 for ESSI)
701                                 ;       MOVEP   #%000100,X:PRRC ; Data Direction Register (0 for In, 1 for Out)
702                                 ;       MOVEP   #%000000,X:PDRC ; Data Register: 'not used' = 0 outputs
703    
704       P:0001B5 P:0001B5 07F43C            MOVEP             #0,X:TX00               ; Initialize the transmitter to zero
                            000000
705       P:0001B7 P:0001B7 000000            NOP
706       P:0001B8 P:0001B8 000000            NOP
707       P:0001B9 P:0001B9 013630            BSET    #TE,X:CRB0                        ; Enable the SSI transmitter
708    
709                                 ; Conversion from software bits to schematic labels for Port C
710                                 ;       PC0 = SC00 = UTL-T-SCK
711                                 ;       PC1 = SC01 = 2_XMT = SYNC on prototype
712                                 ;       PC2 = SC02 = WR_ENA*
713                                 ;       PC3 = SCK0 = TIM-U-SCK
714                                 ;       PC4 = SRD0 = UTL-T-STD
715                                 ;       PC5 = STD0 = TIM-U-STD
716    
717                                 ; Program the serial port ESSI1 = Port D for serial transmission to
718                                 ;   the analog boards and two parallel I/O input pins
719       P:0001BA P:0001BA 07F42F            MOVEP             #>0,X:PCRD              ; Software reset of ESSI0
                            000000
720       P:0001BC P:0001BC 07F425            MOVEP             #$000809,X:CRA1         ; Divide 100 MHz by 20 to get 5.0 MHz
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 14



                            000809
721                                                                                     ; DC[4:0] = 0
722                                                                                     ; WL[2:0] = ALC = 0 for 8-bit data words
723                                                                                     ; SSC1 = 0 for SC1 not used
724       P:0001BE P:0001BE 07F426            MOVEP             #$000030,X:CRB1         ; SCKD = 1 for internally generated clock
                            000030
725                                                                                     ; SCD2 = 1 so frame sync SC2 is an output
726                                                                                     ; SHFD = 0 for MSB shifted first
727                                                                                     ; CKP = 0 for rising clock edge transitions
728                                                                                     ; TE0 = 0 to NOT enable transmitter #0 yet
729                                                                                     ; MOD = 0 so its not networked mode
730       P:0001C0 P:0001C0 07F42F            MOVEP             #%100000,X:PCRD         ; Control Register (0 for GPIO, 1 for ESSI)
                            000020
731                                                                                     ; PD3 = SCK1, PD5 = STD1 for ESSI
732       P:0001C2 P:0001C2 07F42E            MOVEP             #%000100,X:PRRD         ; Data Direction Register (0 for In, 1 for O
ut)
                            000004
733       P:0001C4 P:0001C4 07F42D            MOVEP             #%000100,X:PDRD         ; Data Register: 'not used' = 0 outputs
                            000004
734       P:0001C6 P:0001C6 07F42C            MOVEP             #0,X:TX10               ; Initialize the transmitter to zero
                            000000
735       P:0001C8 P:0001C8 000000            NOP
736       P:0001C9 P:0001C9 000000            NOP
737       P:0001CA P:0001CA 012630            BSET    #TE,X:CRB1                        ; Enable the SSI transmitter
738    
739                                 ; Conversion from software bits to schematic labels for Port D
740                                 ; PD0 = SC10 = 2_XMT_? input
741                                 ; PD1 = SC11 = SSFEF* input
742                                 ; PD2 = SC12 = PWR_EN
743                                 ; PD3 = SCK1 = TIM-A-SCK
744                                 ; PD4 = SRD1 = PWRRST
745                                 ; PD5 = STD1 = TIM-A-STD
746    
747                                 ; Program the SCI port to communicate with the utility board
748       P:0001CB P:0001CB 07F41C            MOVEP             #$0B04,X:SCR            ; SCI programming: 11-bit asynchronous
                            000B04
749                                                                                     ;   protocol (1 start, 8 data, 1 even parity
,
750                                                                                     ;   1 stop); LSB before MSB; enable receiver
751                                                                                     ;   and its interrupts; transmitter interrup
ts
752                                                                                     ;   disabled.
753       P:0001CD P:0001CD 07F41B            MOVEP             #$0003,X:SCCR           ; SCI clock: utility board data rate =
                            000003
754                                                                                     ;   (390,625 kbits/sec); internal clock.
755       P:0001CF P:0001CF 07F41F            MOVEP             #%011,X:PCRE            ; Port Control Register = RXD, TXD enabled
                            000003
756       P:0001D1 P:0001D1 07F41E            MOVEP             #%000,X:PRRE            ; Port Direction Register (0 = Input)
                            000000
757    
758                                 ;       PE0 = RXD
759                                 ;       PE1 = TXD
760                                 ;       PE2 = SCLK
761    
762                                 ; Program one of the three timers as an exposure timer
763       P:0001D3 P:0001D3 07F403            MOVEP             #$C34F,X:TPLR           ; Prescaler to generate millisecond timer,
                            00C34F
764                                                                                     ;  counting from the system clock / 2 = 50 M
Hz
765       P:0001D5 P:0001D5 07F40F            MOVEP             #$208200,X:TCSR0        ; Clear timer complete bit and enable presca
ler
                            208200
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 15



766       P:0001D7 P:0001D7 07F40E            MOVEP             #0,X:TLR0               ; Timer load register
                            000000
767    
768                                 ; Enable interrupts for the SCI port only
769       P:0001D9 P:0001D9 08F4BF            MOVEP             #$000000,X:IPRC         ; No interrupts allowed
                            000000
770       P:0001DB P:0001DB 08F4BE            MOVEP             #>$80,X:IPRP            ; Enable SCI interrupt only, IPR = 1
                            000080
771       P:0001DD P:0001DD 00FCB8            ANDI    #$FC,MR                           ; Unmask all interrupt levels
772    
773                                 ; Initialize the fiber optic serial receiver circuitry
774       P:0001DE P:0001DE 061480            DO      #20,L_FO_INIT
                            0001E3
775       P:0001E0 P:0001E0 5FF000            MOVE                          Y:RDFO,B
                            FFFFF1
776       P:0001E2 P:0001E2 0605A0            REP     #5
777       P:0001E3 P:0001E3 000000            NOP
778                                 L_FO_INIT
779    
780                                 ; Pulse PRSFIFO* low to revive the CMDRST* instruction and reset the FIFO
781       P:0001E4 P:0001E4 44F400            MOVE              #1000000,X0             ; Delay by 10 milliseconds
                            0F4240
782       P:0001E6 P:0001E6 06C400            DO      X0,*+3
                            0001E8
783       P:0001E8 P:0001E8 000000            NOP
784       P:0001E9 P:0001E9 0A8908            BCLR    #8,X:HDR
785       P:0001EA P:0001EA 0614A0            REP     #20
786       P:0001EB P:0001EB 000000            NOP
787       P:0001EC P:0001EC 0A8928            BSET    #8,X:HDR
788    
789                                 ; Reset the utility board
790       P:0001ED P:0001ED 0A0F05            BCLR    #5,X:<LATCH
791       P:0001EE P:0001EE 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Clear reset utility board bit
                            00000F
792       P:0001F0 P:0001F0 06C8A0            REP     #200                              ; Delay by RESET* low time
793       P:0001F1 P:0001F1 000000            NOP
794       P:0001F2 P:0001F2 0A0F25            BSET    #5,X:<LATCH
795       P:0001F3 P:0001F3 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Clear reset utility board bit
                            00000F
796       P:0001F5 P:0001F5 56F400            MOVE              #200000,A               ; Delay 2 msec for utility boot
                            030D40
797       P:0001F7 P:0001F7 06CE00            DO      A,*+3
                            0001F9
798       P:0001F9 P:0001F9 000000            NOP
799    
800                                 ; Put all the analog switch inputs to low so they draw minimum current
801       P:0001FA P:0001FA 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
802       P:0001FB P:0001FB 56F400            MOVE              #$0C3000,A              ; Value of integrate speed and gain switches
                            0C3000
803       P:0001FD P:0001FD 20001B            CLR     B
804       P:0001FE P:0001FE 241000            MOVE              #$100000,X0             ; Increment over board numbers for DAC write
s
805       P:0001FF P:0001FF 45F400            MOVE              #$001000,X1             ; Increment over board numbers for WRSS writ
es
                            001000
806       P:000201 P:000201 060F80            DO      #15,L_ANALOG                      ; Fifteen video processor boards maximum
                            000209
807       P:000203 P:000203 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
808       P:000204 P:000204 200040            ADD     X0,A
809       P:000205 P:000205 5F7000            MOVE                          B,Y:WRSS    ; This is for the fast analog switches
                            FFFFF3
810       P:000207 P:000207 0620A3            REP     #800                              ; Delay for the serial data transmission
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 16



811       P:000208 P:000208 000000            NOP
812       P:000209 P:000209 200068            ADD     X1,B                              ; Increment the video and clock driver numbe
rs
813                                 L_ANALOG
814       P:00020A P:00020A 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
815       P:00020B P:00020B 0C0223            JMP     <SKIP
816    
817                                 ; Transmit contents of accumulator A1 over the synchronous serial transmitter
818                                 XMIT_A_WORD
819       P:00020C P:00020C 07F42C            MOVEP             #0,X:TX10               ; This helps, don't know why
                            000000
820       P:00020E P:00020E 547000            MOVE              A1,X:SV_A1
                            00000E
821       P:000210 P:000210 000000            NOP
822       P:000211 P:000211 01A786            JCLR    #TDE,X:SSISR1,*                   ; Start bit
                            000211
823       P:000213 P:000213 07F42C            MOVEP             #$010000,X:TX10
                            010000
824       P:000215 P:000215 060380            DO      #3,L_X
                            00021B
825       P:000217 P:000217 01A786            JCLR    #TDE,X:SSISR1,*                   ; Three data bytes
                            000217
826       P:000219 P:000219 04CCCC            MOVEP             A1,X:TX10
827       P:00021A P:00021A 0C1E90            LSL     #8,A
828       P:00021B P:00021B 000000            NOP
829                                 L_X
830       P:00021C P:00021C 01A786            JCLR    #TDE,X:SSISR1,*                   ; Zeroes to bring transmitter low
                            00021C
831       P:00021E P:00021E 07F42C            MOVEP             #0,X:TX10
                            000000
832       P:000220 P:000220 54F000            MOVE              X:SV_A1,A1
                            00000E
833       P:000222 P:000222 00000C            RTS
834    
835                                 SKIP
836    
837                                 ; Set up the circular SCI buffer, 32 words in size
838       P:000223 P:000223 64F400            MOVE              #SCI_TABLE,R4
                            000400
839       P:000225 P:000225 051FA4            MOVE              #31,M4
840       P:000226 P:000226 647000            MOVE              R4,X:(SCI_TABLE+33)
                            000421
841    
842                                           IF      @SCP("HOST","ROM")
850                                           ENDIF
851    
852       P:000228 P:000228 44F400            MOVE              #>$AC,X0
                            0000AC
853       P:00022A P:00022A 440100            MOVE              X0,X:<FO_HDR
854    
855       P:00022B P:00022B 0C0181            JMP     <STARTUP
856    
857                                 ;  ****************  X: Memory tables  ********************
858    
859                                 ; Define the address in P: space where the table of constants begins
860    
861                                  X_BOOT_START
862       00022A                              EQU     @LCV(L)-2
863    
864                                           IF      @SCP("HOST","ROM")
866                                           ENDIF
867                                           IF      @SCP("HOST","HOST")
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 17



868       X:000000 X:000000                   ORG     X:0,X:0
869                                           ENDIF
870    
871                                 ; Special storage area - initialization constants and scratch space
872       X:000000 X:000000         STATUS    DC      $64                               ; Controller status bits - quad readout, idl
e
873       000001                    FO_HDR    EQU     STATUS+1                          ; Fiber optic write bytes
874       000005                    HEADER    EQU     FO_HDR+4                          ; Command header
875       000006                    NWORDS    EQU     HEADER+1                          ; Number of words in the command
876       000007                    COM_BUF   EQU     NWORDS+1                          ; Command buffer
877       00000E                    SV_A1     EQU     COM_BUF+7                         ; Save accumulator A1
878    
879                                           IF      @SCP("HOST","ROM")
884                                           ENDIF
885    
886                                           IF      @SCP("HOST","HOST")
887       X:00000F X:00000F                   ORG     X:$F,X:$F
888                                           ENDIF
889    
890                                 ; Parameter table in P: space to be copied into X: space during
891                                 ;   initialization, and is copied from ROM by the DSP boot
892       X:00000F X:00000F         LATCH     DC      $3A                               ; Starting value in latch chip U25
893                                  EXPOSURE_TIME
894       X:000010 X:000010                   DC      0                                 ; Exposure time in milliseconds
895                                  ELAPSED_TIME
896       X:000011 X:000011                   DC      0                                 ; Time elapsed so far in the exposure
897       X:000012 X:000012         ONE       DC      1                                 ; One
898       X:000013 X:000013         TWO       DC      2                                 ; Two
899       X:000014 X:000014         THREE     DC      3                                 ; Three
900       X:000015 X:000015         SEVEN     DC      7                                 ; Seven
901       X:000016 X:000016         MASK1     DC      $FCFCF8                           ; Mask for checking header
902       X:000017 X:000017         MASK2     DC      $030300                           ; Mask for checking header
903       X:000018 X:000018         DONE      DC      'DON'                             ; Standard reply
904       X:000019 X:000019         SBRD      DC      $020000                           ; Source Identification number
905       X:00001A X:00001A         TIM_DRB   DC      $000200                           ; Destination = timing board number
906       X:00001B X:00001B         DMASK     DC      $00FF00                           ; Mask to get destination board number
907       X:00001C X:00001C         SMASK     DC      $FF0000                           ; Mask to get source board number
908       X:00001D X:00001D         ERR       DC      'ERR'                             ; An error occurred
909       X:00001E X:00001E         C100K     DC      100000                            ; Delay for WRROM = 1 millisec
910       X:00001F X:00001F         IDL_ADR   DC      TST_RCV                           ; Address of idling routine
911       X:000020 X:000020         EXP_ADR   DC      0                                 ; Jump to this address during exposures
912    
913                                 ; Places for saving register values
914       X:000021 X:000021         SAVE_SR   DC      0                                 ; Status Register
915       X:000022 X:000022         SAVE_X1   DC      0
916       X:000023 X:000023         SAVE_A1   DC      0
917       X:000024 X:000024         SAVE_R0   DC      0
918       X:000025 X:000025         RCV_ERR   DC      0
919       X:000026 X:000026         SCI_A1    DC      0                                 ; Contents of accumulator A1 in RCV ISR
920       X:000027 X:000027         SCI_R0    DC      SRXL
921    
922                                 ; Command table
923       000028                    COM_TBL_R EQU     @LCV(R)
924       X:000028 X:000028         COM_TBL   DC      'TDL',TDL                         ; Test Data Link
925       X:00002A X:00002A                   DC      'RDM',RDMEM                       ; Read from DSP or EEPROM memory
926       X:00002C X:00002C                   DC      'WRM',WRMEM                       ; Write to DSP memory
927       X:00002E X:00002E                   DC      'LDA',LDAPPL                      ; Load application from EEPROM to DSP
928       X:000030 X:000030                   DC      'STP',STOP_IDLE_CLOCKING
929       X:000032 X:000032                   DC      'DON',START                       ; Nothing special
930       X:000034 X:000034                   DC      'ERR',START                       ; Nothing special
931    
932                                  END_COMMAND_TABLE
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timboot.asm  Page 18



933       000036                              EQU     @LCV(R)
934    
935                                 ; The table at SCI_TABLE is for words received from the utility board, written by
936                                 ;   the interrupt service routine SCI_RCV. Note that it is 32 words long,
937                                 ;   hard coded, and the 33rd location contains the pointer to words that have
938                                 ;   been processed by moving them from the SCI_TABLE to the COM_BUF.
939    
940                                           IF      @SCP("HOST","ROM")
942                                           ENDIF
943    
944       000036                    END_ADR   EQU     @LCV(L)                           ; End address of P: code written to ROM
945    
946       P:00022C P:00022C                   ORG     P:,P:
947    
948       203C97                    CC        EQU     ARC22+ARC47+SHUTTER_CC+SPLIT_PARALLEL+SPLIT_SERIAL+SUBARRAY+BINNING+READOUT_SP
EEDS
949    
950                                 ; Put number of words of application in P: for loading application from EEPROM
951       P:00022C P:00022C                   DC      TIMBOOT_X_MEMORY-@LCV(L)-1
952    
953                                 ; Define CLOCK as a macro to produce in-line code to reduce execution time
954                                 CLOCK     MACRO
955  m                                        JCLR    #SSFHF,X:HDR,*                    ; Don't overfill the WRSS FIFO
956  m                                        REP     Y:(R0)+                           ; Repeat
957  m                                        MOVEP   Y:(R0)+,Y:WRSS                    ; Write the waveform to the FIFO
958  m                                        ENDM
959    
960                                 PARALLEL_CLOCK
961       P:00022D P:00022D 0A898E            JCLR    #SSFHF,X:HDR,*                    ; Don't overfill the WRSS FIFO
                            00022D
962       P:00022F P:00022F 065840            DO      Y:(R0)+,L_LINE                    ; Repeat
                            000233
963       P:000231 P:000231 0604A0            REP     #NUM_REPEATS
964       P:000232 P:000232 09E0F3            MOVEP             Y:(R0),Y:WRSS           ; Write the waveform to the FIFO
965       P:000233 P:000233 205800            MOVE              (R0)+
966                                 L_LINE
967       P:000234 P:000234 00000C            RTS
968    
969                                 ; Set software to IDLE mode
970                                 START_IDLE_CLOCKING
971       P:000235 P:000235 60F400            MOVE              #IDLE,R0                ; Exercise clocks when idling
                            00023A
972       P:000237 P:000237 601F00            MOVE              R0,X:<IDL_ADR
973       P:000238 P:000238 0A0022            BSET    #IDLMODE,X:<STATUS                ; Idle after readout
974       P:000239 P:000239 0C008F            JMP     <FINISH                           ; Need to send header and 'DON'
975    
976                                 ; Keep the CCD idling when not reading out
977       P:00023A P:00023A 060140  IDLE      DO      Y:<NSR,IDL1                       ; Loop over number of pixels per line
                            000246
978       P:00023C P:00023C 307F00            MOVE              #<SERIAL_IDLE,R0        ; Serial transfer on pixel
979                                           CLOCK                                     ; Go to it
983       P:000241 P:000241 330700            MOVE              #COM_BUF,R3
984       P:000242 P:000242 0D00A5            JSR     <GET_RCV                          ; Check for FO or SSI commands
985       P:000243 P:000243 0E0246            JCC     <NO_COM                           ; Continue IDLE if no commands received
986       P:000244 P:000244 00008C            ENDDO
987       P:000245 P:000245 0C005D            JMP     <PRC_RCV                          ; Go process header and command
988       P:000246 P:000246 000000  NO_COM    NOP
989                                 IDL1
990       P:000247 P:000247 306A00            MOVE              #<PARALLEL_SPLIT,R0     ; Address of parallel clocking waveform
991       P:000248 P:000248 0D022D            JSR     <PARALLEL_CLOCK                   ; Go clock out the CCD charge
992       P:000249 P:000249 0C023A            JMP     <IDLE
993    
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  tim.asm  Page 19



994                                 ;  *****************  Exposure and readout routines  *****************
995       P:00024A P:00024A 200013  RDCCD     CLR     A
996       P:00024B P:00024B 0A00B0            JSET    #ST_SA,X:STATUS,SUB_IMG
                            00025E
997       P:00024D P:00024D 5C1A00            MOVE                          A1,Y:<NP_SKIP ; Zero the subarray parameters
998       P:00024E P:00024E 5C1B00            MOVE                          A1,Y:<NS_SKP1
999       P:00024F P:00024F 5C1C00            MOVE                          A1,Y:<NS_SKP2
1000      P:000250 P:000250 5C2200            MOVE                          A1,Y:<N_BIAS
1001      P:000251 P:000251 5E8100            MOVE                          Y:<NSR,A
1002      P:000252 P:000252 0A0085            JCLR    #SPLIT_S,X:STATUS,*+3
                            000255
1003      P:000254 P:000254 200022            ASR     A                                 ; Split serials requires / 2
1004      P:000255 P:000255 000000            NOP
1005      P:000256 P:000256 5E2100            MOVE                          A,Y:<N_COLS ; Number of columns in whole image
1006      P:000257 P:000257 5E8200            MOVE                          Y:<NPR,A    ; NPARALLELS_READ = NPR
1007      P:000258 P:000258 0A0086            JCLR    #SPLIT_P,X:STATUS,*+3
                            00025B
1008      P:00025A P:00025A 200022            ASR     A                                 ; Split parallels requires / 2
1009      P:00025B P:00025B 000000            NOP
1010      P:00025C P:00025C 5E2000            MOVE                          A,Y:<N_ROWS ; Number of rows in whole image
1011      P:00025D P:00025D 0C027A            JMP     <READOUT
1012   
1013                                ; Enter the subarray readout parameters
1014      P:00025E P:00025E 5E9E00  SUB_IMG   MOVE                          Y:<NS_READ,A
1015      P:00025F P:00025F 0A0085            JCLR    #SPLIT_S,X:STATUS,*+3             ; Split serials requires / 2
                            000262
1016      P:000261 P:000261 200022            ASR     A
1017      P:000262 P:000262 000000            NOP
1018      P:000263 P:000263 5E2100            MOVE                          A,Y:<N_COLS ; Number of columns in each subimage
1019      P:000264 P:000264 5E9D00            MOVE                          Y:<NR_BIAS,A
1020      P:000265 P:000265 0A0085            JCLR    #SPLIT_S,X:STATUS,*+3             ; Split serials requires / 2
                            000268
1021      P:000267 P:000267 200022            ASR     A
1022      P:000268 P:000268 000000            NOP
1023      P:000269 P:000269 5E2200            MOVE                          A,Y:<N_BIAS ; Number of columns in the bias region
1024      P:00026A P:00026A 5E9F00            MOVE                          Y:<NP_READ,A
1025      P:00026B P:00026B 0A0086            JCLR    #SPLIT_P,X:STATUS,*+3             ; Split parallels requires / 2
                            00026E
1026      P:00026D P:00026D 200022            ASR     A
1027      P:00026E P:00026E 000000            NOP
1028      P:00026F P:00026F 5E2000            MOVE                          A,Y:<N_ROWS ; Number of rows in each subimage
1029   
1030                                ; Loop over each subarray box
1031      P:000270 P:000270 67F400            MOVE              #READ_TABLE,R7          ; Parameter table for subimage readout
                            000024
1032      P:000272 P:000272 062340            DO      Y:<NBOXES,L_NBOXES                ; Loop over number of boxes
                            0002C9
1033      P:000274 P:000274 4CDF00            MOVE                          Y:(R7)+,X0
1034      P:000275 P:000275 4C1A00            MOVE                          X0,Y:<NP_SKIP
1035      P:000276 P:000276 4CDF00            MOVE                          Y:(R7)+,X0
1036      P:000277 P:000277 4C1B00            MOVE                          X0,Y:<NS_SKP1
1037      P:000278 P:000278 4CDF00            MOVE                          Y:(R7)+,X0
1038      P:000279 P:000279 4C1C00            MOVE                          X0,Y:<NS_SKP2
1039   
1040                                ; Skip over the required number of rows for subimage readout
1041      P:00027A P:00027A 0D05A7  READOUT   JSR     <GENERATE_SERIAL_WAVEFORM
1042      P:00027B P:00027B 0D0414            JSR     <WAIT_TO_FINISH_CLOCKING
1043   
1044                                ; Skip over rows to get a clean readout in binning mode
1045      P:00027C P:00027C 061240            DO      Y:<Y_PRESCAN,L_YPRESCAN
                            000280
1046      P:00027E P:00027E 689300            MOVE                          Y:<PARALLEL,R0
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  tim.asm  Page 20



1047      P:00027F P:00027F 0D022D            JSR     <PARALLEL_CLOCK
1048      P:000280 P:000280 000000            NOP
1049                                L_YPRESCAN
1050   
1051                                ; Skip over rows in subarray mode
1052      P:000281 P:000281 061A40            DO      Y:<NP_SKIP,L_PSKP
                            000290
1053      P:000283 P:000283 060640            DO      Y:<NPBIN,L_PSKIP
                            000287
1054      P:000285 P:000285 689300            MOVE                          Y:<PARALLEL,R0
1055      P:000286 P:000286 0D022D            JSR     <PARALLEL_CLOCK
1056      P:000287 P:000287 000000            NOP
1057      P:000288 P:000288 000000  L_PSKIP   NOP
1058      P:000289 P:000289 06C880            DO      #NUM_CLEAN,L_CLEAN
                            00028F
1059      P:00028B P:00028B 689600            MOVE                          Y:<SERIAL_SKIP,R0 ; Waveform table starting address
1060                                          CLOCK                                     ; Go clock out the CCD charge
1064      P:000290 P:000290 000000  L_CLEAN   NOP
1065                                L_PSKP
1066   
1067                                ; Finally, this is the start of the big readout loop
1068      P:000291 P:000291 062040            DO      Y:<N_ROWS,LPR                     ; Loop over the number of rows in the image
                            0002C8
1069      P:000293 P:000293 060640            DO      Y:<NPBIN,L_PBIN
                            000297
1070      P:000295 P:000295 689300            MOVE                          Y:<PARALLEL,R0
1071      P:000296 P:000296 0D022D            JSR     <PARALLEL_CLOCK
1072      P:000297 P:000297 000000            NOP
1073                                L_PBIN
1074   
1075      P:000298 P:000298 0D083C            JSR     <SKIP_PRESCAN_PIXELS
1076   
1077                                ; Check for a command once per line. Only the ABORT command should be issued.
1078      P:000299 P:000299 330700            MOVE              #COM_BUF,R3
1079      P:00029A P:00029A 0D00A5            JSR     <GET_RCV                          ; Was a command received?
1080      P:00029B P:00029B 0E02A4            JCC     <CONTINUE_READ                    ; If no, continue reading out
1081      P:00029C P:00029C 0C005D            JMP     <PRC_RCV                          ; If yes, go process it
1082   
1083                                ; Abort the readout currently underway
1084      P:00029D P:00029D 0A0084  ABR_RDC   JCLR    #ST_RDC,X:<STATUS,ABORT_EXPOSURE
                            0003C4
1085      P:00029F P:00029F 00008C            ENDDO                                     ; Properly terminate the readout loop
1086      P:0002A0 P:0002A0 0A0090            JCLR    #ST_SA,X:STATUS,*+2
                            0002A2
1087      P:0002A2 P:0002A2 00008C            ENDDO                                     ; Properly terminate the subarray loop
1088      P:0002A3 P:0002A3 0C03C4            JMP     <ABORT_EXPOSURE
1089                                CONTINUE_READ
1090   
1091                                ; Skip over NS_SKP1 columns if needed for subimage readout
1092      P:0002A4 P:0002A4 061B40            DO      Y:<NS_SKP1,L_SKP1                 ; Number of waveform entries total
                            0002AD
1093      P:0002A6 P:0002A6 060540            DO      Y:<NSBIN,L_SKIP1
                            0002AC
1094      P:0002A8 P:0002A8 689600            MOVE                          Y:<SERIAL_SKIP,R0 ; Waveform table starting address
1095                                          CLOCK                                     ; Go clock out the CCD charge
1099      P:0002AD P:0002AD 000000  L_SKIP1   NOP
1100                                L_SKP1
1101   
1102                                ; Finally, read some real pixels
1103      P:0002AE P:0002AE 062140            DO      Y:<N_COLS,L_READ
                            0002B5
1104      P:0002B0 P:0002B0 60F400            MOVE              #PXL_TBL,R0
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  tim.asm  Page 21



                            0001E2
1105                                          CLOCK
1109                                L_READ
1110   
1111                                ; Skip over NS_SKP2 columns if needed for subimage readout
1112      P:0002B6 P:0002B6 061C40            DO      Y:<NS_SKP2,L_SKP2
                            0002BF
1113      P:0002B8 P:0002B8 060540            DO      Y:<NSBIN,L_SKIP2
                            0002BE
1114      P:0002BA P:0002BA 689600            MOVE                          Y:<SERIAL_SKIP,R0 ; Waveform table starting address
1115                                          CLOCK                                     ; Go clock out the CCD charge
1119      P:0002BF P:0002BF 000000  L_SKIP2   NOP
1120                                L_SKP2
1121   
1122                                ; Read the bias pixels if in subimage readout mode
1123      P:0002C0 P:0002C0 062240            DO      Y:<N_BIAS,END_ROW                 ; Number of pixels to read out
                            0002C7
1124      P:0002C2 P:0002C2 60F400            MOVE              #PXL_TBL,R0
                            0001E2
1125                                          CLOCK
1129      P:0002C8 P:0002C8 000000  END_ROW   NOP
1130      P:0002C9 P:0002C9 000000  LPR       NOP                                       ; End of parallel loop
1131                                L_NBOXES                                            ; End of subimage boxes loop
1132   
1133                                ; Restore the controller to non-image data transfer and idling if necessary
1134      P:0002CA P:0002CA 0A0082  RDC_END   JCLR    #IDLMODE,X:<STATUS,NO_IDL
                            0002D0
1135      P:0002CC P:0002CC 60F400            MOVE              #IDLE,R0
                            00023A
1136      P:0002CE P:0002CE 601F00            MOVE              R0,X:<IDL_ADR
1137      P:0002CF P:0002CF 0C02D2            JMP     <RDC_E
1138      P:0002D0 P:0002D0 305A00  NO_IDL    MOVE              #TST_RCV,R0             ; Don't idle after readout
1139      P:0002D1 P:0002D1 601F00            MOVE              R0,X:<IDL_ADR
1140      P:0002D2 P:0002D2 0D0414  RDC_E     JSR     <WAIT_TO_FINISH_CLOCKING
1141      P:0002D3 P:0002D3 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1142      P:0002D4 P:0002D4 0C0054            JMP     <START
1143   
1144                                ; Move the image up or down a set number of lines
1145                                MOVE_PARALLEL                                       ; arg0 = '_UP', 'DWN' or 'SPT', arg1 = numbe
r of lines
1146      P:0002D5 P:0002D5 56DB00            MOVE              X:(R3)+,A
1147      P:0002D6 P:0002D6 0140C5            CMP     #'_UP',A
                            5F5550
1148      P:0002D8 P:0002D8 0E22DD            JNE     <C_DOWN
1149      P:0002D9 P:0002D9 44F400            MOVE              #PARALLEL_UP_LEFT,X0
                            000042
1150      P:0002DB P:0002DB 4C1700            MOVE                          X0,Y:<MV_ADDR
1151      P:0002DC P:0002DC 0C02EA            JMP     <CLOCK_PARALLEL
1152   
1153      P:0002DD P:0002DD 0140C5  C_DOWN    CMP     #'DWN',A
                            44574E
1154      P:0002DF P:0002DF 0E22E4            JNE     <C_SPLIT
1155      P:0002E0 P:0002E0 44F400            MOVE              #PARALLEL_DOWN_LEFT,X0
                            000056
1156      P:0002E2 P:0002E2 4C1700            MOVE                          X0,Y:<MV_ADDR
1157      P:0002E3 P:0002E3 0C02EA            JMP     <CLOCK_PARALLEL
1158   
1159      P:0002E4 P:0002E4 0140C5  C_SPLIT   CMP     #'SPT',A
                            535054
1160      P:0002E6 P:0002E6 0E208D            JNE     <ERROR
1161      P:0002E7 P:0002E7 44F400            MOVE              #PARALLEL_SPLIT,X0
                            00006A
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  tim.asm  Page 22



1162      P:0002E9 P:0002E9 4C1700            MOVE                          X0,Y:<MV_ADDR
1163   
1164                                CLOCK_PARALLEL
1165      P:0002EA P:0002EA 065B00            DO      X:(R3)+,L_CLOCK_PARALLEL
                            0002F0
1166      P:0002EC P:0002EC 689700            MOVE                          Y:<MV_ADDR,R0
1167                                          CLOCK
1171                                L_CLOCK_PARALLEL
1172   
1173      P:0002F1 P:0002F1 0C008F            JMP     <FINISH
1174   
1175                                ; ******  Include many routines not directly needed for readout  *******
1176                                          INCLUDE "timCCDmisc.asm"
1177                                ; Miscellaneous CCD control routines
1178                                POWER_OFF
1179      P:0002F2 P:0002F2 0D0338            JSR     <CLEAR_SWITCHES                   ; Clear all analog switches
1180      P:0002F3 P:0002F3 0A8922            BSET    #LVEN,X:HDR
1181      P:0002F4 P:0002F4 0A8923            BSET    #HVEN,X:HDR
1182      P:0002F5 P:0002F5 0C008F            JMP     <FINISH
1183   
1184                                ; Execute the power-on cycle, as a command
1185                                POWER_ON
1186      P:0002F6 P:0002F6 0D0338            JSR     <CLEAR_SWITCHES                   ; Clear all analog switches
1187      P:0002F7 P:0002F7 0D0309            JSR     <PON                              ; Turn on the power control board
1188      P:0002F8 P:0002F8 0A8980            JCLR    #PWROK,X:HDR,PWR_ERR              ; Test if the power turned on properly
                            000306
1189      P:0002FA P:0002FA 0D0316            JSR     <SET_BIASES                       ; Turn on the DC bias supplies
1190      P:0002FB P:0002FB 012F23            BSET    #3,X:PCRD                         ; Turn on the serial clock
1191      P:0002FC P:0002FC 0D0417            JSR     <PAL_DLY                          ; Delay for all this to happen
1192      P:0002FD P:0002FD 0D05DD            JSR     <SEL_OS
1193      P:0002FE P:0002FE 0D0417            JSR     <PAL_DLY                          ; Delay for all this to happen
1194      P:0002FF P:0002FF 012F03            BCLR    #3,X:PCRD                         ; Turn off the serial clock
1195      P:000300 P:000300 0A0022            BSET    #IDLMODE,X:<STATUS                ; Idle after readout
1196      P:000301 P:000301 60F400            MOVE              #IDLE,R0                ; Put controller in IDLE state
                            00023A
1197      P:000303 P:000303 601F00            MOVE              R0,X:<IDL_ADR
1198      P:000304 P:000304 0A002C            BSET    #ST_DITH,X:<STATUS                ; Turn dithering on
1199      P:000305 P:000305 0C008F            JMP     <FINISH
1200   
1201                                ; Removed temporarily
1202                                ;       MOVE    #$41064,X0
1203                                ;       MOVE    X0,X:<STATUS
1204   
1205   
1206                                ; The power failed to turn on because of an error on the power control board
1207      P:000306 P:000306 0A8922  PWR_ERR   BSET    #LVEN,X:HDR                       ; Turn off the low voltage emable line
1208      P:000307 P:000307 0A8923            BSET    #HVEN,X:HDR                       ; Turn off the high voltage emable line
1209      P:000308 P:000308 0C008D            JMP     <ERROR
1210   
1211                                ; As a subroutine, turn on the low voltages (+/- 6.5V, +/- 16.5V) and delay
1212      P:000309 P:000309 0A8902  PON       BCLR    #LVEN,X:HDR                       ; Set these signals to DSP outputs
1213      P:00030A P:00030A 44F400            MOVE              #2000000,X0
                            1E8480
1214      P:00030C P:00030C 06C400            DO      X0,*+3                            ; Wait 20 millisec for settling
                            00030E
1215      P:00030E P:00030E 000000            NOP
1216   
1217                                ; Turn on the high +36 volt power line and then delay
1218      P:00030F P:00030F 0A8903            BCLR    #HVEN,X:HDR                       ; HVEN = Low => Turn on +36V
1219      P:000310 P:000310 44F400            MOVE              #1000000,X0
                            0F4240
1220      P:000312 P:000312 06C400            DO      X0,*+3                            ; Wait 100 millisec for settling
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 23



                            000314
1221      P:000314 P:000314 000000            NOP
1222      P:000315 P:000315 00000C            RTS
1223   
1224                                ; Set all the DC bias voltages and video processor offset values, reading
1225                                ;   them from the 'DACS' table
1226                                SET_BIASES
1227      P:000316 P:000316 012F23            BSET    #3,X:PCRD                         ; Turn on the serial clock
1228      P:000317 P:000317 0A0F01            BCLR    #1,X:<LATCH                       ; Separate updates of clock driver
1229      P:000318 P:000318 0A0F20            BSET    #CDAC,X:<LATCH                    ; Disable clearing of DACs
1230      P:000319 P:000319 0A0F22            BSET    #ENCK,X:<LATCH                    ; Enable clock and DAC output switches
1231      P:00031A P:00031A 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Write it to the hardware
                            00000F
1232      P:00031C P:00031C 0D0417            JSR     <PAL_DLY                          ; Delay for all this to happen
1233   
1234                                ; Read DAC values from a table, and write them to the DACs
1235      P:00031D P:00031D 60F400            MOVE              #DACS,R0                ; Get starting address of DAC values
                            00017D
1236      P:00031F P:00031F 000000            NOP
1237      P:000320 P:000320 000000            NOP
1238      P:000321 P:000321 065840            DO      Y:(R0)+,L_DAC                     ; Repeat Y:(R0)+ times
                            000325
1239      P:000323 P:000323 5ED800            MOVE                          Y:(R0)+,A   ; Read the table entry
1240      P:000324 P:000324 0D020C            JSR     <XMIT_A_WORD                      ; Transmit it to TIM-A-STD
1241      P:000325 P:000325 000000            NOP
1242                                L_DAC
1243   
1244                                ; Let the DAC voltages all ramp up before exiting
1245      P:000326 P:000326 44F400            MOVE              #400000,X0
                            061A80
1246      P:000328 P:000328 06C400            DO      X0,*+3                            ; 4 millisec delay
                            00032A
1247      P:00032A P:00032A 000000            NOP
1248      P:00032B P:00032B 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1249      P:00032C P:00032C 00000C            RTS
1250   
1251                                ; Read DAC values from a table, and write them to the DACs
1252      P:00032D P:00032D 000000  WR_DACS   NOP
1253      P:00032E P:00032E 065840            DO      Y:(R0)+,L_DACS                    ; Repeat Y:(R0)+ times
                            000332
1254      P:000330 P:000330 5ED800            MOVE                          Y:(R0)+,A   ; Read the table entry
1255      P:000331 P:000331 0D020C            JSR     <XMIT_A_WORD                      ; Transmit it to TIM-A-STD
1256      P:000332 P:000332 000000            NOP
1257                                L_DACS
1258      P:000333 P:000333 00000C            RTS
1259   
1260                                SET_BIAS_VOLTAGES
1261      P:000334 P:000334 0D0316            JSR     <SET_BIASES
1262      P:000335 P:000335 0C008F            JMP     <FINISH
1263   
1264      P:000336 P:000336 0D0338  CLR_SWS   JSR     <CLEAR_SWITCHES
1265      P:000337 P:000337 0C008F            JMP     <FINISH
1266   
1267                                ; Clear all video processor analog switches to lower their power dissipation
1268                                CLEAR_SWITCHES
1269      P:000338 P:000338 012F23            BSET    #3,X:PCRD                         ; Turn the serial clock on
1270      P:000339 P:000339 20001B            CLR     B
1271      P:00033A P:00033A 241000            MOVE              #$100000,X0             ; Increment over board numbers for DAC write
s
1272      P:00033B P:00033B 45F400            MOVE              #$001000,X1             ; Increment over board numbers for WRSS writ
es
                            001000
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 24



1273      P:00033D P:00033D 060F80            DO      #15,L_VIDEO                       ; Fifteen video processor boards maximum
                            000342
1274      P:00033F P:00033F 5F7000            MOVE                          B,Y:WRSS
                            FFFFF3
1275      P:000341 P:000341 0D0417            JSR     <PAL_DLY                          ; Delay for the serial data transmission
1276      P:000342 P:000342 200068            ADD     X1,B
1277                                L_VIDEO
1278      P:000343 P:000343 0A0F00            BCLR    #CDAC,X:<LATCH                    ; Enable clearing of DACs
1279      P:000344 P:000344 0A0F02            BCLR    #ENCK,X:<LATCH                    ; Disable clock and DAC output switches
1280      P:000345 P:000345 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Execute these two operations
                            00000F
1281      P:000347 P:000347 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1282      P:000348 P:000348 00000C            RTS
1283   
1284                                ; Open the shutter by setting the backplane bit TIM-LATCH0
1285      P:000349 P:000349 0A0023  OSHUT     BSET    #ST_SHUT,X:<STATUS                ; Set status bit to mean shutter open
1286      P:00034A P:00034A 0A0F04            BCLR    #SHUTTER,X:<LATCH                 ; Clear hardware shutter bit to open
1287      P:00034B P:00034B 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Write it to the hardware
                            00000F
1288      P:00034D P:00034D 00000C            RTS
1289   
1290                                ; Close the shutter by clearing the backplane bit TIM-LATCH0
1291      P:00034E P:00034E 0A0003  CSHUT     BCLR    #ST_SHUT,X:<STATUS                ; Clear status to mean shutter closed
1292      P:00034F P:00034F 0A0F24            BSET    #SHUTTER,X:<LATCH                 ; Set hardware shutter bit to close
1293      P:000350 P:000350 09F0B5            MOVEP             X:LATCH,Y:WRLATCH       ; Write it to the hardware
                            00000F
1294      P:000352 P:000352 00000C            RTS
1295   
1296                                ; Open the shutter from the timing board, executed as a command
1297                                OPEN_SHUTTER
1298      P:000353 P:000353 0D0349            JSR     <OSHUT
1299      P:000354 P:000354 0C008F            JMP     <FINISH
1300   
1301                                ; Close the shutter from the timing board, executed as a command
1302                                CLOSE_SHUTTER
1303      P:000355 P:000355 0D034E            JSR     <CSHUT
1304      P:000356 P:000356 0C008F            JMP     <FINISH
1305   
1306                                ; Clear the CCD, executed as a command
1307      P:000357 P:000357 0D0359  CLEAR     JSR     <CLR_CCD
1308      P:000358 P:000358 0C008F            JMP     <FINISH
1309   
1310                                ; Default clearing routine with serial clocks inactive
1311                                ; Fast clear image before each exposure, executed as a subroutine
1312      P:000359 P:000359 060340  CLR_CCD   DO      Y:<NPCLR,LPCLR2                   ; Loop over number of lines in image
                            000367
1313      P:00035B P:00035B 60F400            MOVE              #PARALLEL_SPLIT,R0      ; Address of parallel transfer waveform
                            00006A
1314      P:00035D P:00035D 0D022D            JSR     <PARALLEL_CLOCK
1315      P:00035E P:00035E 0A8989            JCLR    #EF,X:HDR,LPCLR1                  ; Simple test for fast execution
                            000367
1316      P:000360 P:000360 330700            MOVE              #COM_BUF,R3
1317      P:000361 P:000361 0D00A5            JSR     <GET_RCV                          ; Check for FO command
1318      P:000362 P:000362 0E0367            JCC     <LPCLR1                           ; Continue if no commands have been received
1319   
1320      P:000363 P:000363 60F400            MOVE              #LPCLR1,R0
                            000367
1321      P:000365 P:000365 601F00            MOVE              R0,X:<IDL_ADR
1322      P:000366 P:000366 0C005D            JMP     <PRC_RCV
1323      P:000367 P:000367 000000  LPCLR1    NOP
1324                                LPCLR2
1325      P:000368 P:000368 689800            MOVE                          Y:<EXPOSE_PARALLELS,R0 ; Put the parallel clocks in the 
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 25



correct state to
1326      P:000369 P:000369 0D022D            JSR     <PARALLEL_CLOCK                   ;   collect charge on only one parallel phas
e
1327      P:00036A P:00036A 00000C            RTS
1328   
1329                                ; Start the exposure timer and monitor its progress
1330      P:00036B P:00036B 07F40E  EXPOSE    MOVEP             #0,X:TLR0               ; Load 0 into counter timer
                            000000
1331      P:00036D P:00036D 240000            MOVE              #0,X0
1332      P:00036E P:00036E 441100            MOVE              X0,X:<ELAPSED_TIME      ; Set elapsed exposure time to zero
1333      P:00036F P:00036F 579000            MOVE              X:<EXPOSURE_TIME,B
1334      P:000370 P:000370 20000B            TST     B                                 ; Special test for zero exposure time
1335      P:000371 P:000371 0EA37F            JEQ     <END_EXP                          ; Don't even start an exposure
1336      P:000372 P:000372 01418C            SUB     #1,B                              ; Timer counts from X:TCPR0+1 to zero
1337      P:000373 P:000373 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Enable the timer #0
1338      P:000374 P:000374 577000            MOVE              B,X:TCPR0
                            FFFF8D
1339      P:000376 P:000376 0A8989  CHK_RCV   JCLR    #EF,X:HDR,CHK_TIM                 ; Simple test for fast execution
                            00037B
1340      P:000378 P:000378 330700            MOVE              #COM_BUF,R3             ; The beginning of the command buffer
1341      P:000379 P:000379 0D00A5            JSR     <GET_RCV                          ; Check for an incoming command
1342      P:00037A P:00037A 0E805D            JCS     <PRC_RCV                          ; If command is received, go check it
1343      P:00037B P:00037B 0B00AC  CHK_TIM   JSSET   #ST_DITH,X:STATUS,DITHER          ; Exercise the serial clocks during exposure
                            00085E
1344      P:00037D P:00037D 018F95            JCLR    #TCF,X:TCSR0,CHK_RCV              ; Wait for timer to equal compare value
                            000376
1345      P:00037F P:00037F 010F00  END_EXP   BCLR    #TIM_BIT,X:TCSR0                  ; Disable the timer
1346      P:000380 P:000380 0AE780            JMP     (R7)                              ; This contains the return address
1347   
1348                                ; Start the exposure, expose, and initiate the CCD readout
1349                                START_EXPOSURE
1350      P:000381 P:000381 57F400            MOVE              #$020102,B
                            020102
1351      P:000383 P:000383 0D00EB            JSR     <XMT_WRD
1352      P:000384 P:000384 57F400            MOVE              #'IIA',B                ; Initialize the PCI image address
                            494941
1353      P:000386 P:000386 0D00EB            JSR     <XMT_WRD
1354      P:000387 P:000387 0D0359            JSR     <CLR_CCD
1355      P:000388 P:000388 305A00            MOVE              #TST_RCV,R0             ; Process commands during the exposure
1356      P:000389 P:000389 601F00            MOVE              R0,X:<IDL_ADR
1357      P:00038A P:00038A 0D0414            JSR     <WAIT_TO_FINISH_CLOCKING
1358   
1359                                ; Operate the shutter if needed and begin exposure
1360      P:00038B P:00038B 0A008B            JCLR    #SHUT,X:STATUS,L_SEX0
                            00038E
1361      P:00038D P:00038D 0D0349            JSR     <OSHUT
1362      P:00038E P:00038E 67F400  L_SEX0    MOVE              #L_SEX1,R7              ; Return address at end of exposure
                            000391
1363      P:000390 P:000390 0C036B            JMP     <EXPOSE                           ; Delay for specified exposure time
1364                                L_SEX1
1365   
1366                                ; Now we really start the CCD readout, alerting the PCI board, closing the
1367                                ;  shutter, waiting for it to close and then reading out
1368      P:000391 P:000391 0D0407  STR_RDC   JSR     <PCI_READ_IMAGE                   ; Get the PCI board reading the image
1369      P:000392 P:000392 0A0024            BSET    #ST_RDC,X:<STATUS                 ; Set status to reading out
1370      P:000393 P:000393 0A008B            JCLR    #SHUT,X:STATUS,S_DEL0
                            0003A1
1371      P:000395 P:000395 0D034E            JSR     <CSHUT                            ; Close the shutter if necessary
1372   
1373                                ; Delay readout until the shutter has fully closed
1374      P:000396 P:000396 5E8E00            MOVE                          Y:<SHDEL,A
1375      P:000397 P:000397 200003            TST     A
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 26



1376      P:000398 P:000398 0EF3A1            JLE     <S_DEL0
1377      P:000399 P:000399 44F400            MOVE              #100000,X0
                            0186A0
1378      P:00039B P:00039B 06CE00            DO      A,S_DEL0                          ; Delay by Y:SHDEL milliseconds
                            0003A0
1379      P:00039D P:00039D 06C400            DO      X0,S_DEL1
                            00039F
1380      P:00039F P:00039F 000000            NOP
1381      P:0003A0 P:0003A0 000000  S_DEL1    NOP
1382                                S_DEL0
1383      P:0003A1 P:0003A1 0A00AA            JSET    #TST_IMG,X:STATUS,SYNTHETIC_IMAGE
                            0003D4
1384      P:0003A3 P:0003A3 0C024A            JMP     <RDCCD                            ; Finally, go read out the CCD
1385   
1386                                ; Set the desired exposure time
1387                                SET_EXPOSURE_TIME
1388      P:0003A4 P:0003A4 46DB00            MOVE              X:(R3)+,Y0
1389      P:0003A5 P:0003A5 461000            MOVE              Y0,X:EXPOSURE_TIME
1390      P:0003A6 P:0003A6 018F80            JCLR    #TIM_BIT,X:TCSR0,FINISH           ; Return if the exposure is not occurring
                            00008F
1391   
1392      P:0003A8 P:0003A8 044E8C            MOVEP             X:TCR0,A                ; If the new exposure time is .LE. the elaps
ed time then
1393      P:0003A9 P:0003A9 200055            CMP     Y0,A                              ;   set the new exposure time to 1 + elapsed
 time
1394      P:0003AA P:0003AA 0E93AF            JLT     <SET_0                            ; Elapsed time is less than the new time, so
 don't bother
1395      P:0003AB P:0003AB 014180            ADD     #1,A                              ; Add a 1 millisec to avoid a race condition
1396      P:0003AC P:0003AC 000000            NOP
1397      P:0003AD P:0003AD 04CC8D            MOVEP             A1,X:TCPR0
1398      P:0003AE P:0003AE 0C008F            JMP     <FINISH
1399   
1400      P:0003AF P:0003AF 04C68D  SET_0     MOVEP             Y0,X:TCPR0              ; Update timer if exposure in progress
1401      P:0003B0 P:0003B0 0C008F            JMP     <FINISH
1402   
1403                                ; Read the time remaining until the exposure ends
1404                                READ_EXPOSURE_TIME
1405      P:0003B1 P:0003B1 018FA0            JSET    #TIM_BIT,X:TCSR0,RD_TIM           ; Read DSP timer if its running
                            0003B5
1406      P:0003B3 P:0003B3 479100            MOVE              X:<ELAPSED_TIME,Y1
1407      P:0003B4 P:0003B4 0C0090            JMP     <FINISH1
1408      P:0003B5 P:0003B5 47F000  RD_TIM    MOVE              X:TCR0,Y1               ; Read elapsed exposure time
                            FFFF8C
1409      P:0003B7 P:0003B7 0C0090            JMP     <FINISH1
1410   
1411                                ; Pause the exposure - close the shutter and stop the timer
1412                                PAUSE_EXPOSURE
1413      P:0003B8 P:0003B8 07700C            MOVEP             X:TCR0,X:ELAPSED_TIME   ; Save the elapsed exposure time
                            000011
1414      P:0003BA P:0003BA 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the DSP exposure timer
1415      P:0003BB P:0003BB 0D034E            JSR     <CSHUT                            ; Close the shutter
1416      P:0003BC P:0003BC 0C008F            JMP     <FINISH
1417   
1418                                ; Resume the exposure - open the shutter if needed and restart the timer
1419                                RESUME_EXPOSURE
1420      P:0003BD P:0003BD 07F00E            MOVEP             X:ELAPSED_TIME,X:TLR0   ; Restore elapsed exposure time
                            000011
1421      P:0003BF P:0003BF 010F20            BSET    #TIM_BIT,X:TCSR0                  ; Re-enable the DSP exposure timer
1422      P:0003C0 P:0003C0 0A008B            JCLR    #SHUT,X:STATUS,L_RES
                            0003C3
1423      P:0003C2 P:0003C2 0D0349            JSR     <OSHUT                            ; Open the shutter if necessary
1424      P:0003C3 P:0003C3 0C008F  L_RES     JMP     <FINISH
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 27



1425   
1426                                ; Abort exposure - close the shutter, stop the timer and resume idle mode
1427                                ABORT_EXPOSURE
1428      P:0003C4 P:0003C4 0D034E            JSR     <CSHUT                            ; Close the shutter
1429      P:0003C5 P:0003C5 010F00            BCLR    #TIM_BIT,X:TCSR0                  ; Disable the DSP exposure timer
1430      P:0003C6 P:0003C6 0A0082            JCLR    #IDLMODE,X:<STATUS,NO_IDL2        ; Don't idle after readout
                            0003CC
1431      P:0003C8 P:0003C8 60F400            MOVE              #IDLE,R0
                            00023A
1432      P:0003CA P:0003CA 601F00            MOVE              R0,X:<IDL_ADR
1433      P:0003CB P:0003CB 0C03CE            JMP     <RDC_E2
1434      P:0003CC P:0003CC 305A00  NO_IDL2   MOVE              #TST_RCV,R0
1435      P:0003CD P:0003CD 601F00            MOVE              R0,X:<IDL_ADR
1436      P:0003CE P:0003CE 0D0414  RDC_E2    JSR     <WAIT_TO_FINISH_CLOCKING
1437      P:0003CF P:0003CF 0A0004            BCLR    #ST_RDC,X:<STATUS                 ; Set status to not reading out
1438      P:0003D0 P:0003D0 06A08F            DO      #4000,*+3                         ; Wait 40 microsec for the fiber
                            0003D2
1439      P:0003D2 P:0003D2 000000            NOP                                       ;  optic to clear out
1440      P:0003D3 P:0003D3 0C008F            JMP     <FINISH
1441   
1442                                ; Generate a synthetic image by simply incrementing the pixel counts
1443                                SYNTHETIC_IMAGE
1444      P:0003D4 P:0003D4 200013            CLR     A
1445      P:0003D5 P:0003D5 060240            DO      Y:<NPR,LPR_TST                    ; Loop over each line readout
                            0003E0
1446      P:0003D7 P:0003D7 060140            DO      Y:<NSR,LSR_TST                    ; Loop over number of pixels per line
                            0003DF
1447      P:0003D9 P:0003D9 0614A0            REP     #20                               ; #20 => 1.0 microsec per pixel
1448      P:0003DA P:0003DA 000000            NOP
1449      P:0003DB P:0003DB 014180            ADD     #1,A                              ; Pixel data = Pixel data + 1
1450      P:0003DC P:0003DC 000000            NOP
1451      P:0003DD P:0003DD 21CF00            MOVE              A,B
1452      P:0003DE P:0003DE 0D03E2            JSR     <XMT_PIX                          ;  transmit them
1453      P:0003DF P:0003DF 000000            NOP
1454                                LSR_TST
1455      P:0003E0 P:0003E0 000000            NOP
1456                                LPR_TST
1457      P:0003E1 P:0003E1 0C02CA            JMP     <RDC_END                          ; Normal exit
1458   
1459                                ; Transmit the 16-bit pixel datum in B1 to the host computer
1460      P:0003E2 P:0003E2 0C1DA1  XMT_PIX   ASL     #16,B,B
1461      P:0003E3 P:0003E3 000000            NOP
1462      P:0003E4 P:0003E4 216500            MOVE              B2,X1
1463      P:0003E5 P:0003E5 0C1D91            ASL     #8,B,B
1464      P:0003E6 P:0003E6 000000            NOP
1465      P:0003E7 P:0003E7 216400            MOVE              B2,X0
1466      P:0003E8 P:0003E8 000000            NOP
1467      P:0003E9 P:0003E9 09C532            MOVEP             X1,Y:WRFO
1468      P:0003EA P:0003EA 09C432            MOVEP             X0,Y:WRFO
1469      P:0003EB P:0003EB 00000C            RTS
1470   
1471                                ; Test the hardware to read A/D values directly into the DSP instead
1472                                ;   of using the SXMIT option, A/Ds #2 and 3.
1473      P:0003EC P:0003EC 57F000  READ_AD   MOVE              X:(RDAD+2),B
                            010002
1474      P:0003EE P:0003EE 0C1DA1            ASL     #16,B,B
1475      P:0003EF P:0003EF 000000            NOP
1476      P:0003F0 P:0003F0 216500            MOVE              B2,X1
1477      P:0003F1 P:0003F1 0C1D91            ASL     #8,B,B
1478      P:0003F2 P:0003F2 000000            NOP
1479      P:0003F3 P:0003F3 216400            MOVE              B2,X0
1480      P:0003F4 P:0003F4 000000            NOP
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 28



1481      P:0003F5 P:0003F5 09C532            MOVEP             X1,Y:WRFO
1482      P:0003F6 P:0003F6 09C432            MOVEP             X0,Y:WRFO
1483      P:0003F7 P:0003F7 060AA0            REP     #10
1484      P:0003F8 P:0003F8 000000            NOP
1485      P:0003F9 P:0003F9 57F000            MOVE              X:(RDAD+3),B
                            010003
1486      P:0003FB P:0003FB 0C1DA1            ASL     #16,B,B
1487      P:0003FC P:0003FC 000000            NOP
1488      P:0003FD P:0003FD 216500            MOVE              B2,X1
1489      P:0003FE P:0003FE 0C1D91            ASL     #8,B,B
1490      P:0003FF P:0003FF 000000            NOP
1491      P:000400 P:000400 216400            MOVE              B2,X0
1492      P:000401 P:000401 000000            NOP
1493      P:000402 P:000402 09C532            MOVEP             X1,Y:WRFO
1494      P:000403 P:000403 09C432            MOVEP             X0,Y:WRFO
1495      P:000404 P:000404 060AA0            REP     #10
1496      P:000405 P:000405 000000            NOP
1497      P:000406 P:000406 00000C            RTS
1498   
1499                                ; Alert the PCI interface board that images are coming soon
1500                                PCI_READ_IMAGE
1501      P:000407 P:000407 57F400            MOVE              #$020104,B              ; Send header word to the FO xmtr
                            020104
1502      P:000409 P:000409 0D00EB            JSR     <XMT_WRD
1503      P:00040A P:00040A 57F400            MOVE              #'RDA',B
                            524441
1504      P:00040C P:00040C 0D00EB            JSR     <XMT_WRD
1505      P:00040D P:00040D 5FF000            MOVE                          Y:NSR,B     ; Number of columns to read
                            000001
1506      P:00040F P:00040F 0D00EB            JSR     <XMT_WRD
1507      P:000410 P:000410 5FF000            MOVE                          Y:NPR,B     ; Number of rows to read
                            000002
1508      P:000412 P:000412 0D00EB            JSR     <XMT_WRD
1509      P:000413 P:000413 00000C            RTS
1510   
1511                                ; Wait for the clocking to be complete before proceeding
1512                                WAIT_TO_FINISH_CLOCKING
1513      P:000414 P:000414 01ADA1            JSET    #SSFEF,X:PDRD,*                   ; Wait for the SS FIFO to be empty
                            000414
1514      P:000416 P:000416 00000C            RTS
1515   
1516                                ; Delay for serial writes to the PALs and DACs by 8 microsec
1517      P:000417 P:000417 062083  PAL_DLY   DO      #800,*+3                          ; Wait 8 usec for serial data xmit
                            000419
1518      P:000419 P:000419 000000            NOP
1519      P:00041A P:00041A 00000C            RTS
1520   
1521                                ; Let the host computer read the controller configuration
1522                                READ_CONTROLLER_CONFIGURATION
1523      P:00041B P:00041B 4F8700            MOVE                          Y:<CONFIG,Y1 ; Just transmit the configuration
1524      P:00041C P:00041C 0C0090            JMP     <FINISH1
1525   
1526                                ; Set the video processor gain:   SGN  #Board   #GAIN  #Time Constant   (0 TO 15)
1527                                SET_GAIN
1528      P:00041D P:00041D 012F23            BSET    #3,X:PCRD                         ; Turn on the serial clock
1529      P:00041E P:00041E 0D0417            JSR     <PAL_DLY
1530      P:00041F P:00041F 56DB00            MOVE              X:(R3)+,A               ; Board number
1531      P:000420 P:000420 0C1EA8            LSL     #20,A
1532      P:000421 P:000421 240D00            MOVE              #$0D0000,X0
1533      P:000422 P:000422 218500            MOVE              A1,X1
1534      P:000423 P:000423 200042            OR      X0,A
1535      P:000424 P:000424 44DB00            MOVE              X:(R3)+,X0              ; Gain
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 29



1536      P:000425 P:000425 200042            OR      X0,A
1537      P:000426 P:000426 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1538   
1539      P:000427 P:000427 56DB00            MOVE              X:(R3)+,A               ; Time constant
1540      P:000428 P:000428 0C1E88            LSL     #4,A
1541      P:000429 P:000429 200062            OR      X1,A1                             ; Board number is in bits #23-20
1542      P:00042A P:00042A 44F400            MOVE              #$0C0100,X0
                            0C0100
1543      P:00042C P:00042C 200042            OR      X0,A
1544      P:00042D P:00042D 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1545      P:00042E P:00042E 0D0417            JSR     <PAL_DLY
1546      P:00042F P:00042F 012F03            BCLR    #3,X:PCRD                         ; Turn off the serial clock
1547      P:000430 P:000430 0C008F            JMP     <FINISH
1548   
1549                                ; **********************************************************************************************
1550                                ; Set a particular DAC numbers, for setting DC bias voltages, clock driver
1551                                ;   voltages and video processor offset
1552                                ; This is code for the ARC32 clock driver and ARC47 CCD video processor
1553                                ;
1554                                ; SBN  #BOARD  #DAC  ['CLK' or 'VID'] voltage
1555                                ;
1556                                ;                               #BOARD is from 0 to 15
1557                                ;                               #DAC number
1558                                ;                               #voltage is from 0 to 255 for ARC-32, to 16383 for ARC-47
1559   
1560                                SET_BIAS_NUMBER                                     ; Set bias number
1561      P:000431 P:000431 012F23            BSET    #3,X:PCRD                         ; Turn on the serial clock
1562      P:000432 P:000432 56DB00            MOVE              X:(R3)+,A               ; First argument is board number, 0 to 15
1563      P:000433 P:000433 0C1EA8            LSL     #20,A
1564      P:000434 P:000434 000000            NOP
1565      P:000435 P:000435 21C500            MOVE              A,X1                    ; Board number is in X1 bits #23-20
1566      P:000436 P:000436 56DB00            MOVE              X:(R3)+,A               ; Second argument is DAC number
1567      P:000437 P:000437 57DB00            MOVE              X:(R3)+,B               ; Third argument is 'VID' or 'CLK' string
1568      P:000438 P:000438 0140CD            CMP     #'VID',B
                            564944
1569      P:00043A P:00043A 0EA477            JEQ     <VID_SBN
1570      P:00043B P:00043B 0140CD            CMP     #'CLK',B
                            434C4B
1571      P:00043D P:00043D 0E2474            JNE     <ERR_SBN
1572   
1573                                ; Clock driver board
1574      P:00043E P:00043E 218F00            MOVE              A1,B                    ; DAC number, 0 to 23
1575      P:00043F P:00043F 0C1E9C            LSL     #14,A
1576      P:000440 P:000440 240E00            MOVE              #$0E0000,X0
1577      P:000441 P:000441 200046            AND     X0,A
1578      P:000442 P:000442 44F400            MOVE              #>7,X0
                            000007
1579      P:000444 P:000444 20004E            AND     X0,B                              ; Get 3 least significant bits of clock #
1580      P:000445 P:000445 01408D            CMP     #0,B
1581      P:000446 P:000446 0E2449            JNE     <CLK_1
1582      P:000447 P:000447 0ACE68            BSET    #8,A
1583      P:000448 P:000448 0C0464            JMP     <BD_SET
1584      P:000449 P:000449 01418D  CLK_1     CMP     #1,B
1585      P:00044A P:00044A 0E244D            JNE     <CLK_2
1586      P:00044B P:00044B 0ACE69            BSET    #9,A
1587      P:00044C P:00044C 0C0464            JMP     <BD_SET
1588      P:00044D P:00044D 01428D  CLK_2     CMP     #2,B
1589      P:00044E P:00044E 0E2451            JNE     <CLK_3
1590      P:00044F P:00044F 0ACE6A            BSET    #10,A
1591      P:000450 P:000450 0C0464            JMP     <BD_SET
1592      P:000451 P:000451 01438D  CLK_3     CMP     #3,B
1593      P:000452 P:000452 0E2455            JNE     <CLK_4
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 30



1594      P:000453 P:000453 0ACE6B            BSET    #11,A
1595      P:000454 P:000454 0C0464            JMP     <BD_SET
1596      P:000455 P:000455 01448D  CLK_4     CMP     #4,B
1597      P:000456 P:000456 0E2459            JNE     <CLK_5
1598      P:000457 P:000457 0ACE6D            BSET    #13,A
1599      P:000458 P:000458 0C0464            JMP     <BD_SET
1600      P:000459 P:000459 01458D  CLK_5     CMP     #5,B
1601      P:00045A P:00045A 0E245D            JNE     <CLK_6
1602      P:00045B P:00045B 0ACE6E            BSET    #14,A
1603      P:00045C P:00045C 0C0464            JMP     <BD_SET
1604      P:00045D P:00045D 01468D  CLK_6     CMP     #6,B
1605      P:00045E P:00045E 0E2461            JNE     <CLK_7
1606      P:00045F P:00045F 0ACE6F            BSET    #15,A
1607      P:000460 P:000460 0C0464            JMP     <BD_SET
1608      P:000461 P:000461 01478D  CLK_7     CMP     #7,B
1609      P:000462 P:000462 0E2464            JNE     <BD_SET
1610      P:000463 P:000463 0ACE70            BSET    #16,A
1611   
1612      P:000464 P:000464 200062  BD_SET    OR      X1,A                              ; Add on the board number
1613      P:000465 P:000465 000000            NOP
1614      P:000466 P:000466 21C400            MOVE              A,X0
1615      P:000467 P:000467 56DB00            MOVE              X:(R3)+,A               ; Fourth argument is voltage value, 0 to $FF
1616      P:000468 P:000468 0604A0            REP     #4
1617      P:000469 P:000469 200023            LSR     A                                 ; Convert 12 bits to 8 bits for ARC32
1618      P:00046A P:00046A 46F400            MOVE              #>$FF,Y0                ; Mask off just 8 bits
                            0000FF
1619      P:00046C P:00046C 200056            AND     Y0,A
1620      P:00046D P:00046D 200042            OR      X0,A
1621      P:00046E P:00046E 000000            NOP
1622      P:00046F P:00046F 5C0000            MOVE                          A1,Y:0      ; Save the DAC number for a little while
1623      P:000470 P:000470 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1624      P:000471 P:000471 0D0417            JSR     <PAL_DLY                          ; Wait for the number to be sent
1625      P:000472 P:000472 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1626      P:000473 P:000473 0C008F            JMP     <FINISH
1627      P:000474 P:000474 56DB00  ERR_SBN   MOVE              X:(R3)+,A               ; Read and discard the fourth argument
1628      P:000475 P:000475 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1629      P:000476 P:000476 0C008D            JMP     <ERROR
1630   
1631                                ; DC bias supply on the ARC-47 video board, excluding video offsets
1632      P:000477 P:000477 014085  VID_SBN   CMP     #0,A
1633      P:000478 P:000478 0E247C            JNE     <CMP1V
1634      P:000479 P:000479 2E0E00            MOVE              #$0E0000,A              ; Magic number for channel #0, Vod0
1635      P:00047A P:00047A 200062            OR      X1,A                              ; Add on the board number
1636      P:00047B P:00047B 0C0510            JMP     <SVO_XMT                          ; Pin #52
1637      P:00047C P:00047C 014185  CMP1V     CMP     #1,A
1638      P:00047D P:00047D 0E2482            JNE     <CMP2V
1639      P:00047E P:00047E 56F400            MOVE              #$0E0004,A              ; Magic number for channel #1, Vrd0
                            0E0004
1640      P:000480 P:000480 200062            OR      X1,A                              ; Pin #13
1641      P:000481 P:000481 0C0510            JMP     <SVO_XMT
1642      P:000482 P:000482 014285  CMP2V     CMP     #2,A
1643      P:000483 P:000483 0E2488            JNE     <CMP3V
1644      P:000484 P:000484 56F400            MOVE              #$0E0008,A              ; Magic number for channel #2, Vog0
                            0E0008
1645      P:000486 P:000486 200062            OR      X1,A                              ; Pin #29
1646      P:000487 P:000487 0C0510            JMP     <SVO_XMT
1647      P:000488 P:000488 014385  CMP3V     CMP     #3,A
1648      P:000489 P:000489 0E248E            JNE     <CMP4V
1649      P:00048A P:00048A 56F400            MOVE              #$0E000C,A              ; Magic number for channel #3, Vrsv0
                            0E000C
1650      P:00048C P:00048C 200062            OR      X1,A                              ; Pin #5
1651      P:00048D P:00048D 0C0510            JMP     <SVO_XMT
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 31



1652   
1653      P:00048E P:00048E 014485  CMP4V     CMP     #4,A
1654      P:00048F P:00048F 0E2494            JNE     <CMP5V
1655      P:000490 P:000490 56F400            MOVE              #$0E0001,A              ; Magic number for channel #4, Vod1
                            0E0001
1656      P:000492 P:000492 200062            OR      X1,A                              ; Pin #32
1657      P:000493 P:000493 0C0510            JMP     <SVO_XMT
1658      P:000494 P:000494 014585  CMP5V     CMP     #5,A
1659      P:000495 P:000495 0E249A            JNE     <CMP6V
1660      P:000496 P:000496 56F400            MOVE              #$0E0005,A              ; Magic number for channel #5, Vrd1
                            0E0005
1661      P:000498 P:000498 200062            OR      X1,A                              ; Pin #55
1662      P:000499 P:000499 0C0510            JMP     <SVO_XMT
1663      P:00049A P:00049A 014685  CMP6V     CMP     #6,A
1664      P:00049B P:00049B 0E24A0            JNE     <CMP7V
1665      P:00049C P:00049C 56F400            MOVE              #$0E0009,A              ; Magic number for channel #6, Vog1
                            0E0009
1666      P:00049E P:00049E 200062            OR      X1,A                              ; Pin #8
1667      P:00049F P:00049F 0C0510            JMP     <SVO_XMT
1668      P:0004A0 P:0004A0 014785  CMP7V     CMP     #7,A
1669      P:0004A1 P:0004A1 0E24A6            JNE     <CMP8V
1670      P:0004A2 P:0004A2 56F400            MOVE              #$0E000D,A              ; Magic number for channel #7, Vrsv1
                            0E000D
1671      P:0004A4 P:0004A4 200062            OR      X1,A                              ; Pin #47
1672      P:0004A5 P:0004A5 0C0510            JMP     <SVO_XMT
1673   
1674      P:0004A6 P:0004A6 014885  CMP8V     CMP     #8,A
1675      P:0004A7 P:0004A7 0E24AC            JNE     <CMP9V
1676      P:0004A8 P:0004A8 56F400            MOVE              #$0E0002,A              ; Magic number for channel #8, Vod2
                            0E0002
1677      P:0004AA P:0004AA 200062            OR      X1,A                              ; Pin #11
1678      P:0004AB P:0004AB 0C0510            JMP     <SVO_XMT
1679      P:0004AC P:0004AC 014985  CMP9V     CMP     #9,A
1680      P:0004AD P:0004AD 0E24B2            JNE     <CMP10V
1681      P:0004AE P:0004AE 56F400            MOVE              #$0E0006,A              ; Magic number for channel #9, Vrd2
                            0E0006
1682      P:0004B0 P:0004B0 200062            OR      X1,A                              ; Pin #35
1683      P:0004B1 P:0004B1 0C0510            JMP     <SVO_XMT
1684      P:0004B2 P:0004B2 014A85  CMP10V    CMP     #10,A
1685      P:0004B3 P:0004B3 0E24B8            JNE     <CMP11V
1686      P:0004B4 P:0004B4 56F400            MOVE              #$0E000A,A              ; Magic number for channel #10, Vog2
                            0E000A
1687      P:0004B6 P:0004B6 200062            OR      X1,A                              ; Pin #50
1688      P:0004B7 P:0004B7 0C0510            JMP     <SVO_XMT
1689      P:0004B8 P:0004B8 014B85  CMP11V    CMP     #11,A
1690      P:0004B9 P:0004B9 0E24BE            JNE     <CMP12V
1691      P:0004BA P:0004BA 56F400            MOVE              #$0E000E,A              ; Magic number for channel #11, Vrsv2
                            0E000E
1692      P:0004BC P:0004BC 200062            OR      X1,A                              ; Pin #27
1693      P:0004BD P:0004BD 0C0510            JMP     <SVO_XMT
1694   
1695      P:0004BE P:0004BE 014C85  CMP12V    CMP     #12,A
1696      P:0004BF P:0004BF 0E24C4            JNE     <CMP13V
1697      P:0004C0 P:0004C0 56F400            MOVE              #$0E0003,A              ; Magic number for channel #12, Vod3
                            0E0003
1698      P:0004C2 P:0004C2 200062            OR      X1,A                              ; Pin #53
1699      P:0004C3 P:0004C3 0C0510            JMP     <SVO_XMT
1700      P:0004C4 P:0004C4 014D85  CMP13V    CMP     #13,A
1701      P:0004C5 P:0004C5 0E24CA            JNE     <CMP14V
1702      P:0004C6 P:0004C6 56F400            MOVE              #$0E0007,A              ; Magic number for channel #13, Vrd3
                            0E0007
1703      P:0004C8 P:0004C8 200062            OR      X1,A                              ; Pin #14
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 32



1704      P:0004C9 P:0004C9 0C0510            JMP     <SVO_XMT
1705      P:0004CA P:0004CA 014E85  CMP14V    CMP     #14,A
1706      P:0004CB P:0004CB 0E24D0            JNE     <CMP15V
1707      P:0004CC P:0004CC 56F400            MOVE              #$0E000B,A              ; Magic number for channel #14, Vog3
                            0E000B
1708      P:0004CE P:0004CE 200062            OR      X1,A                              ; Pin #30
1709      P:0004CF P:0004CF 0C0510            JMP     <SVO_XMT
1710      P:0004D0 P:0004D0 014F85  CMP15V    CMP     #15,A
1711      P:0004D1 P:0004D1 0E24BE            JNE     <CMP12V
1712      P:0004D2 P:0004D2 56F400            MOVE              #$0E000F,A              ; Magic number for channel #15, Vrsv3
                            0E000F
1713      P:0004D4 P:0004D4 200042            OR      X0,A                              ; Pin #6
1714   
1715      P:0004D5 P:0004D5 015085  CMP16V    CMP     #16,A
1716      P:0004D6 P:0004D6 0E24DB            JNE     <CMP17V
1717      P:0004D7 P:0004D7 56F400            MOVE              #$0E0003,A              ; Magic number for channel #12, Vod3
                            0E0003
1718      P:0004D9 P:0004D9 200062            OR      X1,A                              ; Pin #33
1719      P:0004DA P:0004DA 0C0510            JMP     <SVO_XMT
1720      P:0004DB P:0004DB 015185  CMP17V    CMP     #17,A
1721      P:0004DC P:0004DC 0E24E1            JNE     <CMP18V
1722      P:0004DD P:0004DD 56F400            MOVE              #$0E0007,A              ; Magic number for channel #13, Vrd3
                            0E0007
1723      P:0004DF P:0004DF 200062            OR      X1,A                              ; Pin #56
1724      P:0004E0 P:0004E0 0C0510            JMP     <SVO_XMT
1725      P:0004E1 P:0004E1 015285  CMP18V    CMP     #18,A
1726      P:0004E2 P:0004E2 0E24E7            JNE     <CMP19V
1727      P:0004E3 P:0004E3 56F400            MOVE              #$0E000B,A              ; Magic number for channel #14, Vog3
                            0E000B
1728      P:0004E5 P:0004E5 200062            OR      X1,A                              ; Pin #9
1729      P:0004E6 P:0004E6 0C0510            JMP     <SVO_XMT
1730      P:0004E7 P:0004E7 015385  CMP19V    CMP     #19,A
1731      P:0004E8 P:0004E8 0E2474            JNE     <ERR_SBN
1732      P:0004E9 P:0004E9 56F400            MOVE              #$0E000F,A              ; Magic number for channel #15, Vrsv3
                            0E000F
1733      P:0004EB P:0004EB 200042            OR      X0,A                              ; Pin #48
1734   
1735                                ; Set the video offset for the ARC-47 4-channel CCD video board
1736                                ; SVO  #Board  #Channel  #Voltage       Board number is from 0 to 15
1737                                ;                                       DAC number from 0 to 7
1738                                ;                                       Voltage number is from 0 to 16,383 (14 bits)
1739   
1740                                SET_VIDEO_OFFSET
1741      P:0004EC P:0004EC 012F23            BSET    #3,X:PCRD                         ; Turn on the serial clock
1742      P:0004ED P:0004ED 56DB00            MOVE              X:(R3)+,A               ; First argument is board number, 0 to 15
1743      P:0004EE P:0004EE 200003            TST     A
1744      P:0004EF P:0004EF 0E9522            JLT     <ERR_SV1
1745      P:0004F0 P:0004F0 014F85            CMP     #15,A
1746      P:0004F1 P:0004F1 0E7522            JGT     <ERR_SV1
1747      P:0004F2 P:0004F2 0C1EA8            LSL     #20,A
1748      P:0004F3 P:0004F3 000000            NOP
1749      P:0004F4 P:0004F4 21C500            MOVE              A,X1                    ; Board number is in bits #23-20
1750      P:0004F5 P:0004F5 56DB00            MOVE              X:(R3)+,A               ; Second argument is the video channel numbe
r
1751      P:0004F6 P:0004F6 014085            CMP     #0,A
1752      P:0004F7 P:0004F7 0E24FC            JNE     <CMP1
1753      P:0004F8 P:0004F8 56F400            MOVE              #$0E0014,A              ; Magic number for channel #0
                            0E0014
1754      P:0004FA P:0004FA 200062            OR      X1,A
1755      P:0004FB P:0004FB 0C0510            JMP     <SVO_XMT
1756      P:0004FC P:0004FC 014185  CMP1      CMP     #1,A
1757      P:0004FD P:0004FD 0E2502            JNE     <CMP2
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 33



1758      P:0004FE P:0004FE 56F400            MOVE              #$0E0015,A              ; Magic number for channel #1
                            0E0015
1759      P:000500 P:000500 200062            OR      X1,A
1760      P:000501 P:000501 0C0510            JMP     <SVO_XMT
1761      P:000502 P:000502 014285  CMP2      CMP     #2,A
1762      P:000503 P:000503 0E2508            JNE     <CMP3
1763      P:000504 P:000504 56F400            MOVE              #$0E0016,A              ; Magic number for channel #2
                            0E0016
1764      P:000506 P:000506 200062            OR      X1,A
1765      P:000507 P:000507 0C0510            JMP     <SVO_XMT
1766      P:000508 P:000508 014385  CMP3      CMP     #3,A
1767      P:000509 P:000509 0E250E            JNE     <CMP4
1768      P:00050A P:00050A 56F400            MOVE              #$0E0017,A              ; Magic number for channel #3
                            0E0017
1769      P:00050C P:00050C 200062            OR      X1,A
1770      P:00050D P:00050D 0C0510            JMP     <SVO_XMT
1771      P:00050E P:00050E 014485  CMP4      CMP     #4,A
1772      P:00050F P:00050F 0E2529            JNE     <ERR_SV3
1773   
1774      P:000510 P:000510 5C0000  SVO_XMT   MOVE                          A1,Y:0
1775   
1776      P:000511 P:000511 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1777      P:000512 P:000512 0D0417            JSR     <PAL_DLY                          ; Wait for the number to be sent
1778      P:000513 P:000513 56DB00            MOVE              X:(R3)+,A               ; Third argument is the DAC voltage number
1779      P:000514 P:000514 200003            TST     A
1780      P:000515 P:000515 0E9529            JLT     <ERR_SV3                          ; Voltage number needs to be positive
1781      P:000516 P:000516 0140C5            CMP     #$3FFF,A                          ; Voltage number needs to be 14 bits
                            003FFF
1782      P:000518 P:000518 0E7529            JGT     <ERR_SV3
1783      P:000519 P:000519 200062            OR      X1,A                              ; Add in the board number
1784      P:00051A P:00051A 0140C2            OR      #$0FC000,A
                            0FC000
1785      P:00051C P:00051C 000000            NOP
1786      P:00051D P:00051D 5C0100            MOVE                          A1,Y:1
1787      P:00051E P:00051E 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1788      P:00051F P:00051F 0D0417            JSR     <PAL_DLY
1789      P:000520 P:000520 012F03            BCLR    #3,X:PCRD                         ; Turn off the serial clock
1790      P:000521 P:000521 0C008F            JMP     <FINISH
1791      P:000522 P:000522 012F03  ERR_SV1   BCLR    #3,X:PCRD                         ; Turn off the serial clock
1792      P:000523 P:000523 56DB00            MOVE              X:(R3)+,A
1793      P:000524 P:000524 56DB00            MOVE              X:(R3)+,A
1794      P:000525 P:000525 0C008D            JMP     <ERROR
1795      P:000526 P:000526 012F03  ERR_SV2   BCLR    #3,X:PCRD                         ; Turn off the serial clock
1796      P:000527 P:000527 56DB00            MOVE              X:(R3)+,A
1797      P:000528 P:000528 0C008D            JMP     <ERROR
1798      P:000529 P:000529 012F03  ERR_SV3   BCLR    #3,X:PCRD                         ; Turn off the serial clock
1799      P:00052A P:00052A 0C008D            JMP     <ERROR
1800   
1801                                ; Specify the MUX value to be output on the clock driver board
1802                                ; Command syntax is  SMX  #clock_driver_board #MUX1 #MUX2
1803                                ;                               #clock_driver_board from 0 to 15
1804                                ;                               #MUX1, #MUX2 from 0 to 23
1805   
1806      P:00052B P:00052B 012F23  SET_MUX   BSET    #3,X:PCRD                         ; Turn on the serial clock
1807      P:00052C P:00052C 56DB00            MOVE              X:(R3)+,A               ; Clock driver board number
1808      P:00052D P:00052D 0614A0            REP     #20
1809      P:00052E P:00052E 200033            LSL     A
1810      P:00052F P:00052F 44F400            MOVE              #$001000,X0             ; Bits to select MUX on ARC32 board
                            001000
1811      P:000531 P:000531 200042            OR      X0,A
1812      P:000532 P:000532 000000            NOP
1813      P:000533 P:000533 218500            MOVE              A1,X1                   ; Move here for later use
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 34



1814   
1815                                ; Get the first MUX number
1816      P:000534 P:000534 56DB00            MOVE              X:(R3)+,A               ; Get the first MUX number
1817      P:000535 P:000535 200003            TST     A
1818      P:000536 P:000536 0E957B            JLT     <ERR_SM1
1819      P:000537 P:000537 44F400            MOVE              #>24,X0                 ; Check for argument less than 32
                            000018
1820      P:000539 P:000539 200045            CMP     X0,A
1821      P:00053A P:00053A 0E157B            JGE     <ERR_SM1
1822      P:00053B P:00053B 21CF00            MOVE              A,B
1823      P:00053C P:00053C 44F400            MOVE              #>7,X0
                            000007
1824      P:00053E P:00053E 20004E            AND     X0,B
1825      P:00053F P:00053F 44F400            MOVE              #>$18,X0
                            000018
1826      P:000541 P:000541 200046            AND     X0,A
1827      P:000542 P:000542 0E2545            JNE     <SMX_1                            ; Test for 0 <= MUX number <= 7
1828      P:000543 P:000543 0ACD63            BSET    #3,B1
1829      P:000544 P:000544 0C0550            JMP     <SMX_A
1830      P:000545 P:000545 44F400  SMX_1     MOVE              #>$08,X0
                            000008
1831      P:000547 P:000547 200045            CMP     X0,A                              ; Test for 8 <= MUX number <= 15
1832      P:000548 P:000548 0E254B            JNE     <SMX_2
1833      P:000549 P:000549 0ACD64            BSET    #4,B1
1834      P:00054A P:00054A 0C0550            JMP     <SMX_A
1835      P:00054B P:00054B 44F400  SMX_2     MOVE              #>$10,X0
                            000010
1836      P:00054D P:00054D 200045            CMP     X0,A                              ; Test for 16 <= MUX number <= 23
1837      P:00054E P:00054E 0E257B            JNE     <ERR_SM1
1838      P:00054F P:00054F 0ACD65            BSET    #5,B1
1839      P:000550 P:000550 20006A  SMX_A     OR      X1,B1                             ; Add prefix to MUX numbers
1840      P:000551 P:000551 000000            NOP
1841      P:000552 P:000552 21A700            MOVE              B1,Y1
1842   
1843                                ; Add on the second MUX number
1844      P:000553 P:000553 56DB00            MOVE              X:(R3)+,A               ; Get the next MUX number
1845      P:000554 P:000554 200003            TST     A
1846      P:000555 P:000555 0E957C            JLT     <ERR_SM2
1847      P:000556 P:000556 44F400            MOVE              #>24,X0                 ; Check for argument less than 32
                            000018
1848      P:000558 P:000558 200045            CMP     X0,A
1849      P:000559 P:000559 0E157C            JGE     <ERR_SM2
1850      P:00055A P:00055A 0606A0            REP     #6
1851      P:00055B P:00055B 200033            LSL     A
1852      P:00055C P:00055C 000000            NOP
1853      P:00055D P:00055D 21CF00            MOVE              A,B
1854      P:00055E P:00055E 44F400            MOVE              #$1C0,X0
                            0001C0
1855      P:000560 P:000560 20004E            AND     X0,B
1856      P:000561 P:000561 44F400            MOVE              #>$600,X0
                            000600
1857      P:000563 P:000563 200046            AND     X0,A
1858      P:000564 P:000564 0E2567            JNE     <SMX_3                            ; Test for 0 <= MUX number <= 7
1859      P:000565 P:000565 0ACD69            BSET    #9,B1
1860      P:000566 P:000566 0C0572            JMP     <SMX_B
1861      P:000567 P:000567 44F400  SMX_3     MOVE              #>$200,X0
                            000200
1862      P:000569 P:000569 200045            CMP     X0,A                              ; Test for 8 <= MUX number <= 15
1863      P:00056A P:00056A 0E256D            JNE     <SMX_4
1864      P:00056B P:00056B 0ACD6A            BSET    #10,B1
1865      P:00056C P:00056C 0C0572            JMP     <SMX_B
1866      P:00056D P:00056D 44F400  SMX_4     MOVE              #>$400,X0
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 35



                            000400
1867      P:00056F P:00056F 200045            CMP     X0,A                              ; Test for 16 <= MUX number <= 23
1868      P:000570 P:000570 0E257C            JNE     <ERR_SM2
1869      P:000571 P:000571 0ACD6B            BSET    #11,B1
1870      P:000572 P:000572 200078  SMX_B     ADD     Y1,B                              ; Add prefix to MUX numbers
1871      P:000573 P:000573 000000            NOP
1872      P:000574 P:000574 21AE00            MOVE              B1,A
1873      P:000575 P:000575 0140C6            AND     #$F01FFF,A                        ; Just to be sure
                            F01FFF
1874      P:000577 P:000577 0D020C            JSR     <XMIT_A_WORD                      ; Transmit A to TIM-A-STD
1875      P:000578 P:000578 0D0417            JSR     <PAL_DLY                          ; Delay for all this to happen
1876      P:000579 P:000579 012F03            BCLR    #3,X:PCRD                         ; Turn the serial clock off
1877      P:00057A P:00057A 0C008F            JMP     <FINISH
1878      P:00057B P:00057B 56DB00  ERR_SM1   MOVE              X:(R3)+,A               ; Throw off the last argument
1879      P:00057C P:00057C 012F03  ERR_SM2   BCLR    #3,X:PCRD                         ; Turn the serial clock off
1880      P:00057D P:00057D 0C008D            JMP     <ERROR
1881   
1882                                ; Specify subarray readout coordinates, one rectangle only
1883                                SET_SUBARRAY_SIZES
1884      P:00057E P:00057E 200013            CLR     A
1885      P:00057F P:00057F 000000            NOP
1886      P:000580 P:000580 5E2300            MOVE                          A,Y:<NBOXES ; Number of subimage boxes = 0 to start
1887      P:000581 P:000581 44DB00            MOVE              X:(R3)+,X0
1888      P:000582 P:000582 4C1D00            MOVE                          X0,Y:<NR_BIAS ; Number of bias pixels to read
1889      P:000583 P:000583 44DB00            MOVE              X:(R3)+,X0
1890      P:000584 P:000584 4C1E00            MOVE                          X0,Y:<NS_READ ; Number of columns in subimage read
1891      P:000585 P:000585 44DB00            MOVE              X:(R3)+,X0
1892      P:000586 P:000586 4C1F00            MOVE                          X0,Y:<NP_READ ; Number of rows in subimage read
1893      P:000587 P:000587 0A0010            BCLR    #ST_SA,X:STATUS                   ; Not in subarray mode until 'SSP'
1894      P:000588 P:000588 0C008F            JMP     <FINISH                           ;   is executed
1895   
1896                                ; Call this routine once for every subarray to be added to the table
1897                                SET_SUBARRAY_POSITIONS
1898      P:000589 P:000589 5EA300            MOVE                          Y:<NBOXES,A
1899      P:00058A P:00058A 44F400            MOVE              #>10,X0
                            00000A
1900      P:00058C P:00058C 200045            CMP     X0,A
1901      P:00058D P:00058D 0E108D            JGE     <ERROR                            ; Error if number of boxes > 10
1902      P:00058E P:00058E 218400            MOVE              A1,X0
1903      P:00058F P:00058F 459400            MOVE              X:<THREE,X1
1904      P:000590 P:000590 2000A0            MPY     X0,X1,A
1905      P:000591 P:000591 200022            ASR     A
1906      P:000592 P:000592 210C00            MOVE              A0,A1
1907   
1908      P:000593 P:000593 44F400            MOVE              #READ_TABLE,X0
                            000024
1909      P:000595 P:000595 200040            ADD     X0,A
1910      P:000596 P:000596 000000            NOP
1911      P:000597 P:000597 219700            MOVE              A1,R7
1912      P:000598 P:000598 44DB00            MOVE              X:(R3)+,X0
1913      P:000599 P:000599 000000            NOP
1914      P:00059A P:00059A 000000            NOP
1915      P:00059B P:00059B 4C5F00            MOVE                          X0,Y:(R7)+  ; Number of rows (parallels) to clear
1916      P:00059C P:00059C 44DB00            MOVE              X:(R3)+,X0
1917      P:00059D P:00059D 4C5F00            MOVE                          X0,Y:(R7)+  ; Number of columns (serials) clears before
1918      P:00059E P:00059E 44DB00            MOVE              X:(R3)+,X0              ;  the box readout
1919      P:00059F P:00059F 4C5F00            MOVE                          X0,Y:(R7)+  ; Number of columns (serials) clears after
1920      P:0005A0 P:0005A0 5EA300            MOVE                          Y:<NBOXES,A
1921      P:0005A1 P:0005A1 449200            MOVE              X:<ONE,X0
1922      P:0005A2 P:0005A2 200040            ADD     X0,A
1923      P:0005A3 P:0005A3 000000            NOP
1924      P:0005A4 P:0005A4 5C2300            MOVE                          A1,Y:<NBOXES
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 36



1925      P:0005A5 P:0005A5 0A0030            BSET    #ST_SA,X:STATUS
1926      P:0005A6 P:0005A6 0C008F            JMP     <FINISH
1927   
1928                                ; Generate the serial readout waveform table for the chosen
1929                                ;   value of readout and serial binning.
1930   
1931                                GENERATE_SERIAL_WAVEFORM                            ; Generate the serial waveform table
1932      P:0005A7 P:0005A7 61F400            MOVE              #(PXL_TBL+1),R1
                            0001E3
1933      P:0005A9 P:0005A9 5E8500            MOVE                          Y:<NSBIN,A
1934      P:0005AA P:0005AA 014184            SUB     #1,A
1935      P:0005AB P:0005AB 0EF5B9            JLE     <NO_BIN
1936      P:0005AC P:0005AC 06CC00            DO      A1,L_BIN
                            0005B8
1937      P:0005AE P:0005AE 68F000            MOVE                          Y:CLOCK_LINE,R0
                            000014
1938      P:0005B0 P:0005B0 000000            NOP
1939      P:0005B1 P:0005B1 000000            NOP
1940      P:0005B2 P:0005B2 5ED800            MOVE                          Y:(R0)+,A
1941      P:0005B3 P:0005B3 000000            NOP
1942      P:0005B4 P:0005B4 06CC00            DO      A1,L_CLOCK_LINE
                            0005B7
1943      P:0005B6 P:0005B6 4CD800            MOVE                          Y:(R0)+,X0
1944      P:0005B7 P:0005B7 4C5900            MOVE                          X0,Y:(R1)+
1945                                L_CLOCK_LINE
1946      P:0005B8 P:0005B8 000000            NOP
1947                                L_BIN
1948   
1949                                ; Generate the rest of the waveform table
1950      P:0005B9 P:0005B9 689500  NO_BIN    MOVE                          Y:<SERIAL_READ,R0
1951      P:0005BA P:0005BA 000000            NOP
1952      P:0005BB P:0005BB 000000            NOP
1953      P:0005BC P:0005BC 000000            NOP
1954      P:0005BD P:0005BD 5ED800            MOVE                          Y:(R0)+,A
1955      P:0005BE P:0005BE 000000            NOP
1956      P:0005BF P:0005BF 06CC00            DO      A1,L_RD
                            0005C3
1957      P:0005C1 P:0005C1 4CD800            MOVE                          Y:(R0)+,X0
1958      P:0005C2 P:0005C2 0D05CD            JSR     <SEARCH_FOR_SXMIT
1959      P:0005C3 P:0005C3 4C5900            MOVE                          X0,Y:(R1)+
1960                                L_RD
1961   
1962                                ; Finally, calculate the number of entries in the waveform table just generated
1963      P:0005C4 P:0005C4 44F400            MOVE              #PXL_TBL,X0
                            0001E2
1964      P:0005C6 P:0005C6 209000            MOVE              X0,R0
1965      P:0005C7 P:0005C7 222E00            MOVE              R1,A
1966      P:0005C8 P:0005C8 200044            SUB     X0,A
1967      P:0005C9 P:0005C9 014184            SUB     #1,A
1968      P:0005CA P:0005CA 000000            NOP
1969      P:0005CB P:0005CB 5C6000            MOVE                          A1,Y:(R0)
1970      P:0005CC P:0005CC 00000C            RTS
1971   
1972                                ; Search for SXMIT in the PXL_TBL for use in processing the PRESCAN columns
1973                                SEARCH_FOR_SXMIT
1974      P:0005CD P:0005CD 208E00            MOVE              X0,A
1975      P:0005CE P:0005CE 0140C6            AND     #$00F000,A
                            00F000
1976      P:0005D0 P:0005D0 0140C5            CMP     #$00F000,A
                            00F000
1977      P:0005D2 P:0005D2 0E25D4            JNE     <NOT_SX
1978      P:0005D3 P:0005D3 690A00            MOVE                          R1,Y:<SXMIT_ADR
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 37



1979      P:0005D4 P:0005D4 00000C  NOT_SX    RTS
1980   
1981                                ; Select the amplifier and readout mode
1982                                ;   'SOS'  Amplifier_name = '__C', '__D', '__B', '__A' or 'ALL'
1983                                ;                        or 0 (LL), 1 (LR), 2 (UR) or 3 (UL)
1984                                ;                        or '_LL', '_LR', '_UR' or '_UL'
1985   
1986                                SELECT_OUTPUT_SOURCE
1987      P:0005D5 P:0005D5 46DB00            MOVE              X:(R3)+,Y0
1988      P:0005D6 P:0005D6 4E0800            MOVE                          Y0,Y:<OS
1989      P:0005D7 P:0005D7 012F23            BSET    #3,X:PCRD                         ; Turn on the serial clock
1990      P:0005D8 P:0005D8 0D0417            JSR     <PAL_DLY                          ; Delay for all this to happen
1991      P:0005D9 P:0005D9 0D05DD            JSR     <SEL_OS
1992      P:0005DA P:0005DA 0D0417            JSR     <PAL_DLY
1993      P:0005DB P:0005DB 012F03            BCLR    #3,X:PCRD                         ; Turn off the serial clock
1994      P:0005DC P:0005DC 0C008F            JMP     <FINISH
1995   
1996                                SEL_OS
1997                                ;       MOVE    #DC_DEFAULT,R0                  ; See DC_CH2 below
1998                                ;       JSR     <WR_DACS
1999      P:0005DD P:0005DD 5E8800            MOVE                          Y:<OS,A
2000      P:0005DE P:0005DE 0140C5            CMP     #'ALL',A                          ; All Amplifiers = readout #0 to #3
                            414C4C
2001      P:0005E0 P:0005E0 0E2670            JNE     <CMP_LL
2002   
2003      P:0005E1 P:0005E1 44F400            MOVE              #PARALLEL_SPLIT,X0
                            00006A
2004      P:0005E3 P:0005E3 4C7000            MOVE                          X0,Y:PARALLEL
                            000013
2005      P:0005E5 P:0005E5 44F400            MOVE              #EXPOSE_SPLIT,X0
                            00007B
2006      P:0005E7 P:0005E7 4C1800            MOVE                          X0,Y:<EXPOSE_PARALLELS
2007   
2008      P:0005E8 P:0005E8 44F400            MOVE              #SERIAL_SKIP_SPLIT,X0
                            0000A7
2009      P:0005EA P:0005EA 4C7000            MOVE                          X0,Y:SERIAL_SKIP
                            000016
2010      P:0005EC P:0005EC 44F400            MOVE              #CLOCK_LINE_SPLIT,X0
                            000176
2011      P:0005EE P:0005EE 4C7000            MOVE                          X0,Y:CLOCK_LINE
                            000014
2012      P:0005F0 P:0005F0 44F400            MOVE              #$00F0C0,X0
                            00F0C0
2013      P:0005F2 P:0005F2 4C7000            MOVE                          X0,Y:SXMIT
                            000009
2014      P:0005F4 P:0005F4 0A0025            BSET    #SPLIT_S,X:STATUS
2015      P:0005F5 P:0005F5 0A0026            BSET    #SPLIT_P,X:STATUS
2016      P:0005F6 P:0005F6 5E9000            MOVE                          Y:<PXL_SPEED,A
2017      P:0005F7 P:0005F7 0140C5            CMP     #'FST',A                          ; Fast reaout, ~1 MHz
                            465354
2018      P:0005F9 P:0005F9 0E2620            JNE     <CMP_MEDIUM_SPLIT
2019      P:0005FA P:0005FA 44F400            MOVE              #SERIAL_READ_SPLIT_FAST,X0
                            000144
2020      P:0005FC P:0005FC 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2021      P:0005FE P:0005FE 44F400            MOVE              #SXMIT_SPLIT_FAST,X0
                            000148
2022      P:000600 P:000600 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2023      P:000601 P:000601 56F400            MOVE              #GAIN_FAST,A
                            0D0005
2024      P:000603 P:000603 0D020C            JSR     <XMIT_A_WORD
2025      P:000604 P:000604 56F400            MOVE              #TIME_CONSTANT_FAST,A
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 38



                            0C0180
2026      P:000606 P:000606 0D020C            JSR     <XMIT_A_WORD
2027   
2028      P:000607 P:000607 56F400            MOVE              #DAC_ADDR+$000014,A
                            0E0014
2029      P:000609 P:000609 0D020C            JSR     <XMIT_A_WORD
2030      P:00060A P:00060A 56F400            MOVE              #DAC_RegD+OFFSET_LL_FAST,A
                            0FEE2F
2031      P:00060C P:00060C 0D020C            JSR     <XMIT_A_WORD
2032      P:00060D P:00060D 56F400            MOVE              #DAC_ADDR+$000015,A
                            0E0015
2033      P:00060F P:00060F 0D020C            JSR     <XMIT_A_WORD
2034      P:000610 P:000610 56F400            MOVE              #DAC_RegD+OFFSET_LR_FAST,A
                            0FEEC0
2035      P:000612 P:000612 0D020C            JSR     <XMIT_A_WORD
2036      P:000613 P:000613 56F400            MOVE              #DAC_ADDR+$000016,A
                            0E0016
2037      P:000615 P:000615 0D020C            JSR     <XMIT_A_WORD
2038      P:000616 P:000616 56F400            MOVE              #DAC_RegD+OFFSET_UR_FAST,A
                            0FEECB
2039      P:000618 P:000618 0D020C            JSR     <XMIT_A_WORD
2040      P:000619 P:000619 56F400            MOVE              #DAC_ADDR+$000017,A
                            0E0017
2041      P:00061B P:00061B 0D020C            JSR     <XMIT_A_WORD
2042      P:00061C P:00061C 56F400            MOVE              #DAC_RegD+OFFSET_UL_FAST,A
                            0FEDDA
2043      P:00061E P:00061E 0D020C            JSR     <XMIT_A_WORD
2044      P:00061F P:00061F 00000C            RTS
2045   
2046                                CMP_MEDIUM_SPLIT
2047      P:000620 P:000620 5E9000            MOVE                          Y:<PXL_SPEED,A
2048      P:000621 P:000621 0140C5            CMP     #'MED',A                          ; Value for medium readout, 400 kHz
                            4D4544
2049      P:000623 P:000623 0E264A            JNE     <SLOW_SPLIT
2050      P:000624 P:000624 44F400            MOVE              #SERIAL_READ_SPLIT_MED,X0
                            000131
2051      P:000626 P:000626 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2052      P:000628 P:000628 44F400            MOVE              #SXMIT_SPLIT_MED,X0
                            000139
2053      P:00062A P:00062A 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2054      P:00062B P:00062B 56F400            MOVE              #GAIN_MED,A
                            0D0006
2055      P:00062D P:00062D 0D020C            JSR     <XMIT_A_WORD
2056      P:00062E P:00062E 56F400            MOVE              #TIME_CONSTANT_MED,A
                            0C0140
2057      P:000630 P:000630 0D020C            JSR     <XMIT_A_WORD
2058      P:000631 P:000631 56F400            MOVE              #DAC_ADDR+$000014,A
                            0E0014
2059      P:000633 P:000633 0D020C            JSR     <XMIT_A_WORD
2060      P:000634 P:000634 56F400            MOVE              #DAC_RegD+OFFSET_LL_MED,A
                            0FE63C
2061      P:000636 P:000636 0D020C            JSR     <XMIT_A_WORD
2062      P:000637 P:000637 56F400            MOVE              #DAC_ADDR+$000015,A
                            0E0015
2063      P:000639 P:000639 0D020C            JSR     <XMIT_A_WORD
2064      P:00063A P:00063A 56F400            MOVE              #DAC_RegD+OFFSET_LR_MED,A
                            0FE5A0
2065      P:00063C P:00063C 0D020C            JSR     <XMIT_A_WORD
2066      P:00063D P:00063D 56F400            MOVE              #DAC_ADDR+$000016,A
                            0E0016
2067      P:00063F P:00063F 0D020C            JSR     <XMIT_A_WORD
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 39



2068      P:000640 P:000640 56F400            MOVE              #DAC_RegD+OFFSET_UR_MED,A
                            0FE72C
2069      P:000642 P:000642 0D020C            JSR     <XMIT_A_WORD
2070      P:000643 P:000643 56F400            MOVE              #DAC_ADDR+$000017,A
                            0E0017
2071      P:000645 P:000645 0D020C            JSR     <XMIT_A_WORD
2072      P:000646 P:000646 56F400            MOVE              #DAC_RegD+OFFSET_UL_MED,A
                            0FE53B
2073      P:000648 P:000648 0D020C            JSR     <XMIT_A_WORD
2074   
2075      P:000649 P:000649 00000C            RTS
2076   
2077                                SLOW_SPLIT                                          ; Value for slow readout, 100 kHz
2078      P:00064A P:00064A 44F400            MOVE              #SERIAL_READ_SPLIT_SLOW,X0
                            00011E
2079      P:00064C P:00064C 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2080      P:00064E P:00064E 44F400            MOVE              #SXMIT_SPLIT_SLOW,X0
                            000126
2081      P:000650 P:000650 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2082      P:000651 P:000651 56F400            MOVE              #GAIN_SLOW,A
                            0D0003
2083      P:000653 P:000653 0D020C            JSR     <XMIT_A_WORD
2084      P:000654 P:000654 56F400            MOVE              #TIME_CONSTANT_SLOW,A
                            0C0130
2085      P:000656 P:000656 0D020C            JSR     <XMIT_A_WORD
2086      P:000657 P:000657 56F400            MOVE              #DAC_ADDR+$000014,A
                            0E0014
2087      P:000659 P:000659 0D020C            JSR     <XMIT_A_WORD
2088      P:00065A P:00065A 56F400            MOVE              #DAC_RegD+OFFSET_LL_SLOW,A
                            0FE8FC
2089      P:00065C P:00065C 0D020C            JSR     <XMIT_A_WORD
2090      P:00065D P:00065D 56F400            MOVE              #DAC_ADDR+$000015,A
                            0E0015
2091      P:00065F P:00065F 0D020C            JSR     <XMIT_A_WORD
2092      P:000660 P:000660 56F400            MOVE              #DAC_RegD+OFFSET_LR_SLOW,A
                            0FE854
2093      P:000662 P:000662 0D020C            JSR     <XMIT_A_WORD
2094      P:000663 P:000663 56F400            MOVE              #DAC_ADDR+$000016,A
                            0E0016
2095      P:000665 P:000665 0D020C            JSR     <XMIT_A_WORD
2096      P:000666 P:000666 56F400            MOVE              #DAC_RegD+OFFSET_UR_SLOW,A
                            0FE98E
2097      P:000668 P:000668 0D020C            JSR     <XMIT_A_WORD
2098      P:000669 P:000669 56F400            MOVE              #DAC_ADDR+$000017,A
                            0E0017
2099      P:00066B P:00066B 0D020C            JSR     <XMIT_A_WORD
2100      P:00066C P:00066C 56F400            MOVE              #DAC_RegD+OFFSET_UL_SLOW,A
                            0FE804
2101      P:00066E P:00066E 0D020C            JSR     <XMIT_A_WORD
2102   
2103      P:00066F P:00066F 00000C            RTS
2104   
2105      P:000670 P:000670 5E8800  CMP_LL    MOVE                          Y:<OS,A     ; Lower left readout, #0
2106      P:000671 P:000671 0140C5            CMP     #'__C',A
                            5F5F43
2107      P:000673 P:000673 0EA679            JEQ     <EQ_LL
2108      P:000674 P:000674 0140C5            CMP     #'_LL',A
                            5F4C4C
2109      P:000676 P:000676 0EA679            JEQ     <EQ_LL
2110      P:000677 P:000677 014085            CMP     #0,A
2111      P:000678 P:000678 0E26D8            JNE     <CMP_LR
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 40



2112      P:000679 P:000679 44F400  EQ_LL     MOVE              #PARALLEL_DOWN_LEFT,X0
                            000056
2113      P:00067B P:00067B 4C7000            MOVE                          X0,Y:PARALLEL
                            000013
2114      P:00067D P:00067D 44F400            MOVE              #EXPOSE_DOWN,X0
                            000078
2115      P:00067F P:00067F 4C1800            MOVE                          X0,Y:<EXPOSE_PARALLELS
2116   
2117      P:000680 P:000680 44F400            MOVE              #SERIAL_SKIP_LEFT,X0
                            000099
2118      P:000682 P:000682 4C7000            MOVE                          X0,Y:SERIAL_SKIP
                            000016
2119      P:000684 P:000684 44F400            MOVE              #CLOCK_LINE_LEFT,X0
                            000168
2120      P:000686 P:000686 4C7000            MOVE                          X0,Y:CLOCK_LINE
                            000014
2121      P:000688 P:000688 44F400            MOVE              #$00F000,X0
                            00F000
2122      P:00068A P:00068A 4C7000            MOVE                          X0,Y:SXMIT
                            000009
2123      P:00068C P:00068C 4C7000            MOVE                          X0,Y:SXMIT_LEFT_SLOW
                            0000B6
2124      P:00068E P:00068E 4C7000            MOVE                          X0,Y:SXMIT_LEFT_MED
                            0000C9
2125      P:000690 P:000690 4C7000            MOVE                          X0,Y:SXMIT_LEFT_FAST
                            0000D8
2126   
2127      P:000692 P:000692 0A0005            BCLR    #SPLIT_S,X:STATUS
2128      P:000693 P:000693 0A0006            BCLR    #SPLIT_P,X:STATUS
2129   
2130      P:000694 P:000694 5E9000            MOVE                          Y:<PXL_SPEED,A
2131      P:000695 P:000695 0140C5            CMP     #'FST',A
                            465354
2132      P:000697 P:000697 0E26AC            JNE     <CMP_MEDIUM_LL
2133      P:000698 P:000698 44F400            MOVE              #SERIAL_READ_LEFT_FAST,X0
                            0000D4
2134      P:00069A P:00069A 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2135      P:00069C P:00069C 44F400            MOVE              #SXMIT_LEFT_FAST,X0
                            0000D8
2136      P:00069E P:00069E 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2137      P:00069F P:00069F 56F400            MOVE              #GAIN_FAST,A
                            0D0005
2138      P:0006A1 P:0006A1 0D020C            JSR     <XMIT_A_WORD
2139      P:0006A2 P:0006A2 56F400            MOVE              #TIME_CONSTANT_FAST,A
                            0C0180
2140      P:0006A4 P:0006A4 0D020C            JSR     <XMIT_A_WORD
2141      P:0006A5 P:0006A5 56F400            MOVE              #DAC_ADDR+$000014,A
                            0E0014
2142      P:0006A7 P:0006A7 0D020C            JSR     <XMIT_A_WORD
2143      P:0006A8 P:0006A8 56F400            MOVE              #DAC_RegD+OFFSET_LL_FAST,A
                            0FEE2F
2144      P:0006AA P:0006AA 0D020C            JSR     <XMIT_A_WORD
2145      P:0006AB P:0006AB 00000C            RTS
2146   
2147                                CMP_MEDIUM_LL
2148      P:0006AC P:0006AC 5E9000            MOVE                          Y:<PXL_SPEED,A
2149      P:0006AD P:0006AD 0140C5            CMP     #'MED',A
                            4D4544
2150      P:0006AF P:0006AF 0E26C4            JNE     <SLOW_LL
2151      P:0006B0 P:0006B0 44F400            MOVE              #SERIAL_READ_LEFT_MED,X0
                            0000C1
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 41



2152      P:0006B2 P:0006B2 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2153      P:0006B4 P:0006B4 44F400            MOVE              #SXMIT_LEFT_MED,X0
                            0000C9
2154      P:0006B6 P:0006B6 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2155      P:0006B7 P:0006B7 56F400            MOVE              #GAIN_MED,A
                            0D0006
2156      P:0006B9 P:0006B9 0D020C            JSR     <XMIT_A_WORD
2157      P:0006BA P:0006BA 56F400            MOVE              #TIME_CONSTANT_MED,A
                            0C0140
2158      P:0006BC P:0006BC 0D020C            JSR     <XMIT_A_WORD
2159      P:0006BD P:0006BD 56F400            MOVE              #DAC_ADDR+$000014,A
                            0E0014
2160      P:0006BF P:0006BF 0D020C            JSR     <XMIT_A_WORD
2161      P:0006C0 P:0006C0 56F400            MOVE              #DAC_RegD+OFFSET_LL_MED,A
                            0FE63C
2162      P:0006C2 P:0006C2 0D020C            JSR     <XMIT_A_WORD
2163      P:0006C3 P:0006C3 00000C            RTS
2164   
2165      P:0006C4 P:0006C4 44F400  SLOW_LL   MOVE              #SERIAL_READ_LEFT_SLOW,X0
                            0000AE
2166      P:0006C6 P:0006C6 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2167      P:0006C8 P:0006C8 44F400            MOVE              #SXMIT_LEFT_SLOW,X0
                            0000B6
2168      P:0006CA P:0006CA 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2169      P:0006CB P:0006CB 56F400            MOVE              #GAIN_SLOW,A
                            0D0003
2170      P:0006CD P:0006CD 0D020C            JSR     <XMIT_A_WORD
2171      P:0006CE P:0006CE 56F400            MOVE              #TIME_CONSTANT_SLOW,A
                            0C0130
2172      P:0006D0 P:0006D0 0D020C            JSR     <XMIT_A_WORD
2173      P:0006D1 P:0006D1 56F400            MOVE              #DAC_ADDR+$000014,A
                            0E0014
2174      P:0006D3 P:0006D3 0D020C            JSR     <XMIT_A_WORD
2175      P:0006D4 P:0006D4 56F400            MOVE              #DAC_RegD+OFFSET_LL_SLOW,A
                            0FE8FC
2176      P:0006D6 P:0006D6 0D020C            JSR     <XMIT_A_WORD
2177      P:0006D7 P:0006D7 00000C            RTS
2178   
2179      P:0006D8 P:0006D8 5E8800  CMP_LR    MOVE                          Y:<OS,A     ; Lower right readout, #1
2180      P:0006D9 P:0006D9 0140C5            CMP     #'__D',A
                            5F5F44
2181      P:0006DB P:0006DB 0EA6E1            JEQ     <EQ_LR
2182      P:0006DC P:0006DC 0140C5            CMP     #'_LR',A
                            5F4C52
2183      P:0006DE P:0006DE 0EA6E1            JEQ     <EQ_LR
2184      P:0006DF P:0006DF 014185            CMP     #1,A
2185      P:0006E0 P:0006E0 0E2740            JNE     <CMP_UR
2186      P:0006E1 P:0006E1 44F400  EQ_LR     MOVE              #PARALLEL_DOWN_RIGHT,X0
                            000060
2187      P:0006E3 P:0006E3 4C7000            MOVE                          X0,Y:PARALLEL
                            000013
2188      P:0006E5 P:0006E5 44F400            MOVE              #EXPOSE_DOWN,X0
                            000078
2189      P:0006E7 P:0006E7 4C1800            MOVE                          X0,Y:<EXPOSE_PARALLELS
2190   
2191      P:0006E8 P:0006E8 44F400            MOVE              #SERIAL_SKIP_RIGHT,X0
                            0000A0
2192      P:0006EA P:0006EA 4C7000            MOVE                          X0,Y:SERIAL_SKIP
                            000016
2193      P:0006EC P:0006EC 44F400            MOVE              #CLOCK_LINE_RIGHT,X0
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 42



                            00016F
2194      P:0006EE P:0006EE 4C7000            MOVE                          X0,Y:CLOCK_LINE
                            000014
2195      P:0006F0 P:0006F0 44F400            MOVE              #$00F041,X0
                            00F041
2196      P:0006F2 P:0006F2 4C7000            MOVE                          X0,Y:SXMIT
                            000009
2197      P:0006F4 P:0006F4 4C7000            MOVE                          X0,Y:SXMIT_RIGHT_FAST
                            000110
2198      P:0006F6 P:0006F6 4C7000            MOVE                          X0,Y:SXMIT_RIGHT_MED
                            000101
2199      P:0006F8 P:0006F8 4C7000            MOVE                          X0,Y:SXMIT_RIGHT_SLOW
                            0000EE
2200   
2201      P:0006FA P:0006FA 0A0005            BCLR    #SPLIT_S,X:STATUS
2202      P:0006FB P:0006FB 0A0006            BCLR    #SPLIT_P,X:STATUS
2203   
2204      P:0006FC P:0006FC 5E9000            MOVE                          Y:<PXL_SPEED,A
2205      P:0006FD P:0006FD 0140C5            CMP     #'FST',A
                            465354
2206      P:0006FF P:0006FF 0E2714            JNE     <CMP_MEDIUM_LR
2207      P:000700 P:000700 44F400            MOVE              #SERIAL_READ_RIGHT_FAST,X0
                            00010C
2208      P:000702 P:000702 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2209      P:000704 P:000704 44F400            MOVE              #SXMIT_RIGHT_FAST,X0
                            000110
2210      P:000706 P:000706 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2211      P:000707 P:000707 56F400            MOVE              #GAIN_FAST,A
                            0D0005
2212      P:000709 P:000709 0D020C            JSR     <XMIT_A_WORD
2213      P:00070A P:00070A 56F400            MOVE              #TIME_CONSTANT_FAST,A
                            0C0180
2214      P:00070C P:00070C 0D020C            JSR     <XMIT_A_WORD
2215      P:00070D P:00070D 56F400            MOVE              #DAC_ADDR+$000015,A
                            0E0015
2216      P:00070F P:00070F 0D020C            JSR     <XMIT_A_WORD
2217      P:000710 P:000710 56F400            MOVE              #DAC_RegD+OFFSET_LR_FAST,A
                            0FEEC0
2218      P:000712 P:000712 0D020C            JSR     <XMIT_A_WORD
2219      P:000713 P:000713 00000C            RTS
2220   
2221                                CMP_MEDIUM_LR
2222      P:000714 P:000714 5E9000            MOVE                          Y:<PXL_SPEED,A
2223      P:000715 P:000715 0140C5            CMP     #'MED',A
                            4D4544
2224      P:000717 P:000717 0E272C            JNE     <SLOW_LR
2225      P:000718 P:000718 44F400            MOVE              #SERIAL_READ_RIGHT_MED,X0
                            0000F9
2226      P:00071A P:00071A 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2227      P:00071C P:00071C 44F400            MOVE              #SXMIT_RIGHT_MED,X0
                            000101
2228      P:00071E P:00071E 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2229      P:00071F P:00071F 56F400            MOVE              #GAIN_MED,A
                            0D0006
2230      P:000721 P:000721 0D020C            JSR     <XMIT_A_WORD
2231      P:000722 P:000722 56F400            MOVE              #TIME_CONSTANT_MED,A
                            0C0140
2232      P:000724 P:000724 0D020C            JSR     <XMIT_A_WORD
2233      P:000725 P:000725 56F400            MOVE              #DAC_ADDR+$000015,A
                            0E0015
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 43



2234      P:000727 P:000727 0D020C            JSR     <XMIT_A_WORD
2235      P:000728 P:000728 56F400            MOVE              #DAC_RegD+OFFSET_LR_MED,A
                            0FE5A0
2236      P:00072A P:00072A 0D020C            JSR     <XMIT_A_WORD
2237      P:00072B P:00072B 00000C            RTS
2238   
2239      P:00072C P:00072C 44F400  SLOW_LR   MOVE              #SERIAL_READ_RIGHT_SLOW,X0
                            0000E6
2240      P:00072E P:00072E 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2241      P:000730 P:000730 44F400            MOVE              #SXMIT_RIGHT_SLOW,X0
                            0000EE
2242      P:000732 P:000732 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2243      P:000733 P:000733 56F400            MOVE              #GAIN_SLOW,A
                            0D0003
2244      P:000735 P:000735 0D020C            JSR     <XMIT_A_WORD
2245      P:000736 P:000736 56F400            MOVE              #TIME_CONSTANT_SLOW,A
                            0C0130
2246      P:000738 P:000738 0D020C            JSR     <XMIT_A_WORD
2247      P:000739 P:000739 56F400            MOVE              #DAC_ADDR+$000015,A
                            0E0015
2248      P:00073B P:00073B 0D020C            JSR     <XMIT_A_WORD
2249      P:00073C P:00073C 56F400            MOVE              #DAC_RegD+OFFSET_LR_SLOW,A
                            0FE854
2250      P:00073E P:00073E 0D020C            JSR     <XMIT_A_WORD
2251      P:00073F P:00073F 00000C            RTS
2252   
2253      P:000740 P:000740 5E8800  CMP_UR    MOVE                          Y:<OS,A     ; Upper right readout, #2
2254      P:000741 P:000741 0140C5            CMP     #'__B',A
                            5F5F42
2255      P:000743 P:000743 0EA749            JEQ     <EQ_UR
2256      P:000744 P:000744 0140C5            CMP     #'_UR',A
                            5F5552
2257      P:000746 P:000746 0EA749            JEQ     <EQ_UR
2258      P:000747 P:000747 014285            CMP     #2,A
2259      P:000748 P:000748 0E27A8            JNE     <CMP_UL
2260      P:000749 P:000749 44F400  EQ_UR     MOVE              #PARALLEL_UP_RIGHT,X0
                            00004C
2261      P:00074B P:00074B 4C7000            MOVE                          X0,Y:PARALLEL
                            000013
2262      P:00074D P:00074D 44F400            MOVE              #EXPOSE_UP,X0
                            000075
2263      P:00074F P:00074F 4C1800            MOVE                          X0,Y:<EXPOSE_PARALLELS
2264   
2265      P:000750 P:000750 44F400            MOVE              #SERIAL_SKIP_RIGHT,X0
                            0000A0
2266      P:000752 P:000752 4C7000            MOVE                          X0,Y:SERIAL_SKIP
                            000016
2267      P:000754 P:000754 44F400            MOVE              #CLOCK_LINE_RIGHT,X0
                            00016F
2268      P:000756 P:000756 4C7000            MOVE                          X0,Y:CLOCK_LINE
                            000014
2269      P:000758 P:000758 44F400            MOVE              #$00F082,X0
                            00F082
2270      P:00075A P:00075A 4C7000            MOVE                          X0,Y:SXMIT
                            000009
2271      P:00075C P:00075C 4C7000            MOVE                          X0,Y:SXMIT_RIGHT_FAST
                            000110
2272      P:00075E P:00075E 4C7000            MOVE                          X0,Y:SXMIT_RIGHT_MED
                            000101
2273      P:000760 P:000760 4C7000            MOVE                          X0,Y:SXMIT_RIGHT_SLOW
                            0000EE
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 44



2274                                ;       MOVE    #DC_CH2,R0                      ; Special serial low value for Channel 2
2275                                ;       JSR     <WR_DACS
2276      P:000762 P:000762 0A0005            BCLR    #SPLIT_S,X:STATUS
2277      P:000763 P:000763 0A0006            BCLR    #SPLIT_P,X:STATUS
2278   
2279      P:000764 P:000764 5E9000            MOVE                          Y:<PXL_SPEED,A
2280      P:000765 P:000765 0140C5            CMP     #'FST',A
                            465354
2281      P:000767 P:000767 0E277C            JNE     <CMP_MEDIUM_UR
2282      P:000768 P:000768 44F400            MOVE              #SERIAL_READ_RIGHT_FAST,X0
                            00010C
2283      P:00076A P:00076A 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2284      P:00076C P:00076C 44F400            MOVE              #SXMIT_RIGHT_FAST,X0
                            000110
2285      P:00076E P:00076E 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2286   
2287      P:00076F P:00076F 56F400            MOVE              #GAIN_FAST,A
                            0D0005
2288      P:000771 P:000771 0D020C            JSR     <XMIT_A_WORD
2289      P:000772 P:000772 56F400            MOVE              #TIME_CONSTANT_FAST,A
                            0C0180
2290      P:000774 P:000774 0D020C            JSR     <XMIT_A_WORD
2291   
2292      P:000775 P:000775 56F400            MOVE              #DAC_ADDR+$000016,A
                            0E0016
2293      P:000777 P:000777 0D020C            JSR     <XMIT_A_WORD
2294      P:000778 P:000778 56F400            MOVE              #DAC_RegD+OFFSET_UR_FAST,A
                            0FEECB
2295      P:00077A P:00077A 0D020C            JSR     <XMIT_A_WORD
2296      P:00077B P:00077B 00000C            RTS
2297   
2298                                CMP_MEDIUM_UR
2299      P:00077C P:00077C 5E9000            MOVE                          Y:<PXL_SPEED,A
2300      P:00077D P:00077D 0140C5            CMP     #'MED',A
                            4D4544
2301      P:00077F P:00077F 0E2794            JNE     <SLOW_UR
2302      P:000780 P:000780 44F400            MOVE              #SERIAL_READ_RIGHT_MED,X0
                            0000F9
2303      P:000782 P:000782 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2304      P:000784 P:000784 44F400            MOVE              #SXMIT_RIGHT_MED,X0
                            000101
2305      P:000786 P:000786 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2306      P:000787 P:000787 56F400            MOVE              #GAIN_MED,A
                            0D0006
2307      P:000789 P:000789 0D020C            JSR     <XMIT_A_WORD
2308      P:00078A P:00078A 56F400            MOVE              #TIME_CONSTANT_MED,A
                            0C0140
2309      P:00078C P:00078C 0D020C            JSR     <XMIT_A_WORD
2310      P:00078D P:00078D 56F400            MOVE              #DAC_ADDR+$000016,A
                            0E0016
2311      P:00078F P:00078F 0D020C            JSR     <XMIT_A_WORD
2312      P:000790 P:000790 56F400            MOVE              #DAC_RegD+OFFSET_UR_MED,A
                            0FE72C
2313      P:000792 P:000792 0D020C            JSR     <XMIT_A_WORD
2314      P:000793 P:000793 00000C            RTS
2315   
2316      P:000794 P:000794 44F400  SLOW_UR   MOVE              #SERIAL_READ_RIGHT_SLOW,X0
                            0000E6
2317      P:000796 P:000796 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 45



2318      P:000798 P:000798 44F400            MOVE              #SXMIT_RIGHT_SLOW,X0
                            0000EE
2319      P:00079A P:00079A 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2320      P:00079B P:00079B 56F400            MOVE              #GAIN_SLOW,A
                            0D0003
2321      P:00079D P:00079D 0D020C            JSR     <XMIT_A_WORD
2322      P:00079E P:00079E 56F400            MOVE              #TIME_CONSTANT_SLOW,A
                            0C0130
2323      P:0007A0 P:0007A0 0D020C            JSR     <XMIT_A_WORD
2324      P:0007A1 P:0007A1 56F400            MOVE              #DAC_ADDR+$000016,A
                            0E0016
2325      P:0007A3 P:0007A3 0D020C            JSR     <XMIT_A_WORD
2326      P:0007A4 P:0007A4 56F400            MOVE              #DAC_RegD+OFFSET_UR_SLOW,A
                            0FE98E
2327      P:0007A6 P:0007A6 0D020C            JSR     <XMIT_A_WORD
2328      P:0007A7 P:0007A7 00000C            RTS
2329   
2330      P:0007A8 P:0007A8 5E8800  CMP_UL    MOVE                          Y:<OS,A     ; Upper left readout, #3
2331      P:0007A9 P:0007A9 0140C5            CMP     #'__A',A
                            5F5F41
2332      P:0007AB P:0007AB 0EA7B1            JEQ     <EQ_UL
2333      P:0007AC P:0007AC 0140C5            CMP     #'_UL',A
                            5F554C
2334      P:0007AE P:0007AE 0EA7B1            JEQ     <EQ_UL
2335      P:0007AF P:0007AF 014385            CMP     #3,A
2336      P:0007B0 P:0007B0 0E208D            JNE     <ERROR
2337      P:0007B1 P:0007B1 44F400  EQ_UL     MOVE              #PARALLEL_UP_LEFT,X0
                            000042
2338      P:0007B3 P:0007B3 4C7000            MOVE                          X0,Y:PARALLEL
                            000013
2339      P:0007B5 P:0007B5 44F400            MOVE              #EXPOSE_UP,X0
                            000075
2340      P:0007B7 P:0007B7 4C1800            MOVE                          X0,Y:<EXPOSE_PARALLELS
2341   
2342      P:0007B8 P:0007B8 44F400            MOVE              #SERIAL_SKIP_LEFT,X0
                            000099
2343      P:0007BA P:0007BA 4C7000            MOVE                          X0,Y:SERIAL_SKIP
                            000016
2344      P:0007BC P:0007BC 44F400            MOVE              #CLOCK_LINE_LEFT,X0
                            000168
2345      P:0007BE P:0007BE 4C7000            MOVE                          X0,Y:CLOCK_LINE
                            000014
2346      P:0007C0 P:0007C0 44F400            MOVE              #$00F0C3,X0
                            00F0C3
2347      P:0007C2 P:0007C2 4C7000            MOVE                          X0,Y:SXMIT
                            000009
2348      P:0007C4 P:0007C4 4C7000            MOVE                          X0,Y:SXMIT_LEFT_FAST
                            0000D8
2349      P:0007C6 P:0007C6 4C7000            MOVE                          X0,Y:SXMIT_LEFT_MED
                            0000C9
2350      P:0007C8 P:0007C8 4C7000            MOVE                          X0,Y:SXMIT_LEFT_SLOW
                            0000B6
2351      P:0007CA P:0007CA 0A0005            BCLR    #SPLIT_S,X:STATUS
2352      P:0007CB P:0007CB 0A0006            BCLR    #SPLIT_P,X:STATUS
2353   
2354      P:0007CC P:0007CC 5E9000            MOVE                          Y:<PXL_SPEED,A
2355      P:0007CD P:0007CD 0140C5            CMP     #'FST',A
                            465354
2356      P:0007CF P:0007CF 0E27E4            JNE     <CMP_MEDIUM_UL
2357      P:0007D0 P:0007D0 44F400            MOVE              #SERIAL_READ_LEFT_FAST,X0
                            0000D4
2358      P:0007D2 P:0007D2 4C7000            MOVE                          X0,Y:SERIAL_READ
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 46



                            000015
2359      P:0007D4 P:0007D4 44F400            MOVE              #SXMIT_LEFT_FAST,X0
                            0000D8
2360      P:0007D6 P:0007D6 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2361      P:0007D7 P:0007D7 56F400            MOVE              #GAIN_FAST,A
                            0D0005
2362      P:0007D9 P:0007D9 0D020C            JSR     <XMIT_A_WORD
2363      P:0007DA P:0007DA 56F400            MOVE              #TIME_CONSTANT_FAST,A
                            0C0180
2364      P:0007DC P:0007DC 0D020C            JSR     <XMIT_A_WORD
2365      P:0007DD P:0007DD 56F400            MOVE              #DAC_ADDR+$000017,A
                            0E0017
2366      P:0007DF P:0007DF 0D020C            JSR     <XMIT_A_WORD
2367      P:0007E0 P:0007E0 56F400            MOVE              #DAC_RegD+OFFSET_UL_FAST,A
                            0FEDDA
2368      P:0007E2 P:0007E2 0D020C            JSR     <XMIT_A_WORD
2369      P:0007E3 P:0007E3 00000C            RTS
2370   
2371                                CMP_MEDIUM_UL
2372      P:0007E4 P:0007E4 5E9000            MOVE                          Y:<PXL_SPEED,A
2373      P:0007E5 P:0007E5 0140C5            CMP     #'MED',A
                            4D4544
2374      P:0007E7 P:0007E7 0E27FC            JNE     <SLOW_UL
2375      P:0007E8 P:0007E8 44F400            MOVE              #SERIAL_READ_LEFT_MED,X0
                            0000C1
2376      P:0007EA P:0007EA 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2377      P:0007EC P:0007EC 44F400            MOVE              #SXMIT_LEFT_MED,X0
                            0000C9
2378      P:0007EE P:0007EE 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2379      P:0007EF P:0007EF 56F400            MOVE              #GAIN_MED,A
                            0D0006
2380      P:0007F1 P:0007F1 0D020C            JSR     <XMIT_A_WORD
2381      P:0007F2 P:0007F2 56F400            MOVE              #TIME_CONSTANT_MED,A
                            0C0140
2382      P:0007F4 P:0007F4 0D020C            JSR     <XMIT_A_WORD
2383      P:0007F5 P:0007F5 56F400            MOVE              #DAC_ADDR+$000017,A
                            0E0017
2384      P:0007F7 P:0007F7 0D020C            JSR     <XMIT_A_WORD
2385      P:0007F8 P:0007F8 56F400            MOVE              #DAC_RegD+OFFSET_UL_MED,A
                            0FE53B
2386      P:0007FA P:0007FA 0D020C            JSR     <XMIT_A_WORD
2387      P:0007FB P:0007FB 00000C            RTS
2388   
2389      P:0007FC P:0007FC 44F400  SLOW_UL   MOVE              #SERIAL_READ_LEFT_SLOW,X0
                            0000AE
2390      P:0007FE P:0007FE 4C7000            MOVE                          X0,Y:SERIAL_READ
                            000015
2391      P:000800 P:000800 44F400            MOVE              #SXMIT_LEFT_SLOW,X0
                            0000B6
2392      P:000802 P:000802 4C0B00            MOVE                          X0,Y:<ADR_SXMIT
2393      P:000803 P:000803 56F400            MOVE              #GAIN_SLOW,A
                            0D0003
2394      P:000805 P:000805 0D020C            JSR     <XMIT_A_WORD
2395      P:000806 P:000806 56F400            MOVE              #TIME_CONSTANT_SLOW,A
                            0C0130
2396      P:000808 P:000808 0D020C            JSR     <XMIT_A_WORD
2397      P:000809 P:000809 56F400            MOVE              #DAC_ADDR+$000017,A
                            0E0017
2398      P:00080B P:00080B 0D020C            JSR     <XMIT_A_WORD
2399      P:00080C P:00080C 56F400            MOVE              #DAC_RegD+OFFSET_UL_SLOW,A
                            0FE804
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 47



2400      P:00080E P:00080E 0D020C            JSR     <XMIT_A_WORD
2401      P:00080F P:00080F 00000C            RTS
2402   
2403                                SELECT_PIXEL_SPEED                                  ; 'SLW', 'MED' or 'FST'
2404      P:000810 P:000810 56DB00            MOVE              X:(R3)+,A
2405      P:000811 P:000811 0140C5            CMP     #'SLW',A
                            534C57
2406      P:000813 P:000813 0EA81B            JEQ     <SPS_END
2407      P:000814 P:000814 0140C5            CMP     #'MED',A
                            4D4544
2408      P:000816 P:000816 0EA81B            JEQ     <SPS_END
2409      P:000817 P:000817 0140C5            CMP     #'FST',A
                            465354
2410      P:000819 P:000819 0EA81B            JEQ     <SPS_END
2411      P:00081A P:00081A 0C008D            JMP     <ERROR
2412   
2413      P:00081B P:00081B 5C1000  SPS_END   MOVE                          A1,Y:<PXL_SPEED
2414      P:00081C P:00081C 012F23            BSET    #3,X:PCRD                         ; Turn on the serial clock
2415      P:00081D P:00081D 0D0417            JSR     <PAL_DLY                          ; Delay for all this to happen
2416      P:00081E P:00081E 0D05DD            JSR     <SEL_OS
2417      P:00081F P:00081F 0D0417            JSR     <PAL_DLY
2418      P:000820 P:000820 012F03            BCLR    #3,X:PCRD                         ; Turn off the serial clock
2419      P:000821 P:000821 0C008F            JMP     <FINISH
2420   
2421                                ; Move the image UP by the indicated number of lines
2422                                MOVE_PARALLEL_UP
2423      P:000822 P:000822 44DB00            MOVE              X:(R3)+,X0
2424      P:000823 P:000823 06C400            DO      X0,L_UP
                            00082A
2425      P:000825 P:000825 60F400            MOVE              #PARALLEL_UP_LEFT,R0
                            000042
2426                                          CLOCK
2430                                L_UP
2431   
2432                                ; Move the image DOWN by the indicated number of lines
2433                                MOVE_PARALLEL_DOWN
2434      P:00082B P:00082B 44DB00            MOVE              X:(R3)+,X0
2435      P:00082C P:00082C 06C400            DO      X0,L_DOWN
                            000833
2436      P:00082E P:00082E 60F400            MOVE              #PARALLEL_DOWN_LEFT,R0
                            000056
2437                                          CLOCK
2441                                L_DOWN
2442   
2443                                ; Move the image both up and down by the indicated number of lines
2444                                MOVE_PARALLEL_SPLIT
2445      P:000834 P:000834 065B00            DO      X:(R3)+,L_SPLIT
                            00083B
2446      P:000836 P:000836 60F400            MOVE              #PARALLEL_SPLIT,R0
                            00006A
2447                                          CLOCK
2451                                L_SPLIT
2452   
2453                                ; Skip over the pre-scan pixels by not transmitting A/D data in PXL_TBL
2454                                SKIP_PRESCAN_PIXELS
2455      P:00083C P:00083C 6D8B00            MOVE                          Y:<ADR_SXMIT,R5
2456      P:00083D P:00083D 000000            NOP
2457      P:00083E P:00083E 44F400            MOVE              #>%0011000,X0
                            000018
2458      P:000840 P:000840 4C6500            MOVE                          X0,Y:(R5)   ; Overwrite SXMIT with a benign value
2459   
2460                                ; Now clock the CCD prescan pixels
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  timCCDmisc.asm  Page 48



2461      P:000841 P:000841 061140            DO      Y:<X_PRESCAN,L_XPRESCAN
                            000848
2462      P:000843 P:000843 68F000            MOVE                          Y:SERIAL_READ,R0
                            000015
2463                                          CLOCK
2467                                L_XPRESCAN
2468      P:000849 P:000849 4C8900            MOVE                          Y:<SXMIT,X0 ; Restore SXMIT
2469      P:00084A P:00084A 4C6500            MOVE                          X0,Y:(R5)
2470      P:00084B P:00084B 00000C            RTS
2471   
2472                                ; Warm up the video processor by not transmitting A/D data in PXL_TBL
2473                                WARM_UP_VP
2474      P:00084C P:00084C 6D8A00            MOVE                          Y:<SXMIT_ADR,R5
2475      P:00084D P:00084D 000000            NOP
2476      P:00084E P:00084E 44F400            MOVE              #>%0011000,X0
                            000018
2477      P:000850 P:000850 4C6500            MOVE                          X0,Y:(R5)   ; Overwrite SXMIT with a benign value
2478      P:000851 P:000851 44F400            MOVE              #WARM_UP,X0
                            027100
2479      P:000853 P:000853 06C400            DO      X0,L_WARM_UP
                            00085A
2480      P:000855 P:000855 60F400            MOVE              #PXL_TBL,R0
                            0001E2
2481                                          CLOCK
2485                                L_WARM_UP
2486      P:00085B P:00085B 4C8900            MOVE                          Y:<SXMIT,X0 ; Restore SXMIT
2487      P:00085C P:00085C 4C6500            MOVE                          X0,Y:(R5)
2488      P:00085D P:00085D 00000C            RTS
2489   
2490      P:00085E P:00085E 689900  DITHER    MOVE                          Y:<SERIAL_DITHER,R0
2491                                          CLOCK
2495      P:000863 P:000863 00000C            RTS
2496   
2497                                SET_DITHER
2498      P:000864 P:000864 44DB00            MOVE              X:(R3)+,X0
2499      P:000865 P:000865 0AC400            JCLR    #0,X0,NO_DITH
                            000869
2500      P:000867 P:000867 0A002C            BSET    #ST_DITH,X:<STATUS
2501      P:000868 P:000868 0C008F            JMP     <FINISH
2502      P:000869 P:000869 0A000C  NO_DITH   BCLR    #ST_DITH,X:<STATUS
2503      P:00086A P:00086A 0C008F            JMP     <FINISH
2504   
2505                                ; Skip X rows and Y columns. Zero = 0 indicates no skipping
2506                                SKIP_X_Y
2507      P:00086B P:00086B 44DB00            MOVE              X:(R3)+,X0
2508      P:00086C P:00086C 4C1100            MOVE                          X0,Y:<X_PRESCAN
2509      P:00086D P:00086D 44DB00            MOVE              X:(R3)+,X0
2510      P:00086E P:00086E 4C1200            MOVE                          X0,Y:<Y_PRESCAN
2511      P:00086F P:00086F 0C008F            JMP     <FINISH
2512   
2513   
2514                                 TIMBOOT_X_MEMORY
2515      000870                              EQU     @LCV(L)
2516   
2517                                ;  ****************  Setup memory tables in X: space ********************
2518   
2519                                ; Define the address in P: space where the table of constants begins
2520   
2521                                          IF      @SCP("HOST","HOST")
2522      X:000036 X:000036                   ORG     X:END_COMMAND_TABLE,X:END_COMMAND_TABLE
2523                                          ENDIF
2524   
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  tim.asm  Page 49



2525                                          IF      @SCP("HOST","ROM")
2527                                          ENDIF
2528   
2529                                ; Application commands
2530      X:000036 X:000036                   DC      'PON',POWER_ON
2531      X:000038 X:000038                   DC      'POF',POWER_OFF
2532      X:00003A X:00003A                   DC      'SBV',SET_BIAS_VOLTAGES
2533      X:00003C X:00003C                   DC      'IDL',START_IDLE_CLOCKING
2534      X:00003E X:00003E                   DC      'OSH',OPEN_SHUTTER
2535      X:000040 X:000040                   DC      'CSH',CLOSE_SHUTTER
2536      X:000042 X:000042                   DC      'RDC',RDCCD
2537      X:000044 X:000044                   DC      'CLR',CLEAR
2538   
2539                                ; Exposure and readout control routines
2540      X:000046 X:000046                   DC      'SET',SET_EXPOSURE_TIME
2541      X:000048 X:000048                   DC      'RET',READ_EXPOSURE_TIME
2542      X:00004A X:00004A                   DC      'SEX',START_EXPOSURE
2543      X:00004C X:00004C                   DC      'PEX',PAUSE_EXPOSURE
2544      X:00004E X:00004E                   DC      'REX',RESUME_EXPOSURE
2545      X:000050 X:000050                   DC      'AEX',ABORT_EXPOSURE
2546      X:000052 X:000052                   DC      'ABR',ABR_RDC
2547      X:000054 X:000054                   DC      'CRD',CONTINUE_READ
2548   
2549                                ; Support routines
2550      X:000056 X:000056                   DC      'SGN',SET_GAIN
2551      X:000058 X:000058                   DC      'SBN',SET_BIAS_NUMBER
2552      X:00005A X:00005A                   DC      'SMX',SET_MUX
2553      X:00005C X:00005C                   DC      'SVO',SET_VIDEO_OFFSET
2554      X:00005E X:00005E                   DC      'CSW',CLR_SWS
2555      X:000060 X:000060                   DC      'SOS',SELECT_OUTPUT_SOURCE
2556      X:000062 X:000062                   DC      'SSS',SET_SUBARRAY_SIZES
2557      X:000064 X:000064                   DC      'SSP',SET_SUBARRAY_POSITIONS
2558      X:000066 X:000066                   DC      'RCC',READ_CONTROLLER_CONFIGURATION
2559      X:000068 X:000068                   DC      'SPS',SELECT_PIXEL_SPEED
2560      X:00006A X:00006A                   DC      'DTH',SET_DITHER
2561      X:00006C X:00006C                   DC      'SXY',SKIP_X_Y
2562   
2563                                ; Control lines one by one
2564      X:00006E X:00006E                   DC      'PUP',MOVE_PARALLEL_UP
2565      X:000070 X:000070                   DC      'PDN',MOVE_PARALLEL_DOWN
2566      X:000072 X:000072                   DC      'PSL',MOVE_PARALLEL_SPLIT
2567   
2568                                 END_APPLICATON_COMMAND_TABLE
2569      000074                              EQU     @LCV(L)
2570   
2571                                          IF      @SCP("HOST","HOST")
2572      000026                    NUM_COM   EQU     (@LCV(R)-COM_TBL_R)/2             ; Number of boot +
2573                                                                                    ;  application commands
2574      00037B                    EXPOSING  EQU     CHK_TIM                           ; Address if exposing
2575                                 CONTINUE_READING
2576      00024A                              EQU     RDCCD                             ; Address if reading out
2577                                          ENDIF
2578   
2579                                          IF      @SCP("HOST","ROM")
2581                                          ENDIF
2582   
2583                                ; Now let's go for the timing waveform tables
2584                                          IF      @SCP("HOST","HOST")
2585      Y:000000 Y:000000                   ORG     Y:0,Y:0
2586                                          ENDIF
2587   
2588      Y:000000 Y:000000         GAIN      DC      END_APPLICATON_Y_MEMORY-@LCV(L)-1
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  tim.asm  Page 50



2589   
2590      Y:000001 Y:000001         NSR       DC      2200                              ; Number Serial Read, set by host computer
2591      Y:000002 Y:000002         NPR       DC      2200                              ; Number Parallel Read, set by host computer
2592      Y:000003 Y:000003         NPCLR     DC      NP_CLR                            ; Lines to clear, quadrant mode
2593      Y:000004 Y:000004         NSCLR     DC      NS_CLR
2594      Y:000005 Y:000005         NSBIN     DC      1                                 ; Serial binning parameter
2595      Y:000006 Y:000006         NPBIN     DC      1                                 ; Parallel binning parameter
2596      Y:000007 Y:000007         CONFIG    DC      CC                                ; Controller configuration
2597      Y:000008 Y:000008         OS        DC      'ALL'                             ; Name of the output source(s)
2598      Y:000009 Y:000009         SXMIT     DC      $00F0C0
2599      Y:00000A Y:00000A         SXMIT_ADR DC      0                                 ; Address of SXMIT value in PXL_TBL
2600      Y:00000B Y:00000B         ADR_SXMIT DC      SXMIT_SPLIT_MED                   ; Address of SXMIT value in waveform table
2601      Y:00000C Y:00000C         SYN_DAT   DC      0                                 ; Synthetic image mode pixel count
2602      Y:00000D Y:00000D         TST_DATA  DC      0                                 ; For synthetic image
2603      Y:00000E Y:00000E         SHDEL     DC      SH_DEL                            ; Delay from shutter close to start of reado
ut
2604      Y:00000F Y:00000F         PRE_SCAN  DC      PRESCAN                           ; Number of prescan pixels, corrected for
2605                                                                                    ;   binning
2606      Y:000010 Y:000010         PXL_SPEED DC      DEFAULT_SPEED                     ; Pixel readout speed; default is 400 KHZ
2607      Y:000011 Y:000011         X_PRESCAN DC      0                                 ; Number of columns to skip before readout
2608      Y:000012 Y:000012         Y_PRESCAN DC      0                                 ; Number of rows to skip before readout
2609   
2610                                ; Waveform table addresses
2611      Y:000013 Y:000013         PARALLEL  DC      PARALLEL_SPLIT
2612      Y:000014 Y:000014         CLOCK_LINE DC     CLOCK_LINE_SPLIT
2613                                 SERIAL_READ
2614      Y:000015 Y:000015                   DC      SERIAL_READ_SPLIT_MED
2615                                 SERIAL_SKIP
2616      Y:000016 Y:000016                   DC      SERIAL_SKIP_SPLIT
2617      Y:000017 Y:000017         MV_ADDR   DC      PARALLEL_SPLIT
2618                                 EXPOSE_PARALLELS
2619      Y:000018 Y:000018                   DC      EXPOSE_SPLIT
2620                                 SERIAL_DITHER
2621      Y:000019 Y:000019                   DC      SERIAL_SPLIT_DITHER_MED
2622   
2623                                ; Subarray readout parameters
2624      Y:00001A Y:00001A         NP_SKIP   DC      0                                 ; Number of rows to skip
2625      Y:00001B Y:00001B         NS_SKP1   DC      0                                 ; Number of serials to clear before read
2626      Y:00001C Y:00001C         NS_SKP2   DC      0                                 ; Number of serials to clear after read
2627      Y:00001D Y:00001D         NR_BIAS   DC      0                                 ; Number of bias pixels to read
2628      Y:00001E Y:00001E         NS_READ   DC      0                                 ; Number of columns in subimage read
2629      Y:00001F Y:00001F         NP_READ   DC      0                                 ; Number of rows in subimage read
2630      Y:000020 Y:000020         N_ROWS    DC      0                                 ; Number of rows to actually read
2631      Y:000021 Y:000021         N_COLS    DC      0                                 ; Number of columns to actually read
2632      Y:000022 Y:000022         N_BIAS    DC      0                                 ; Number of columns to read in the bias regi
on
2633   
2634                                ; Subimage readout parameters. Ten subimage boxes maximum.
2635      Y:000023 Y:000023         NBOXES    DC      0                                 ; Number of boxes to read
2636                                READ_TABLE
2637      Y:000024 Y:000024                   DC      0,0,0                             ; #1 = Number of rows to clear
2638      Y:000027 Y:000027                   DC      0,0,0                             ; #2 = Number of columns to skip before
2639      Y:00002A Y:00002A                   DC      0,0,0                             ;   subimage read
2640      Y:00002D Y:00002D                   DC      0,0,0                             ; #3 = Number of columns to skip after
2641      Y:000030 Y:000030                   DC      0,0,0                             ;   subimage clear
2642      Y:000033 Y:000033                   DC      0,0,0
2643      Y:000036 Y:000036                   DC      0,0,0
2644      Y:000039 Y:000039                   DC      0,0,0
2645      Y:00003C Y:00003C                   DC      0,0,0
2646      Y:00003F Y:00003F                   DC      0,0,0
2647   
2648                                ; Include the waveform table for the designated type of CCD
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  tim.asm  Page 51



2649                                          INCLUDE "STA4K.waveforms"                 ; Readout and clocking waveform file
2650                                ; Waveform tables and definitions for the STA4150A 4k pixel CCD with
2651                                ;   ARC22 timing, ARC32 clock driver and ARC47 quad video boards.
2652                                ; Implement MPP mode for a reduction in hot column defects
2653   
2654                                ; Miscellaneous definitions
2655      000000                    VIDEO     EQU     $000000                           ; Video board timing select address
2656      002000                    CLK2      EQU     $002000                           ; Clock driver board timing select address
2657      003000                    CLK3      EQU     $003000
2658      200000                    CLKV      EQU     $200000                           ; Clock driver board DAC voltage selection a
ddress
2659   
2660      000000                    VID0      EQU     $000000                           ; Address of the ARC-47 video board
2661                                 VIDEO_CONFIG
2662      0C000C                              EQU     $0C000C                           ; WARP = DAC_OUT = ON; H16B, Reset FIFOs
2663      0E0000                    DAC_ADDR  EQU     $0E0000                           ; DAC Channel Address
2664      0FC000                    DAC_RegD  EQU     $0FC000                           ; DAC X1 Register
2665   
2666                                ; Delay numbers for clocking
2667      7D0000                    P_DELAY   EQU     $7D0000                           ; Parallel clock delay
2668                                 NUM_REPEATS
2669      000004                              EQU     4                                 ; Repeat each waveform line this many times
2670      030000                    R_DELAY   EQU     $030000                           ; Serial register transfer delay            
    <---  was $02
2671      020000                    B_DELAY   EQU     $020000                           ; Serial register clocking delay for binning
2672      000898                    NP_CLR    EQU     2200                              ; Parallel clocks to clear
2673      000898                    NS_CLR    EQU     2200                              ; Serial clocks to clear
2674      000078                    SH_DEL    EQU     120                               ; Shutter delay in milliseconds
2675      000000                    PRESKIP   EQU     0                                 ; n on the CCD - 5 to warm up the video proc
essor
2676      000000                    PRESCAN   EQU     0                                 ; n on the CCD + 3 on video processor
2677      0000C8                    NUM_CLEAN EQU     200                               ; In subarray readout, the number of serial 
skips per row
2678                                 DEFAULT_SPEED
2679      4D4544                              EQU     'MED'                             ; Medium readout speed
2680      027100                    WARM_UP   EQU     160000                            ; Number of pixels to clock to warm up the v
ideo processor
2681   
2682                                ; Gain: $0D000g, g = 0 to F, Gain = 1.0 to 4.75 in steps of 0.25
2683      0D0005                    GAIN_FAST EQU     $0D0005
2684      0D0006                    GAIN_MED  EQU     $0D0006                           ; 3 at 2.6 e-/ADU ;   5 at 2.0 e-/ADU
2685      0D0003                    GAIN_SLOW EQU     $0D0003
2686   
2687                                ; Integrator time constant:     $0C01t0, t = 0 to F, t time constant, larger values -> more gain
2688                                 TIME_CONSTANT_FAST
2689      0C0180                              EQU     $0C0180
2690                                 TIME_CONSTANT_MED
2691      0C0140                              EQU     $0C0140                           ; 3 at 2.6 e-/ADU
2692                                 TIME_CONSTANT_SLOW
2693      0C0130                              EQU     $0C0130
2694   
2695                                ; Range of OFFSET is 0 to $3FFF. Increasing numbers lower image counts.
2696                                 OFFSET_FAST
2697      002D80                              EQU     $2D80
2698                                 OFFSET_LL_FAST
2699      002E2F                              EQU     OFFSET_FAST+175
2700                                 OFFSET_LR_FAST
2701      002EC0                              EQU     OFFSET_FAST+320
2702                                 OFFSET_UR_FAST
2703      002ECB                              EQU     OFFSET_FAST+331
2704                                 OFFSET_UL_FAST
2705      002DDA                              EQU     OFFSET_FAST+90
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 52



2706   
2707      002600                    OFFSET_MED EQU    $2600
2708                                 OFFSET_LL_MED
2709      00263C                              EQU     OFFSET_MED+60
2710                                 OFFSET_LR_MED
2711      0025A0                              EQU     OFFSET_MED-96
2712                                 OFFSET_UR_MED
2713      00272C                              EQU     OFFSET_MED+300                    ; start at +134
2714                                 OFFSET_UL_MED
2715      00253B                              EQU     OFFSET_MED-197
2716   
2717                                 OFFSET_SLOW
2718      002880                              EQU     $2880
2719                                 OFFSET_LL_SLOW
2720      0028FC                              EQU     OFFSET_SLOW+124
2721                                 OFFSET_LR_SLOW
2722      002854                              EQU     OFFSET_SLOW-44
2723                                 OFFSET_UR_SLOW
2724      00298E                              EQU     OFFSET_SLOW+270
2725                                 OFFSET_UL_SLOW
2726      002804                              EQU     OFFSET_SLOW-124
2727   
2728      8.000000E+000             RG_HI     EQU     +8.0                              ; Reset Gate High               was +7/0
2729      -2.000000E+000            RG_LO     EQU     -2.0                              ; Reset Gate Low
2730      4.500000E+000             S_HI      EQU     +4.5                              ; Serial Register Clock High    was +6/-5
2731      -4.500000E+000            S_LO      EQU     -4.5                              ; Serial Register Clock Low
2732      4.500000E+000             SW_HI     EQU     +4.5                              ; Summing Well High             was +5/-5
2733      -4.500000E+000            SW_LO     EQU     -4.5                              ; Summing Well Low
2734      2.000000E+000             I_HI      EQU     +2.0                              ; Imaging Area Clocks High
2735      -8.000000E+000            I_LO      EQU     -8.0                              ; Imaging Area Clocks Low
2736      3.000000E+000             I3_HI     EQU     +3.0                              ; Imaging Area Clocks High
2737      -7.000000E+000            I3_LO     EQU     -7.0                              ; Imaging Area Clocks Low
2738   
2739      1.300000E+001             Vmax      EQU     +13.0                             ; Maximum clock driver voltage
2740      0.000000E+000             ZERO      EQU     0.0                               ; Unused pins
2741   
2742                                ; Video Offset DAC numbers      0 to $3FFF -> 14 bits
2743      002800                    OFFSET    EQU     $2800                             ; The larger the number the fewer
2744      002800                    OFFSET0   EQU     OFFSET                            ;  the image counts
2745      002800                    OFFSET1   EQU     OFFSET
2746      002800                    OFFSET2   EQU     OFFSET
2747      002800                    OFFSET3   EQU     OFFSET
2748   
2749                                ; DC Bias voltages
2750      2.400000E+001             VOD       EQU     24.0                              ; Output Drain Lesser: 26, 15.5, -2 <-- 30 m
ax
2751      2.430000E+001             VODUR     EQU     24.3                              ; CCD gain is lower in this quadrant
2752      2.376000E+001             VODLR     EQU     23.76                             ; CCD gain is higher in this quadrant
2753      1.400000E+001             VRD       EQU     14.0                              ; Reset Drain                       <-- 20 m
ax
2754      0.000000E+000             VOTG      EQU     0.0                               ; Output Gate
2755      1.500000E+001             VSC       EQU     15.0                              ; Scupper
2756   
2757                                ; DC Bias voltages - Lesser's values, slightly higher noise, lower gain
2758                                ;VOD    EQU     26.0    ; Output Drain
2759                                ;VRD    EQU     15.0    ; Reset Drain
2760                                ;VOTG   EQU      0.0    ; Output Gate
2761                                ;VSC    EQU     25.0    ; Scupper
2762   
2763                                ; DC Bias voltages - Slovakia and Poland's values Optimized for SN 15669
2764                                ;VOD    EQU     28.0    ; Output Drain
2765                                ;VRD    EQU     16.5    ; Reset Drain
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 53



2766                                ;VOTG   EQU     -2.0    ; Output Gate
2767                                ;VSC    EQU     20.0    ; Scupper
2768   
2769                                ; Kasey voltages June 18, 2013 for S/N 16314 - much higher noise
2770                                ;       OD = 28
2771                                ;       RD = 14
2772                                ;       OTG = -1
2773                                ;       SW = +6/-6
2774                                ;       S = +6/-5
2775                                ;       RG = +8/-2
2776                                ;       P1, P2 = +3.5/-8.5
2777                                ;       P3 = +8.5/-5
2778   
2779                                ; Switch state bit definitions for the bottom half of ARC32 clock driver board
2780      000001                    RG        EQU     1                                 ; All reset gates                       Pin 
#1
2781      000002                    S1LL      EQU     2                                 ; Serial Register Lower Left, Phase 1   Pin 
#2
2782      000004                    S2LL      EQU     4                                 ; Serial Register Lower Left, Phase 2   Pin 
#3
2783      000008                    S3L       EQU     8                                 ; Serial Register Lower, Phase 3        Pin 
#4
2784      000010                    S1LR      EQU     $10                               ; Serial Register Lower Right, Phase 1  Pin 
#5
2785      000020                    S2LR      EQU     $20                               ; Serial Register Lower Right, Phase 2  Pin 
#6
2786      000040                    S1UL      EQU     $40                               ; Serial Register Upper Left, Phase 1   Pin 
#7
2787      000080                    S2UL      EQU     $80                               ; Serial Register Upper Left, Phase 2   Pin 
#8
2788      000100                    S3U       EQU     $100                              ; Serial Register Upper, Phase 3        Pin 
#9
2789      000200                    S1UR      EQU     $200                              ; Serial Register Upper Right, Phase 1  Pin 
#10
2790      000400                    S2UR      EQU     $400                              ; Serial Register Upper Right, Phase 2  Pin 
#11
2791      000800                    SW        EQU     $800                              ; Summing Well                          Pin 
#12
2792   
2793      000042                    S1L       EQU     S1LL+S1UL
2794      000084                    S2L       EQU     S2LL+S2UL
2795      000210                    S1R       EQU     S1LR+S1UR
2796      000420                    S2R       EQU     S2LR+S2UR
2797   
2798      000252                    S1        EQU     S1LL+S1LR+S1UR+S1UL               ; Define these for split readout
2799      0004A4                    S2        EQU     S2LL+S2LR+S2UR+S2UL
2800      000108                    S3        EQU     S3L+S3U
2801   
2802                                ; Bit definitions for top half of clock driver board, CLK3
2803      000001                    I1LL      EQU     1                                 ; Image clock, Lower Left, Phase 1          
    Pin #13
2804      000002                    I2LL      EQU     2                                 ; Image clock, Lower Left, Phase 2          
    Pin #14
2805      000004                    I3LL      EQU     4                                 ; Image clock, Lower Left, Phase 3          
    Pin #15
2806      000008                    I1UL      EQU     8                                 ; Image clock, Upper Left, Phase 1          
    Pin #16
2807      000010                    I2UL      EQU     $10                               ; Image clock, Upper Left, Phase 2          
    Pin #17
2808      000020                    I3UL      EQU     $20                               ; Image clock, Upper Left, Phase 3          
    Pin #18
2809      000040                    I2LR      EQU     $40                               ; Image clock, Lower Right, Phase 1         
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 54



    Pin #19
2810      000080                    I1LR      EQU     $80                               ; Image clock, Lower Right, Phase 2         
    Pin #33
2811      000100                    I3LR      EQU     $100                              ; Image clock, Lower Right, Phase 3         
    Pin #34
2812      000200                    I2UR      EQU     $200                              ; Image clock, Upper Right, Phase 1         
    Pin #35
2813      000400                    I1UR      EQU     $400                              ; Image clock, Upper Right, Phase 2         
    Pin #36
2814      000800                    I3UR      EQU     $800                              ; Image clock, Upper Right, Phase 3         
    Pin #37
2815                                ; Note that the I2LR and I1LR are out of order to reflect a wiring error in the dewar.
2816                                ;   Same for I2UR and I1UR.
2817   
2818      000081                    I1L       EQU     I1LL+I1LR
2819      000042                    I2L       EQU     I2LL+I2LR
2820      000104                    I3L       EQU     I3LL+I3LR
2821      000408                    I1U       EQU     I1UL+I1UR
2822      000210                    I2U       EQU     I2UL+I2UR
2823      000820                    I3U       EQU     I3UL+I3UR
2824   
2825                                ; Serial Clocks:        RG+S1LL+S2LL+S3L+S1LR+S2LR+S1UL+S2UL+S3U+S1UR+S2UR+SW
2826                                ; Imaging Clocks:       I1L+I2L+I3L+I1U+I2U+I3U
2827   
2828                                ;  ***  Definitions for Y: memory waveform tables  *****
2829   
2830                                ; Clock the entire image UP and LEFT
2831                                PARALLEL_UP_LEFT
2832      Y:000042 Y:000042                   DC      END_PARALLEL_UP_LEFT-PARALLEL_UP_LEFT-1
2833      Y:000043 Y:000043                   DC      CLK2+R_DELAY+RG+S1+S2+00+SW
2834      Y:000044 Y:000044                   DC      VIDEO+%0011000                    ; DC restore and reset integrator
2835      Y:000045 Y:000045                   DC      CLK3+P_DELAY+I1L+I2L+000+I1U+I2U+000
2836      Y:000046 Y:000046                   DC      CLK3+P_DELAY+I1L+000+000+I1U+000+000
2837      Y:000047 Y:000047                   DC      CLK3+P_DELAY+I1L+000+I3L+I1U+000+I3U
2838      Y:000048 Y:000048                   DC      CLK3+P_DELAY+000+000+I3L+000+000+I3U
2839      Y:000049 Y:000049                   DC      CLK3+P_DELAY+000+I2L+I3L+000+I2U+I3U
2840      Y:00004A Y:00004A                   DC      CLK3+P_DELAY+000+I2L+000+000+I2U+000
2841                                ;       DC      CLK3+P_DELAY+000+000+000+000+000+000
2842      Y:00004B Y:00004B                   DC      CLK2+00+000+S2L+S1R+000+00+00
2843                                END_PARALLEL_UP_LEFT
2844   
2845                                ; Clock the entire image UP and RIGHT
2846                                PARALLEL_UP_RIGHT
2847      Y:00004C Y:00004C                   DC      END_PARALLEL_UP_RIGHT-PARALLEL_UP_RIGHT-1
2848      Y:00004D Y:00004D                   DC      CLK2+R_DELAY+RG+S1+S2+00+SW
2849      Y:00004E Y:00004E                   DC      VIDEO+%0011000                    ; DC restore and reset integrator
2850      Y:00004F Y:00004F                   DC      CLK3+P_DELAY+I1L+I2L+000+I1U+I2U+000
2851      Y:000050 Y:000050                   DC      CLK3+P_DELAY+I1L+000+000+I1U+000+000
2852      Y:000051 Y:000051                   DC      CLK3+P_DELAY+I1L+000+I3L+I1U+000+I3U
2853      Y:000052 Y:000052                   DC      CLK3+P_DELAY+000+000+I3L+000+000+I3U
2854      Y:000053 Y:000053                   DC      CLK3+P_DELAY+000+I2L+I3L+000+I2U+I3U
2855      Y:000054 Y:000054                   DC      CLK3+P_DELAY+000+I2L+000+000+I2U+000
2856                                ;       DC      CLK3+P_DELAY+000+000+000+000+000+000
2857      Y:000055 Y:000055                   DC      CLK2+00+S1L+000+000+S2R+00+00
2858                                END_PARALLEL_UP_RIGHT
2859   
2860                                ; Clock the entire image DOWN and LEFT
2861                                PARALLEL_DOWN_LEFT
2862      Y:000056 Y:000056                   DC      END_PARALLEL_DOWN_LEFT-PARALLEL_DOWN_LEFT-1
2863      Y:000057 Y:000057                   DC      CLK2+R_DELAY+RG+S1+S2+00+SW
2864      Y:000058 Y:000058                   DC      VIDEO+%0011000                    ; DC restore and reset integrator
2865      Y:000059 Y:000059                   DC      CLK3+P_DELAY+I1L+I2L+000+I1U+I2U+000
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 55



2866      Y:00005A Y:00005A                   DC      CLK3+P_DELAY+000+I2L+000+000+I2U+000
2867      Y:00005B Y:00005B                   DC      CLK3+P_DELAY+000+I2L+I3L+000+I2U+I3U
2868      Y:00005C Y:00005C                   DC      CLK3+P_DELAY+000+000+I3L+000+000+I3U
2869      Y:00005D Y:00005D                   DC      CLK3+P_DELAY+I1L+000+I3L+I1U+000+I3U
2870      Y:00005E Y:00005E                   DC      CLK3+P_DELAY+I1L+000+000+I1U+000+000
2871                                ;       DC      CLK3+P_DELAY+000+000+000+000+000+000    ; MPP during readout
2872      Y:00005F Y:00005F                   DC      CLK2+00+000+S2L+S1R+000+00+00
2873                                END_PARALLEL_DOWN_LEFT
2874   
2875                                ; Clock the entire image DOWN and RIGHT
2876                                PARALLEL_DOWN_RIGHT
2877      Y:000060 Y:000060                   DC      END_PARALLEL_DOWN_RIGHT-PARALLEL_DOWN_RIGHT-1
2878      Y:000061 Y:000061                   DC      CLK2+R_DELAY+RG+S1+S2+00+SW
2879      Y:000062 Y:000062                   DC      VIDEO+%0011000                    ; DC restore and reset integrator
2880      Y:000063 Y:000063                   DC      CLK3+P_DELAY+I1L+I2L+000+I1U+I2U+000
2881      Y:000064 Y:000064                   DC      CLK3+P_DELAY+000+I2L+000+000+I2U+000
2882      Y:000065 Y:000065                   DC      CLK3+P_DELAY+000+I2L+I3L+000+I2U+I3U
2883      Y:000066 Y:000066                   DC      CLK3+P_DELAY+000+000+I3L+000+000+I3U
2884      Y:000067 Y:000067                   DC      CLK3+P_DELAY+I1L+000+I3L+I1U+000+I3U
2885      Y:000068 Y:000068                   DC      CLK3+P_DELAY+I1L+000+000+I1U+000+000
2886                                ;       DC      CLK3+P_DELAY+000+000+000+000+000+000    ; MPP during readout
2887      Y:000069 Y:000069                   DC      CLK2+00+S1L+000+000+S2R+00+00
2888                                END_PARALLEL_DOWN_RIGHT
2889   
2890                                ;  Default
2891                                ; Clock the bottom half of the image DOWN and the top half UP (split)
2892                                PARALLEL_SPLIT
2893      Y:00006A Y:00006A                   DC      END_PARALLEL_SPLIT-PARALLEL_SPLIT-1
2894      Y:00006B Y:00006B                   DC      CLK2+RG+S1+S2+00+SW
2895      Y:00006C Y:00006C                   DC      VIDEO+%0011000                    ; DC restore and reset integrator
2896      Y:00006D Y:00006D                   DC      CLK3+P_DELAY+I1L+I2L+000+I1U+I2U+000
2897      Y:00006E Y:00006E                   DC      CLK3+P_DELAY+000+I2L+000+I1U+000+000
2898      Y:00006F Y:00006F                   DC      CLK3+P_DELAY+000+I2L+I3L+I1U+000+I3U
2899      Y:000070 Y:000070                   DC      CLK3+P_DELAY+000+000+I3L+000+000+I3U
2900      Y:000071 Y:000071                   DC      CLK3+P_DELAY+I1L+000+I3L+000+I2U+I3U
2901      Y:000072 Y:000072                   DC      CLK3+P_DELAY+I1L+000+000+000+I2U+000
2902      Y:000073 Y:000073                   DC      CLK3+P_DELAY+000+000+000+000+000+000 ; MPP during readout
2903      Y:000074 Y:000074                   DC      CLK2+00+00+S2+00+00
2904                                END_PARALLEL_SPLIT
2905   
2906                                EXPOSE_UP
2907      Y:000075 Y:000075                   DC      END_EXPOSE_UP-EXPOSE_UP-1
2908      Y:000076 Y:000076                   DC      CLK3+P_DELAY+I1L+I2L+000+I1U+I2U+000
2909      Y:000077 Y:000077                   DC      CLK3+P_DELAY+000+000+000+000+000+000
2910                                END_EXPOSE_UP
2911   
2912                                EXPOSE_DOWN
2913      Y:000078 Y:000078                   DC      END_EXPOSE_DOWN-EXPOSE_DOWN-1
2914      Y:000079 Y:000079                   DC      CLK3+P_DELAY+I1L+I2L+000+I1U+I2U+000
2915      Y:00007A Y:00007A                   DC      CLK3+P_DELAY+000+000+000+000+000+000
2916                                END_EXPOSE_DOWN
2917   
2918                                EXPOSE_SPLIT
2919      Y:00007B Y:00007B                   DC      END_EXPOSE_SPLIT-EXPOSE_SPLIT-1
2920      Y:00007C Y:00007C                   DC      CLK3+P_DELAY+I1L+I2L+000+I1U+I2U+000
2921      Y:00007D Y:00007D                   DC      CLK3+P_DELAY+000+000+000+000+000+000
2922      Y:00007E Y:00007E                   DC      CLK2                              ; All serial clocks low
2923                                END_EXPOSE_SPLIT
2924   
2925                                ;  *****************  Serial IDLE and Clearing waveforms  ****************
2926                                SERIAL_IDLE                                         ; Clock split serial charge
2927      Y:00007F Y:00007F                   DC      END_SERIAL_IDLE-SERIAL_IDLE-1
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 56



2928      Y:000080 Y:000080                   DC      CLK2+R_DELAY+RG+00+S2+00+SW
2929      Y:000081 Y:000081                   DC      CLK2+(R_DELAY-$010000)+RG+00+S2+S3+SW
2930      Y:000082 Y:000082                   DC      VIDEO+$000000+%0011000            ; Reset integrator
2931      Y:000083 Y:000083                   DC      CLK2+R_DELAY+00+00+00+S3+SW
2932      Y:000084 Y:000084                   DC      CLK2+R_DELAY+00+S1+00+S3+SW
2933      Y:000085 Y:000085                   DC      CLK2+R_DELAY+00+S1+00+00+SW
2934      Y:000086 Y:000086                   DC      CLK2+00+S1+S2+00+SW
2935      Y:000087 Y:000087                   DC      CLK2+00+S1+S2+00+SW
2936      Y:000088 Y:000088                   DC      VIDEO+$000000+%0011001            ; Stop resetting integrator
2937      Y:000089 Y:000089                   DC      VIDEO+$070000+%0011011            ; Stop resetting integrator
2938      Y:00008A Y:00008A                   DC      VIDEO+$210000+%0001011            ; Integrate reset level
2939      Y:00008B Y:00008B                   DC      VIDEO+$000000+%0011011            ; Stop Integrate
2940      Y:00008C Y:00008C                   DC      CLK2+00+S1+S2+00+00               ; Dump the charge
2941      Y:00008D Y:00008D                   DC      VIDEO+$090000+%0010011            ; Change polarity
2942      Y:00008E Y:00008E                   DC      VIDEO+$210000+%0000011            ; Integrate signal level
2943      Y:00008F Y:00008F                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
2944      Y:000090 Y:000090                   DC      VIDEO+$000000+%1110011            ; Start A/D conversion
2945      Y:000091 Y:000091                   DC      VIDEO+$000000+%0010011            ; End of start A/D conversion pulse
2946                                END_SERIAL_IDLE
2947   
2948                                SERIALS_CLEAR                                       ; Split
2949      Y:000092 Y:000092                   DC      END_SERIALS_CLEAR-SERIALS_CLEAR-1
2950      Y:000093 Y:000093                   DC      CLK2+R_DELAY+RG+00+00+S3+00
2951      Y:000094 Y:000094                   DC      CLK2+R_DELAY+00+S1+00+S3+SW
2952      Y:000095 Y:000095                   DC      CLK2+R_DELAY+00+S1+00+00+SW
2953      Y:000096 Y:000096                   DC      CLK2+R_DELAY+00+S1+S2+00+00
2954      Y:000097 Y:000097                   DC      CLK2+R_DELAY+00+00+S2+00+00
2955      Y:000098 Y:000098                   DC      CLK2+R_DELAY+00+00+S2+S3+00
2956                                END_SERIALS_CLEAR
2957   
2958                                ; ****************  Waveforms for skipping (subarray readout)  ******************
2959                                SERIAL_SKIP_LEFT
2960      Y:000099 Y:000099                   DC      END_SERIAL_SKIP_LEFT-SERIAL_SKIP_LEFT-1
2961      Y:00009A Y:00009A                   DC      CLK2+R_DELAY+RG+000+000+000+000+S3+00
2962      Y:00009B Y:00009B                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+S3+SW
2963      Y:00009C Y:00009C                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+00+SW
2964      Y:00009D Y:00009D                   DC      CLK2+R_DELAY+00+S1L+S2L+S1R+S2R+00+00
2965      Y:00009E Y:00009E                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+00+00
2966      Y:00009F Y:00009F                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+S3+00
2967                                END_SERIAL_SKIP_LEFT
2968   
2969                                SERIAL_SKIP_RIGHT
2970      Y:0000A0 Y:0000A0                   DC      END_SERIAL_SKIP_RIGHT-SERIAL_SKIP_RIGHT-1
2971      Y:0000A1 Y:0000A1                   DC      CLK2+R_DELAY+RG+000+000+000+000+S3+00
2972      Y:0000A2 Y:0000A2                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+S3+SW
2973      Y:0000A3 Y:0000A3                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+00+SW
2974      Y:0000A4 Y:0000A4                   DC      CLK2+R_DELAY+00+S1L+S2L+S1R+S2R+00+00
2975      Y:0000A5 Y:0000A5                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+00+00
2976      Y:0000A6 Y:0000A6                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+S3+00
2977                                END_SERIAL_SKIP_RIGHT
2978   
2979                                SERIAL_SKIP_SPLIT
2980      Y:0000A7 Y:0000A7                   DC      END_SERIAL_SKIP_SPLIT-SERIAL_SKIP_SPLIT-1
2981      Y:0000A8 Y:0000A8                   DC      CLK2+R_DELAY+RG+00+00+S3+00
2982      Y:0000A9 Y:0000A9                   DC      CLK2+R_DELAY+00+S1+00+S3+SW
2983      Y:0000AA Y:0000AA                   DC      CLK2+R_DELAY+00+S1+00+00+SW
2984      Y:0000AB Y:0000AB                   DC      CLK2+R_DELAY+00+S1+S2+00+00
2985      Y:0000AC Y:0000AC                   DC      CLK2+R_DELAY+00+00+S2+00+00
2986      Y:0000AD Y:0000AD                   DC      CLK2+R_DELAY+00+00+S2+S3+00
2987                                END_SERIAL_SKIP_SPLIT
2988   
2989                                ; ARC47/8:  |xfer|A/D|integ|polarity|not used|DC Restore|rst| (1 => switch open)
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 57



2990                                ;   **********  Waveforms for LEFT readout ******
2991                                SERIAL_READ_LEFT_SLOW
2992      Y:0000AE Y:0000AE                   DC      END_SERIAL_READ_LEFT_SLOW-SERIAL_READ_LEFT_SLOW-1
2993      Y:0000AF Y:0000AF                   DC      CLK2+R_DELAY+RG+000+S2L+S1R+000+00+SW
2994      Y:0000B0 Y:0000B0                   DC      CLK2+(R_DELAY-$010000)+RG+000+S2L+S1R+000+S3+SW
2995      Y:0000B1 Y:0000B1                   DC      VIDEO+$000000+%0011000            ; Reset integrator
2996      Y:0000B2 Y:0000B2                   DC      CLK2+R_DELAY+00+000+000+000+000+S3+SW
2997      Y:0000B3 Y:0000B3                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+S3+SW
2998      Y:0000B4 Y:0000B4                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+00+SW
2999      Y:0000B5 Y:0000B5                   DC      CLK2+R_DELAY+00+S1L+S2L+S1R+S2R+00+SW
3000                                SXMIT_LEFT_SLOW
3001      Y:0000B6 Y:0000B6                   DC      $00F0C0                           ; SXMIT 0 to 3
3002      Y:0000B7 Y:0000B7                   DC      VIDEO+$000000+%0011001            ; Stop resetting integrator
3003      Y:0000B8 Y:0000B8                   DC      VIDEO+$070000+%0011011            ; Stop DC restore
3004      Y:0000B9 Y:0000B9                   DC      VIDEO+$600000+%0001011            ; Integrate reset level
3005      Y:0000BA Y:0000BA                   DC      VIDEO+$000000+%0011011            ; Stop Integrate
3006      Y:0000BB Y:0000BB                   DC      CLK2+00+S1L+S2L+S1R+S2R+00+00     ; Dump the charge
3007      Y:0000BC Y:0000BC                   DC      VIDEO+$090000+%0010011            ; Change polarity
3008      Y:0000BD Y:0000BD                   DC      VIDEO+$600000+%0000011            ; Integrate signal level
3009      Y:0000BE Y:0000BE                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
3010      Y:0000BF Y:0000BF                   DC      VIDEO+$000000+%1110011            ; Start A/D conversion
3011      Y:0000C0 Y:0000C0                   DC      VIDEO+$000000+%0010011            ; End of start A/D conversion pulse
3012                                END_SERIAL_READ_LEFT_SLOW
3013   
3014                                SERIAL_READ_LEFT_MED
3015      Y:0000C1 Y:0000C1                   DC      END_SERIAL_READ_LEFT_MED-SERIAL_READ_LEFT_MED-1
3016      Y:0000C2 Y:0000C2                   DC      CLK2+R_DELAY+RG+000+S2L+S1R+000+00+SW
3017      Y:0000C3 Y:0000C3                   DC      CLK2+(R_DELAY-$010000)+RG+000+S2L+S1R+000+S3+SW
3018      Y:0000C4 Y:0000C4                   DC      VIDEO+$000000+%0011000            ; Reset integrator
3019      Y:0000C5 Y:0000C5                   DC      CLK2+R_DELAY+00+000+000+000+000+S3+SW
3020      Y:0000C6 Y:0000C6                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+S3+SW
3021      Y:0000C7 Y:0000C7                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+00+SW
3022      Y:0000C8 Y:0000C8                   DC      CLK2+R_DELAY+00+S1L+S2L+S1R+S2R+00+SW
3023                                SXMIT_LEFT_MED
3024      Y:0000C9 Y:0000C9                   DC      $00F0C0                           ; SXMIT 0 to 3
3025      Y:0000CA Y:0000CA                   DC      VIDEO+$000000+%0011001            ; Stop resetting integrator
3026      Y:0000CB Y:0000CB                   DC      VIDEO+$070000+%0011011            ; Stop DC restore
3027      Y:0000CC Y:0000CC                   DC      VIDEO+$210000+%0001011            ; Integrate reset level
3028      Y:0000CD Y:0000CD                   DC      VIDEO+$000000+%0011011            ; Stop Integrate
3029      Y:0000CE Y:0000CE                   DC      CLK2+00+S1L+S2L+S1R+S2R+00+00     ; Dump the charge
3030      Y:0000CF Y:0000CF                   DC      VIDEO+$090000+%0010011            ; Change polarity
3031      Y:0000D0 Y:0000D0                   DC      VIDEO+$210000+%0000011            ; Integrate signal level
3032      Y:0000D1 Y:0000D1                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
3033      Y:0000D2 Y:0000D2                   DC      VIDEO+$000000+%1110011            ; Start A/D conversion
3034      Y:0000D3 Y:0000D3                   DC      VIDEO+$000000+%0010011            ; End of start A/D conversion pulse
3035                                END_SERIAL_READ_LEFT_MED
3036   
3037                                SERIAL_READ_LEFT_FAST
3038      Y:0000D4 Y:0000D4                   DC      END_SERIAL_READ_LEFT_FAST-SERIAL_READ_LEFT_FAST-1
3039      Y:0000D5 Y:0000D5                   DC      CLK2+$000000+RG+000+S2L+S1R+000+S3+SW
3040      Y:0000D6 Y:0000D6                   DC      VIDEO+$000000+%0011000            ; Reset integrator
3041      Y:0000D7 Y:0000D7                   DC      CLK2+$000000+00+000+000+000+000+S3+SW
3042                                SXMIT_LEFT_FAST
3043      Y:0000D8 Y:0000D8                   DC      $00F000                           ; SXMIT 0 only
3044      Y:0000D9 Y:0000D9                   DC      VIDEO+$000000+%0011001            ; Stop resetting integrator
3045      Y:0000DA Y:0000DA                   DC      VIDEO+$000000+%0011011            ; Stop DC restore
3046      Y:0000DB Y:0000DB                   DC      VIDEO+$000000+%0001011            ; Integrate reset level
3047      Y:0000DC Y:0000DC                   DC      CLK2+$040000+000+S1L+000+000+S2R+S3+SW
3048      Y:0000DD Y:0000DD                   DC      CLK2+$040000+000+S1L+000+000+S2R+00+SW
3049      Y:0000DE Y:0000DE                   DC      CLK2+$000000+000+S1L+000+000+S2R+00+00 ; Dump the charge
3050      Y:0000DF Y:0000DF                   DC      VIDEO+$0030000+%0010111           ; Stop integrate, change polarity
3051      Y:0000E0 Y:0000E0                   DC      VIDEO+$000000+%0000111            ; Integrate signal level
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 58



3052      Y:0000E1 Y:0000E1                   DC      CLK2+$040000+00+S1L+S2L+S1R+S2R+00+00
3053      Y:0000E2 Y:0000E2                   DC      CLK2+$040000+00+000+S2L+S1R+000+00+00
3054      Y:0000E3 Y:0000E3                   DC      CLK2+$000000+00+000+S2L+S1R+000+S3+00
3055      Y:0000E4 Y:0000E4                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
3056      Y:0000E5 Y:0000E5                   DC      VIDEO+$000000+%1110011            ; Start A/D
3057                                END_SERIAL_READ_LEFT_FAST
3058   
3059                                ;   **********  Waveforms for RIGHT readout ******
3060                                SERIAL_READ_RIGHT_SLOW
3061      Y:0000E6 Y:0000E6                   DC      END_SERIAL_READ_RIGHT_SLOW-SERIAL_READ_RIGHT_SLOW-1
3062      Y:0000E7 Y:0000E7                   DC      CLK2+R_DELAY+RG+S1L+000+000+S2R+00+SW
3063      Y:0000E8 Y:0000E8                   DC      CLK2+(R_DELAY-$010000)+RG+S1L+000+000+S2R+S3+SW
3064      Y:0000E9 Y:0000E9                   DC      VIDEO+$000000+%0011000            ; Reset integrator
3065      Y:0000EA Y:0000EA                   DC      CLK2+R_DELAY+00+000+000+000+000+S3+SW
3066      Y:0000EB Y:0000EB                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+S3+SW
3067      Y:0000EC Y:0000EC                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+00+SW
3068      Y:0000ED Y:0000ED                   DC      CLK2+R_DELAY+00+S1L+S2L+S1R+S2R+00+SW
3069                                SXMIT_RIGHT_SLOW
3070      Y:0000EE Y:0000EE                   DC      $00F0C0                           ; SXMIT 0 to 3
3071      Y:0000EF Y:0000EF                   DC      VIDEO+$000000+%0011001            ; Stop resetting integrator
3072      Y:0000F0 Y:0000F0                   DC      VIDEO+$070000+%0011011            ; Stop DC restore
3073      Y:0000F1 Y:0000F1                   DC      VIDEO+$600000+%0001011            ; Integrate reset level
3074      Y:0000F2 Y:0000F2                   DC      VIDEO+$000000+%0011011            ; Stop Integrate
3075      Y:0000F3 Y:0000F3                   DC      CLK2+00+S1L+S2L+S1R+S2R+00+00     ; Dump the charge
3076      Y:0000F4 Y:0000F4                   DC      VIDEO+$090000+%0010011            ; Change polarity
3077      Y:0000F5 Y:0000F5                   DC      VIDEO+$600000+%0000011            ; Integrate signal level
3078      Y:0000F6 Y:0000F6                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
3079      Y:0000F7 Y:0000F7                   DC      VIDEO+$000000+%1110011            ; Start A/D conversion
3080      Y:0000F8 Y:0000F8                   DC      VIDEO+$000000+%0010011            ; End of start A/D conversion pulse
3081                                END_SERIAL_READ_RIGHT_SLOW
3082   
3083                                SERIAL_READ_RIGHT_MED
3084      Y:0000F9 Y:0000F9                   DC      END_SERIAL_READ_RIGHT_MED-SERIAL_READ_RIGHT_MED-1
3085      Y:0000FA Y:0000FA                   DC      CLK2+R_DELAY+RG+S1L+000+000+S2R+00+SW
3086      Y:0000FB Y:0000FB                   DC      CLK2+(R_DELAY-$010000)+RG+S1L+000+000+S2R+S3+SW
3087      Y:0000FC Y:0000FC                   DC      VIDEO+$000000+%0011000            ; Reset integrator
3088      Y:0000FD Y:0000FD                   DC      CLK2+R_DELAY+00+000+000+000+000+S3+SW
3089      Y:0000FE Y:0000FE                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+S3+SW
3090      Y:0000FF Y:0000FF                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+00+SW
3091      Y:000100 Y:000100                   DC      CLK2+R_DELAY+00+S1L+S2L+S1R+S2R+00+SW
3092                                SXMIT_RIGHT_MED
3093      Y:000101 Y:000101                   DC      $00F0C0                           ; SXMIT 0 to 3
3094      Y:000102 Y:000102                   DC      VIDEO+$000000+%0011001            ; Stop resetting integrator
3095      Y:000103 Y:000103                   DC      VIDEO+$070000+%0011011            ; Stop DC restore
3096      Y:000104 Y:000104                   DC      VIDEO+$210000+%0001011            ; Integrate reset level
3097      Y:000105 Y:000105                   DC      VIDEO+$000000+%0011011            ; Stop Integrate
3098      Y:000106 Y:000106                   DC      CLK2+00+S1L+S2L+S1R+S2R+00+00     ; Dump the charge
3099      Y:000107 Y:000107                   DC      VIDEO+$090000+%0010011            ; Change polarity
3100      Y:000108 Y:000108                   DC      VIDEO+$210000+%0000011            ; Integrate signal level
3101      Y:000109 Y:000109                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
3102      Y:00010A Y:00010A                   DC      VIDEO+$000000+%1110011            ; Start A/D conversion
3103      Y:00010B Y:00010B                   DC      VIDEO+$000000+%0010011            ; End of start A/D conversion pulse
3104                                END_SERIAL_READ_RIGHT_MED
3105   
3106                                SERIAL_READ_RIGHT_FAST                              ; ~1 microsec
3107      Y:00010C Y:00010C                   DC      END_SERIAL_READ_RIGHT_FAST-SERIAL_READ_RIGHT_FAST-1
3108      Y:00010D Y:00010D                   DC      CLK2+$000000+RG+S1L+000+000+S2R+S3+SW
3109      Y:00010E Y:00010E                   DC      VIDEO+$000000+%0011000            ; Reset integrator
3110      Y:00010F Y:00010F                   DC      CLK2+$000000+00+000+000+000+000+S3+SW
3111                                SXMIT_RIGHT_FAST
3112      Y:000110 Y:000110                   DC      $00F041                           ; SXMIT 1 only
3113      Y:000111 Y:000111                   DC      VIDEO+$000000+%0011001            ; Stop resetting integrator
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 59



3114      Y:000112 Y:000112                   DC      VIDEO+$000000+%0011011            ; Stop DC restore
3115      Y:000113 Y:000113                   DC      VIDEO+$000000+%0001011            ; Integrate reset level
3116      Y:000114 Y:000114                   DC      CLK2+$040000+00+000+S2L+S1R+000+S3+SW
3117      Y:000115 Y:000115                   DC      CLK2+$040000+00+000+S2L+S1R+000+00+SW
3118      Y:000116 Y:000116                   DC      CLK2+$000000+00+000+S2L+S1R+000+00+00 ; Dump the charge
3119      Y:000117 Y:000117                   DC      VIDEO+$030000+%0010111            ; Stop integrate, change polarity
3120      Y:000118 Y:000118                   DC      VIDEO+$000000+%0000111            ; Integrate signal level
3121      Y:000119 Y:000119                   DC      CLK2+$040000+00+S1L+S2L+S1R+S2R+00+00
3122      Y:00011A Y:00011A                   DC      CLK2+$040000+00+S1L+000+000+S2R+00+00
3123      Y:00011B Y:00011B                   DC      CLK2+$000000+00+S1L+000+000+S2R+S3+00
3124      Y:00011C Y:00011C                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
3125      Y:00011D Y:00011D                   DC      VIDEO+$000000+%1110011            ; Start A/D
3126                                END_SERIAL_READ_RIGHT_FAST
3127   
3128                                ;   **********  Waveform for SPLIT = Both readouts ******
3129                                SERIAL_READ_SPLIT_SLOW
3130      Y:00011E Y:00011E                   DC      END_SERIAL_READ_SPLIT_SLOW-SERIAL_READ_SPLIT_SLOW-1
3131      Y:00011F Y:00011F                   DC      CLK2+R_DELAY+RG+00+S2+00+SW
3132      Y:000120 Y:000120                   DC      CLK2+(R_DELAY-$010000)+RG+00+S2+S3+SW
3133      Y:000121 Y:000121                   DC      VIDEO+$000000+%0011000            ; Reset integrator
3134      Y:000122 Y:000122                   DC      CLK2+R_DELAY+00+00+00+S3+SW
3135      Y:000123 Y:000123                   DC      CLK2+R_DELAY+00+S1+00+S3+SW
3136      Y:000124 Y:000124                   DC      CLK2+R_DELAY+00+S1+00+00+SW
3137      Y:000125 Y:000125                   DC      CLK2+00+S1+S2+00+SW
3138                                SXMIT_SPLIT_SLOW
3139      Y:000126 Y:000126                   DC      $00F0C0                           ; SXMIT 0 to 3
3140      Y:000127 Y:000127                   DC      VIDEO+$000000+%0011001            ; Stop resetting integrator
3141      Y:000128 Y:000128                   DC      VIDEO+$070000+%0011011            ; Stop DC restore
3142      Y:000129 Y:000129                   DC      VIDEO+$600000+%0001011            ; Integrate reset level
3143      Y:00012A Y:00012A                   DC      VIDEO+$000000+%0011011            ; Stop Integrate
3144      Y:00012B Y:00012B                   DC      CLK2+00+S1+S2+00+00               ; Dump the charge
3145      Y:00012C Y:00012C                   DC      VIDEO+$090000+%0010011            ; Change polarity
3146      Y:00012D Y:00012D                   DC      VIDEO+$600000+%0000011            ; Integrate signal level
3147      Y:00012E Y:00012E                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
3148      Y:00012F Y:00012F                   DC      VIDEO+$000000+%1110011            ; Start A/D conversion
3149      Y:000130 Y:000130                   DC      VIDEO+$000000+%0010011            ; End of start A/D conversion pulse
3150                                END_SERIAL_READ_SPLIT_SLOW
3151   
3152                                SERIAL_READ_SPLIT_MED
3153      Y:000131 Y:000131                   DC      END_SERIAL_READ_SPLIT_MED-SERIAL_READ_SPLIT_MED-1
3154      Y:000132 Y:000132                   DC      CLK2+R_DELAY+RG+00+S2+00+SW
3155      Y:000133 Y:000133                   DC      CLK2+(R_DELAY-$010000)+RG+00+S2+S3+SW
3156      Y:000134 Y:000134                   DC      VIDEO+$000000+%0011000            ; Reset integrator
3157      Y:000135 Y:000135                   DC      CLK2+R_DELAY+00+00+00+S3+SW
3158      Y:000136 Y:000136                   DC      CLK2+R_DELAY+00+S1+00+S3+SW
3159      Y:000137 Y:000137                   DC      CLK2+R_DELAY+00+S1+00+00+SW
3160      Y:000138 Y:000138                   DC      CLK2+00+S1+S2+00+SW
3161                                SXMIT_SPLIT_MED
3162      Y:000139 Y:000139                   DC      $00F0C0                           ; SXMIT 0 to 3
3163      Y:00013A Y:00013A                   DC      VIDEO+$000000+%0011001            ; Stop resetting integrator
3164      Y:00013B Y:00013B                   DC      VIDEO+$070000+%0011011            ; Stop DC restore
3165      Y:00013C Y:00013C                   DC      VIDEO+$210000+%0001011            ; Integrate reset level
3166      Y:00013D Y:00013D                   DC      VIDEO+$000000+%0011011            ; Stop Integrate
3167      Y:00013E Y:00013E                   DC      CLK2+00+S1+S2+00+00               ; Dump the charge
3168      Y:00013F Y:00013F                   DC      VIDEO+$090000+%0010011            ; Change polarity
3169      Y:000140 Y:000140                   DC      VIDEO+$210000+%0000011            ; Integrate signal level
3170      Y:000141 Y:000141                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
3171      Y:000142 Y:000142                   DC      VIDEO+$000000+%1110011            ; Start A/D conversion
3172      Y:000143 Y:000143                   DC      VIDEO+$000000+%0010011            ; End of start A/D conversion pulse
3173                                END_SERIAL_READ_SPLIT_MED
3174   
3175                                SERIAL_READ_SPLIT_FAST                              ; ~ 1 microsec
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 60



3176      Y:000144 Y:000144                   DC      END_SERIAL_READ_SPLIT_FAST-SERIAL_READ_SPLIT_FAST-1
3177      Y:000145 Y:000145                   DC      CLK2+$000000+RG+00+S2+S3+SW
3178      Y:000146 Y:000146                   DC      VIDEO+$000000+%0011000            ; Reset integrator
3179      Y:000147 Y:000147                   DC      CLK2+$000000+00+00+00+S3+SW
3180                                SXMIT_SPLIT_FAST
3181      Y:000148 Y:000148                   DC      $00F0C0                           ; SXMIT 0 to 3
3182      Y:000149 Y:000149                   DC      VIDEO+$000000+%0011001            ; Stop resetting integrator
3183      Y:00014A Y:00014A                   DC      VIDEO+$000000+%0011011            ; Stop DC restore
3184      Y:00014B Y:00014B                   DC      VIDEO+$000000+%0001011            ; Integrate reset level
3185      Y:00014C Y:00014C                   DC      CLK2+$040000+00+S1+00+S3+SW
3186      Y:00014D Y:00014D                   DC      CLK2+$040000+00+S1+00+00+SW
3187      Y:00014E Y:00014E                   DC      CLK2+$000000+00+S1+00+00+00       ; Dump the charge
3188      Y:00014F Y:00014F                   DC      VIDEO+$030000+%0010111            ; Stop integrate, change polarity
3189      Y:000150 Y:000150                   DC      VIDEO+$000000+%0000111            ; Integrate signal level
3190      Y:000151 Y:000151                   DC      CLK2+$040000+00+S1+S2+00+00
3191      Y:000152 Y:000152                   DC      CLK2+$040000+00+00+S2+00+00
3192      Y:000153 Y:000153                   DC      CLK2+$000000+00+00+S2+S3+00
3193      Y:000154 Y:000154                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
3194      Y:000155 Y:000155                   DC      VIDEO+$000000+%1110011            ; Start A/D
3195                                END_SERIAL_READ_SPLIT_FAST
3196   
3197                                SERIAL_SPLIT_DITHER_MED
3198      Y:000156 Y:000156                   DC      END_SERIAL_SPLIT_DITHER_MED-SERIAL_SPLIT_DITHER_MED-1
3199      Y:000157 Y:000157                   DC      CLK2+R_DELAY+RG+00+S2+00+00
3200      Y:000158 Y:000158                   DC      CLK2+R_DELAY+00+00+S2+S3+00
3201      Y:000159 Y:000159                   DC      VIDEO+$000000+%0011000            ; Reset integrator
3202      Y:00015A Y:00015A                   DC      CLK2+R_DELAY+00+00+00+S3+00
3203      Y:00015B Y:00015B                   DC      CLK2+R_DELAY+00+S1+00+S3+SW
3204      Y:00015C Y:00015C                   DC      CLK2+R_DELAY+00+S1+00+00+SW
3205      Y:00015D Y:00015D                   DC      CLK2+00+S1+S2+00+SW
3206      Y:00015E Y:00015E                   DC      CLK2+00+S1+S2+00+SW               ; nop - don't transmit A/D data
3207      Y:00015F Y:00015F                   DC      VIDEO+$080000+%0011011            ; Stop resetting integrator
3208      Y:000160 Y:000160                   DC      VIDEO+$210000+%0001011            ; Integrate reset level
3209      Y:000161 Y:000161                   DC      VIDEO+$000000+%0011011            ; Stop Integrate
3210      Y:000162 Y:000162                   DC      CLK2+00+S1+S2+00+00               ; Dump the charge
3211      Y:000163 Y:000163                   DC      VIDEO+$090000+%0010011            ; Change polarity
3212      Y:000164 Y:000164                   DC      VIDEO+$210000+%0000011            ; Integrate signal level
3213      Y:000165 Y:000165                   DC      VIDEO+$000000+%0010011            ; Stop Integrate
3214      Y:000166 Y:000166                   DC      VIDEO+$000000+%1110011            ; Start A/D conversion
3215      Y:000167 Y:000167                   DC      VIDEO+$000000+%0010011            ; End of start A/D conversion pulse
3216                                END_SERIAL_SPLIT_DITHER_MED
3217   
3218                                ;  ************** Waveforms for Binning ***************
3219                                CLOCK_LINE_LEFT
3220      Y:000168 Y:000168                   DC      END_CLOCK_LINE_LEFT-CLOCK_LINE_LEFT-1
3221      Y:000169 Y:000169                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+00+SW
3222      Y:00016A Y:00016A                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+S3+SW
3223      Y:00016B Y:00016B                   DC      CLK2+R_DELAY+00+000+000+000+000+S3+SW
3224      Y:00016C Y:00016C                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+S3+SW
3225      Y:00016D Y:00016D                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+00+SW
3226      Y:00016E Y:00016E                   DC      CLK2+R_DELAY+00+S1L+S2L+S1R+S2R+00+SW
3227                                END_CLOCK_LINE_LEFT
3228   
3229                                CLOCK_LINE_RIGHT
3230      Y:00016F Y:00016F                   DC      END_CLOCK_LINE_RIGHT-CLOCK_LINE_RIGHT-1
3231      Y:000170 Y:000170                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+00+SW
3232      Y:000171 Y:000171                   DC      CLK2+R_DELAY+00+S1L+000+000+S2R+S3+SW
3233      Y:000172 Y:000172                   DC      CLK2+R_DELAY+00+000+000+000+000+S3+SW
3234      Y:000173 Y:000173                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+S3+SW
3235      Y:000174 Y:000174                   DC      CLK2+R_DELAY+00+000+S2L+S1R+000+00+SW
3236      Y:000175 Y:000175                   DC      CLK2+R_DELAY+00+S1L+S2L+S1R+S2R+00+SW
3237                                END_CLOCK_LINE_RIGHT
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 61



3238   
3239                                CLOCK_LINE_SPLIT
3240      Y:000176 Y:000176                   DC      END_CLOCK_LINE_SPLIT-CLOCK_LINE_SPLIT-1
3241      Y:000177 Y:000177                   DC      CLK2+R_DELAY+00+00+S2+00+SW
3242      Y:000178 Y:000178                   DC      CLK2+R_DELAY+00+00+S2+S3+SW
3243      Y:000179 Y:000179                   DC      CLK2+R_DELAY+00+00+00+S3+SW
3244      Y:00017A Y:00017A                   DC      CLK2+R_DELAY+00+S1+00+S3+SW
3245      Y:00017B Y:00017B                   DC      CLK2+R_DELAY+00+S1+00+00+SW
3246      Y:00017C Y:00017C                   DC      CLK2+R_DELAY+00+S1+S2+00+SW
3247                                END_CLOCK_LINE_SPLIT
3248   
3249                                ; Initialization of ARC32 clock driver and video processor DACs and switches
3250      Y:00017D Y:00017D         DACS      DC      END_DACS-DACS-1
3251      Y:00017E Y:00017E                   DC      CLKV+$0A0080                      ; DAC = unbuffered mode
3252      Y:00017F Y:00017F                   DC      CLKV+$000100+@CVI((RG_HI+Vmax)/(2*Vmax)*255) ; Pin #1, Reset Gate
3253      Y:000180 Y:000180                   DC      CLKV+$000200+@CVI((RG_LO+Vmax)/(2*Vmax)*255)
3254      Y:000181 Y:000181                   DC      CLKV+$000400+@CVI((S_HI+Vmax)/(2*Vmax)*255) ; Pin #2, S1 Lower Left
3255      Y:000182 Y:000182                   DC      CLKV+$000800+@CVI((S_LO+Vmax)/(2*Vmax)*255)
3256      Y:000183 Y:000183                   DC      CLKV+$002000+@CVI((S_HI+Vmax)/(2*Vmax)*255) ; Pin #3, S2 Lower Left
3257      Y:000184 Y:000184                   DC      CLKV+$004000+@CVI((S_LO+Vmax)/(2*Vmax)*255)
3258      Y:000185 Y:000185                   DC      CLKV+$008000+@CVI((S_HI+Vmax)/(2*Vmax)*255) ; Pin #4, S3 Lower Both
3259      Y:000186 Y:000186                   DC      CLKV+$010000+@CVI((S_LO+Vmax)/(2*Vmax)*255)
3260      Y:000187 Y:000187                   DC      CLKV+$020100+@CVI((S_HI+Vmax)/(2*Vmax)*255) ; Pin #5, S1 Lower Right
3261      Y:000188 Y:000188                   DC      CLKV+$020200+@CVI((S_LO+Vmax)/(2*Vmax)*255)
3262      Y:000189 Y:000189                   DC      CLKV+$020400+@CVI((S_HI+Vmax)/(2*Vmax)*255) ; Pin #6, S2 Lower Right
3263      Y:00018A Y:00018A                   DC      CLKV+$020800+@CVI((S_LO+Vmax)/(2*Vmax)*255)
3264      Y:00018B Y:00018B                   DC      CLKV+$022000+@CVI((S_HI+Vmax)/(2*Vmax)*255) ; Pin #7, S1 Upper Left
3265      Y:00018C Y:00018C                   DC      CLKV+$024000+@CVI((S_LO+Vmax)/(2*Vmax)*255)
3266      Y:00018D Y:00018D                   DC      CLKV+$028000+@CVI((S_HI+Vmax)/(2*Vmax)*255) ; Pin #8, S2 Upper Left
3267      Y:00018E Y:00018E                   DC      CLKV+$030000+@CVI((S_LO+Vmax)/(2*Vmax)*255)
3268      Y:00018F Y:00018F                   DC      CLKV+$040100+@CVI((S_HI+Vmax)/(2*Vmax)*255) ; Pin #9, S3 Upper Both
3269      Y:000190 Y:000190                   DC      CLKV+$040200+@CVI((S_LO+Vmax)/(2*Vmax)*255)
3270      Y:000191 Y:000191                   DC      CLKV+$040400+@CVI((S_HI+Vmax)/(2*Vmax)*255) ; Pin #10, S1 Upper Right
3271      Y:000192 Y:000192                   DC      CLKV+$040800+@CVI((S_LO+Vmax)/(2*Vmax)*255)
3272      Y:000193 Y:000193                   DC      CLKV+$042000+@CVI((S_HI+Vmax)/(2*Vmax)*255) ; Pin #11, S2 Upper Right
3273      Y:000194 Y:000194                   DC      CLKV+$044000+@CVI((S_LO+Vmax)/(2*Vmax)*255)
3274      Y:000195 Y:000195                   DC      CLKV+$048000+@CVI((SW_HI+Vmax)/(2*Vmax)*255) ; Pin #12, Summing Well
3275      Y:000196 Y:000196                   DC      CLKV+$050000+@CVI((SW_LO+Vmax)/(2*Vmax)*255)
3276   
3277      Y:000197 Y:000197                   DC      CLKV+$060100+@CVI((I_HI+Vmax)/(2*Vmax)*255) ; Pin #13, I1 Lower Left
3278      Y:000198 Y:000198                   DC      CLKV+$060200+@CVI((I_LO+Vmax)/(2*Vmax)*255)
3279      Y:000199 Y:000199                   DC      CLKV+$060400+@CVI((I_HI+Vmax)/(2*Vmax)*255) ; Pin #14, I2 Lower Left
3280      Y:00019A Y:00019A                   DC      CLKV+$060800+@CVI((I_LO+Vmax)/(2*Vmax)*255)
3281      Y:00019B Y:00019B                   DC      CLKV+$062000+@CVI((I3_HI+Vmax)/(2*Vmax)*255) ; Pin #15, I3 Lower Left, MPP pha
se
3282      Y:00019C Y:00019C                   DC      CLKV+$064000+@CVI((I3_LO+Vmax)/(2*Vmax)*255)
3283      Y:00019D Y:00019D                   DC      CLKV+$068000+@CVI((I_HI+Vmax)/(2*Vmax)*255) ; Pin #16, I1 Upper Left
3284      Y:00019E Y:00019E                   DC      CLKV+$070000+@CVI((I_LO+Vmax)/(2*Vmax)*255)
3285      Y:00019F Y:00019F                   DC      CLKV+$080100+@CVI((I_HI+Vmax)/(2*Vmax)*255) ; Pin #17, I2 Upper Left
3286      Y:0001A0 Y:0001A0                   DC      CLKV+$080200+@CVI((I_LO+Vmax)/(2*Vmax)*255)
3287      Y:0001A1 Y:0001A1                   DC      CLKV+$080400+@CVI((I3_HI+Vmax)/(2*Vmax)*255) ; Pin #18, I3 Upper Left, MPP pha
se
3288      Y:0001A2 Y:0001A2                   DC      CLKV+$080800+@CVI((I3_LO+Vmax)/(2*Vmax)*255)
3289      Y:0001A3 Y:0001A3                   DC      CLKV+$082000+@CVI((I_HI+Vmax)/(2*Vmax)*255) ; Pin #19, I1 Lower Right
3290      Y:0001A4 Y:0001A4                   DC      CLKV+$084000+@CVI((I_LO+Vmax)/(2*Vmax)*255)
3291      Y:0001A5 Y:0001A5                   DC      CLKV+$088000+@CVI((I_HI+Vmax)/(2*Vmax)*255) ; Pin #33, I2 Lower Right
3292      Y:0001A6 Y:0001A6                   DC      CLKV+$090000+@CVI((I_LO+Vmax)/(2*Vmax)*255)
3293      Y:0001A7 Y:0001A7                   DC      CLKV+$0A0100+@CVI((I3_HI+Vmax)/(2*Vmax)*255) ; Pin #34, I3 Lower Right, MPP ph
ase
3294      Y:0001A8 Y:0001A8                   DC      CLKV+$0A0200+@CVI((I3_LO+Vmax)/(2*Vmax)*255)
3295      Y:0001A9 Y:0001A9                   DC      CLKV+$0A0400+@CVI((I_HI+Vmax)/(2*Vmax)*255) ; Pin #35, I1 Upper Right
3296      Y:0001AA Y:0001AA                   DC      CLKV+$0A0800+@CVI((I_LO+Vmax)/(2*Vmax)*255)
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 62



3297      Y:0001AB Y:0001AB                   DC      CLKV+$0A2000+@CVI((I_HI+Vmax)/(2*Vmax)*255) ; Pin #36, I2 Upper Right
3298      Y:0001AC Y:0001AC                   DC      CLKV+$0A4000+@CVI((I_LO+Vmax)/(2*Vmax)*255)
3299      Y:0001AD Y:0001AD                   DC      CLKV+$0A8000+@CVI((I3_HI+Vmax)/(2*Vmax)*255) ; Pin #37, I3 Upper Right, MPP ph
ase
3300      Y:0001AE Y:0001AE                   DC      CLKV+$0B0000+@CVI((I3_LO+Vmax)/(2*Vmax)*255)
3301   
3302                                ;  ******************  Code for the ARC-47 video board ****************************
3303      Y:0001AF Y:0001AF                   DC      VID0+$0C0000                      ; Normal Image data D17-D2
3304   
3305                                ; Gain: $0D000g, g = 0 to F, Gain = 1.0 to 4.75 in steps of 0.25
3306      Y:0001B0 Y:0001B0                   DC      VID0+$0D0004
3307   
3308                                ; Integrator time constant:     $0C01t0, t = 0 to F, t time constant, larger values -> more gain
3309                                ;       DC      VID0+$0C0180    ; Default = 8 => 0.5 microsec, same as ARC-45
3310      Y:0001B1 Y:0001B1                   DC      VID0+$0C0130                      ; Good for INT = $40
3311   
3312      2.980000E+001             VOD_MAX   EQU     29.8
3313      2.000000E+001             VRD_MAX   EQU     20.0
3314      1.000000E+001             VOTG_MAX  EQU     10.0
3315      00338A                    DAC_VOD   EQU     @CVI((VOD/VOD_MAX)*16384-1)       ; Unipolar
3316      00342F                    DAC_VODUR EQU     @CVI((VODUR/VOD_MAX)*16384-1)     ; Unipolar
3317      003306                    DAC_VODLR EQU     @CVI((VODLR/VOD_MAX)*16384-1)     ; Unipolar
3318      002035                    DAC_VSC   EQU     @CVI((VSC/VOD_MAX)*16384-1)       ; Unipolar
3319      002CCB                    DAC_VRD   EQU     @CVI((VRD/VRD_MAX)*16384-1)       ; Unipolar
3320      001FFF                    DAC_VOTG  EQU     @CVI(((VOTG+VOTG_MAX)/VOTG_MAX)*8192-1) ; Bipolar
3321      001FFF                    DAC_ZERO  EQU     8191                              ; Bipolar
3322   
3323                                ; Initialize the ARC-47 DAC for the DC_BIAS voltages
3324      Y:0001B2 Y:0001B2                   DC      VID0+DAC_ADDR+$000000             ; Vod0, Pin #52
3325      Y:0001B3 Y:0001B3                   DC      VID0+DAC_RegD+DAC_VOD
3326      Y:0001B4 Y:0001B4                   DC      VID0+DAC_ADDR+$000004             ; Vrd0, Pin #13
3327      Y:0001B5 Y:0001B5                   DC      VID0+DAC_RegD+DAC_VRD
3328      Y:0001B6 Y:0001B6                   DC      VID0+DAC_ADDR+$000008             ; Votg, Pin #29
3329      Y:0001B7 Y:0001B7                   DC      VID0+DAC_RegD+DAC_VOTG
3330      Y:0001B8 Y:0001B8                   DC      VID0+DAC_ADDR+$00000C             ; Unused, Pin #5
3331      Y:0001B9 Y:0001B9                   DC      VID0+DAC_RegD+DAC_ZERO
3332   
3333      Y:0001BA Y:0001BA                   DC      VID0+DAC_ADDR+$000001             ; Vod1, Pin #32
3334      Y:0001BB Y:0001BB                   DC      VID0+DAC_RegD+DAC_VODLR
3335      Y:0001BC Y:0001BC                   DC      VID0+DAC_ADDR+$000005             ; Unused, Pin #55
3336      Y:0001BD Y:0001BD                   DC      VID0+DAC_RegD
3337      Y:0001BE Y:0001BE                   DC      VID0+DAC_ADDR+$000009             ; Unused, Pin #8
3338      Y:0001BF Y:0001BF                   DC      VID0+DAC_RegD+DAC_ZERO
3339      Y:0001C0 Y:0001C0                   DC      VID0+DAC_ADDR+$00000D             ; Unused, Pin #47
3340      Y:0001C1 Y:0001C1                   DC      VID0+DAC_RegD+DAC_ZERO
3341   
3342      Y:0001C2 Y:0001C2                   DC      VID0+DAC_ADDR+$000002             ; Vod2, Pin #11
3343      Y:0001C3 Y:0001C3                   DC      VID0+DAC_RegD+DAC_VODUR
3344      Y:0001C4 Y:0001C4                   DC      VID0+DAC_ADDR+$000006             ; Unused, Pin #35
3345      Y:0001C5 Y:0001C5                   DC      VID0+DAC_RegD
3346      Y:0001C6 Y:0001C6                   DC      VID0+DAC_ADDR+$00000A             ; Unused, Pin #50
3347      Y:0001C7 Y:0001C7                   DC      VID0+DAC_RegD+DAC_ZERO
3348      Y:0001C8 Y:0001C8                   DC      VID0+DAC_ADDR+$00000E             ; Unused, Pin #27
3349      Y:0001C9 Y:0001C9                   DC      VID0+DAC_RegD+DAC_ZERO
3350   
3351      Y:0001CA Y:0001CA                   DC      VID0+DAC_ADDR+$000003             ; Vod3, Pin #53
3352      Y:0001CB Y:0001CB                   DC      VID0+DAC_RegD+DAC_VOD
3353      Y:0001CC Y:0001CC                   DC      VID0+DAC_ADDR+$000007             ; Unused, Pin #14
3354      Y:0001CD Y:0001CD                   DC      VID0+DAC_RegD
3355      Y:0001CE Y:0001CE                   DC      VID0+DAC_ADDR+$00000B             ; Unused, Pin #30
3356      Y:0001CF Y:0001CF                   DC      VID0+DAC_RegD+DAC_ZERO
3357      Y:0001D0 Y:0001D0                   DC      VID0+DAC_ADDR+$00000F             ; Unused, Pin #6
Motorola DSP56300 Assembler  Version 6.3.4   15-05-13  12:34:16  STA4K.waveforms  Page 63



3358      Y:0001D1 Y:0001D1                   DC      VID0+DAC_RegD+DAC_ZERO
3359   
3360      Y:0001D2 Y:0001D2                   DC      VID0+DAC_ADDR+$000010             ; Vsc, Pin #33
3361      Y:0001D3 Y:0001D3                   DC      VID0+DAC_RegD+DAC_VSC
3362      Y:0001D4 Y:0001D4                   DC      VID0+DAC_ADDR+$000011             ; Unused, Pin #56
3363      Y:0001D5 Y:0001D5                   DC      VID0+DAC_RegD
3364      Y:0001D6 Y:0001D6                   DC      VID0+DAC_ADDR+$000012             ; Unused, Pin #9
3365      Y:0001D7 Y:0001D7                   DC      VID0+DAC_RegD+DAC_ZERO
3366      Y:0001D8 Y:0001D8                   DC      VID0+DAC_ADDR+$000013             ; Unused, Pin #48
3367      Y:0001D9 Y:0001D9                   DC      VID0+DAC_RegD+DAC_ZERO
3368   
3369                                ; Initialize the ARC-47 DAC For Video Offsets
3370      Y:0001DA Y:0001DA                   DC      VID0+DAC_ADDR+$000014
3371      Y:0001DB Y:0001DB                   DC      VID0+DAC_RegD+OFFSET0
3372      Y:0001DC Y:0001DC                   DC      VID0+DAC_ADDR+$000015
3373      Y:0001DD Y:0001DD                   DC      VID0+DAC_RegD+OFFSET1
3374      Y:0001DE Y:0001DE                   DC      VID0+DAC_ADDR+$000016
3375      Y:0001DF Y:0001DF                   DC      VID0+DAC_RegD+OFFSET2
3376      Y:0001E0 Y:0001E0                   DC      VID0+DAC_ADDR+$000017
3377      Y:0001E1 Y:0001E1                   DC      VID0+DAC_RegD+OFFSET3
3378   
3379                                END_DACS
3380   
3381                                ; Pixel table to contain serial waveform constructed from pieces
3382      Y:0001E2 Y:0001E2         PXL_TBL   DC      0
3383   
3384                                 END_APPLICATON_Y_MEMORY
3385      0001E3                              EQU     @LCV(L)
3386   
3387                                ; End of program
3388                                          END

0    Errors
0    Warnings


