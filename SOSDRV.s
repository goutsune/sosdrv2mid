;I/O registers

TEST        = $f0     ; Unused in driver
DSP_CTRL    = $f1
DSP_ADDR    = $f2
DSP_DATA    = $f3
PORT0       = $f4
PORT1       = $f5
PORT2       = $f6
PORT3       = $f7
TMP0        = $f8     ; Unused in driver
TMP1        = $f9     ; Unused in driver
TIMER0      = $fa
TIMER1      = $fb
TIMER2      = $fc     ; Unused in driver
HW_COUNTER0 = $fd
HW_COUNTER1 = $fe
HW_COUNTER2 = $ff

; Global DSP Registers

DSP_MVOLL   = $0c
DSP_MVOLR   = $1c
DSP_EVOLL   = $2c
DSP_EVOLR   = $3c
DSP_KON	    = $4c
DSP_KOF	    = $5c
DSP_FLG	    = $6c
DSP_ENDX    = $7c
DSP_EFB	    = $0d
DSP_PMON    = $2d
DSP_NON	    = $3d
DSP_EON	    = $4d
DSP_DIR	    = $5d
DSP_ESA	    = $6d
DSP_EDL	    = $7d
DSP_C0	    = $0f
DSP_C1	    = $1f
DSP_C2	    = $2f
DSP_C3	    = $3f
DSP_C4	    = $4f
DSP_C5	    = $5f
DSP_C6	    = $6f
DSP_C7 	    = $7f

; Zero page variables
PROC_SFX_FLAG = $02
PROC_MUS_FLAG = $03
SFX_BUSY      = $06
WRITE_MASK    = $09
CHAN_PTR      = $10  ; 16 bit pointer to channel work area, referenced around everywhere
CUR_TRACK_STAT= $12  ; Holds the status of current track
CUR_TRACK     = $13  ; Denotes 1-current track being processed. Depends on $2 and $3
CUR_SEQ_PTR   = $14  ; 16b, stores sequence data pointer when loading event
CUR_SEQ_PTR_HI= $15  ; Upper byte for convenience
CMD_PARAM_OFC = $16  ; Used to read next bytes from sequences as current command param
DRV_FLAGS     = $17  ; Used when setting timer speed and more
DRIVER_STATE1 = $18
DRIVER_STATE2 = $19
DSP_CHAN_STAT = $c0  ; $c0~$c7 are used to track channel busy status by driver
DRV_TMP_LO    = $d0  ; Note pitch, Output volume, Pan, Track processing loop
DRV_TMP_HI    = $d1  ;  and Vibrato store temp data there
NXT_PITCH_LO  = $d2  ; This is pitch for the next semitone,
NXT_PITCH_HI  = $d3  ; used when calculating vibrato?

; Sequencer commands
NOTE_REST  = $bf

; Control Register commands
START_TIM0    = $1
START_TIM1    = $2
START_TIM2 	  = $4
PORT_CLEAR_01 = $10
PORT_CLEAR_23 = $20


; Work area defs
TRACK_STATUS = $00  ; Track status
                    ; $90 = rest,
                    ; $D0 = playing,
                    ; $F0 = Load next command
                    ; $28 = Error?
RAW_CMD      = $01  ; Raw command value is written here // ALSO STORES TIMER DIVIDER
SEQ_PTR      = $02  ; 16b, points to next command to read
SEQ_PTR_HI   = $03  ; 16b, points to next command to read
REMAIN_LEN   = $04  ; counts down, new cmd is fetched if 0
NOTE_LEN     = $05  ; Number of ticks to wait before loading next event
REMAIN_CUT   = $06  ; Counts down, sets channel status to 90 and cuts sound early
NOTE_CUT     = $07  ; Number of ticks to wait before cuttin curent note, does not load next event
NOTE_NUM     = $08  ; Decoded note number for lookup
NOTE_VEL     = $09  ; Note velocity, used when writing volume register
COARSE_TUNE  = $0a  ; Adds semitones to current note, signed
DSP_CHANNEL  = $0b  ; Defines to which dsp channel should next note be written
WORK_0C      = $0c
CUR_DETUNE   = $0d  ; Detune tmp?
VIBRATO_SPD  = $0e  ; 0 stops processing alltogether
WORK_0F      = $0f  ; ???
VOLUME_OUT_L = $10  ; $0-7f
VOLUME_OUT_R = $11  ; ↑
VOLUME_LEV   = $12  ; Saved when setting volume, used for calculation only
PAN_TMP      = $13  ; Saved when setting pan, used for calculation only
FINE_TUNE    = $14  ; Detunes current instrument, in cents?
VIBRATO_LEV  = $15  ;
DRVPARAM_TMP = $16  ; Used together with vibrato level
DRVPARAM_TMP2= $17  ; Used together with vibrato level
COARSE_TUNE2 = $18  ; Offsets sound by semitone
FINE_TUNE2   = $19  ; Offsets sound by 1/256 semitone?
PLAY_MODE    = $1a  ; Track playback mode. $25 normal,
                    ;                      $ff breaks engine,
                    ;                      $00 stops playback at track end
WORK_1B      = $1b  ; Seems to be unused in code

; ========= These 5 are transferred in bulk?
SPC_SCRN     = $1c  ; DSP *4 register, loads instrument data from memory tbl
SPC_ADSR1    = $1d  ; DSP ADSR Register 1: E DDD AAAA  //E: Enable
SPC_ADSR2    = $1e  ; DSP ADSR register 2: SSS  RRRRR
SPC_GAIN     = $1f  ; DSP Gain, 0VVV VVVV or 1 MM VVVVV  //M: Mode; V: Value
FREQ_MULT    = $20  ; Seems to be multiplier for frequency values
SPC_OUTX     = $21  ; Are we even supposed to write these to DSP?

SEQ_START    = $22  ; Sequence start offset
WORK_24      = $24  ; Affects PLAY_MODE


.ORG $0800

Start:
; Port 0 Seems to trigger transfer routine
; Port 1 Plays SFX by number
; Port 2 ????
; Port 3 ????
0800: e8 10     mov   a,#PORT_CLEAR_01
0802: c5 f1 00  mov   DSP_CTRL,a
0805: e8 65     mov   a,#$65
0807: c5 f6 00  mov   PORT2,a
080a: e8 87     mov   a,#$87
080c: c5 f7 00  mov   PORT3,a
080f: 20        clrp				; The driver only works on page $0000 for page adressing
0810: cd ef     mov   x,#$ef
0812: bd        mov   sp,x          ; Setup stack
0813: cd 00     mov   x,#0

; This manually writes DSP registers, 0x22 bytes
DSPInit:
0815: f5 4d 10  mov   a,DSPInitData+x
0818: fd        mov   y,a               ; Select DSP Register
0819: 3d        inc   x
081a: f5 4d 10  mov   a,DSPInitData+x   ; Select Register Value
081d: 3d        inc   x
081e: 3f 92 0a  call  WriteDSP
0821: c8 22     cmp   x,#$22
0823: 90 f0     bcc   DSPInit           ; X < $22?

0825: e8 2a     mov   a,#$2a            ; 1/(8000/42) = 5¼ ms, ~ 190.48Hz
0827: c5 fa 00  mov   TIMER0,a          ; Setup timer speed
082a: e8 01     mov   a,#START_TIM0
082c: c5 f1 00  mov   DSP_CTRL,a        ; Start the timer
082f: e8 00     mov   a,#0
0831: 5d        mov   x,a

0832: af        mov   (x)+,a
0833: c8 e0     cmp   x,#$e0
0835: 90 fb     bcc   $0832

0837: 8d 04     mov   y,#4              ; $04XX are SFX tracks
0839: e8 00     mov   a,#0              ;   ↑
083b: da 10     movw  CHAN_PTR,ya
083d: 8f 10 13  mov   CUR_TRACK,#$10    ; 16 tracks to process, starting with $0400
0840: 8d 00     mov   y,#0              ; <-.
0842: e8 00     mov   a,#0              ;   |
0844: d7 10     mov   (CHAN_PTR)+y,a    ;  |
0846: 3f b8 08  call  UnkSub            ;  `.
0849: 6e 13 f4  dbnz  CUR_TRACK,$0840   ; Did we finish with all tracks?
084c: e8 80     mov   a,#$80
084e: c5 f4 00  mov   PORT0,a
0851: c4 04     mov   $04,a
0853: e8 00     mov   a,#0
0855: c5 f5 00  mov   PORT1,a
0858: c4 05     mov   $05,a
085a: 60        clrc

WaitForTimer:
085b: e5 fd 00  mov   a,HW_COUNTER0     ; Read counter value
085e: 28 0f     and   a,#$0f            ; Only lower 4 bits
0860: 84 02     adc   a,PROC_SFX_FLAG   ; $02 = timer accumulator,
                                        ; add to current timer value
0862: c4 02     mov   $02,a             ; Store back into memory
0864: 68 32     cmp   a,#$32
0866: 90 f3     bcc   WaitForTimer      ; Loop until our counter is > 0x32

LoopSetup:
0868: 8f 00 02  mov   PROC_SFX_FLAG,#0
086b: e8 2a     mov   a,#$2a
086d: 3f 48 0d  call  $0d48
0870: 8d 6c     mov   y,#DSP_FLG
0872: e8 12     mov   a,StoreSettingAndApply            ; %00010010 Noise=800Hz
0874: 3f 92 0a  call  WriteDSP
0877: c4 00     mov   $00,a
0879: 3f c1 08  call  CheckSFX
087c: f8 18     mov   x,DRIVER_STATE1
087e: 3e 19     cmp   x,DRIVER_STATE2
0880: f0 05     beq   $0887             ;-. Process normally if states are equal
0882: 3f f6 08  call  $08f6             ;  `.
0885: 2f f5     bra   $087c             ;    `.
                                        ;     ;
MainLoop:                               ;    /
0887: e4 02     mov   a,PROC_SFX_FLAG   ; <-´
0889: d0 09     bne   $0894
088b: e5 fd 00  mov   a,HW_COUNTER0
088e: 28 0f     and   a,#$0f
0890: c4 02     mov   PROC_SFX_FLAG,a
0892: 2f 0c     bra   $08a0
0894: e4 24     mov   a,$24
0896: d0 06     bne   $089e
0898: 3f f6 0a  call  ResetChanLoop16Tr
089b: 3f c5 0a  call  $0ac5
089e: 8b 02     dec   PROC_SFX_FLAG
08a0: e4 03     mov   a,PROC_MUS_FLAG
08a2: d0 09     bne   $08ad
08a4: e5 fe 00  mov   a,HW_COUNTER1
08a7: 28 0f     and   a,#$0f
08a9: c4 03     mov   PROC_MUS_FLAG,a
08ab: 2f 09     bra   $08b6
08ad: e4 24     mov   a,$24
08af: d0 03     bne   $08b4
08b1: 3f 04 0b  call  ResetChanLoop8Tr
08b4: 8b 03     dec   PROC_MUS_FLAG   ; At this point we finished processing all tracks
08b6: 2f c1     bra   $0879

SetNextChanPtr:
08b8: 8d 00     mov   y,#$00
08ba: e8 40     mov   a,#$40
08bc: 7a 10     addw  ya,CHAN_PTR
08be: da 10     movw  CHAN_PTR,ya
08c0: 6f        ret

CheckSFX:
08c1: ec f5 00  mov   y,PORT1
08c4: 7e 06     cmp   y,SFX_BUSY
08c6: f0 0c     beq   $08d4
08c8: 3f ef 08  call  $08ef
08cb: f0 28     beq   $08f5
08cd: e8 04     mov   a,#$04
08cf: cb 06     mov   SFX_BUSY,y
08d1: 3f e1 08  call  $08e1
08d4: e5 f4 00  mov   a,PORT0
08d7: 10 1c     bpl   $08f5
08d9: 3f ef 08  call  $08ef
08dc: f0 17     beq   $08f5
08de: 3f 3a 09  call  $093a
08e1: f8 18     mov   x,DRIVER_STATE1
08e3: d5 00 02  mov   $0200+x,a
08e6: 3d        inc   x
08e7: dd        mov   a,y
08e8: d5 00 02  mov   $0200+x,a
08eb: 3d        inc   x
08ec: d8 18     mov   DRIVER_STATE1,x
08ee: 6f        ret

08ef: f8 18     mov   x,DRIVER_STATE1
08f1: 3d        inc   x
08f2: 3d        inc   x
08f3: 3e 19     cmp   x,DRIVER_STATE2
08f5: 6f        ret

08f6: 3f 21 09  call  $0921
08f9: 1c        asl   a
08fa: 5d        mov   x,a
08fb: c8 1c     cmp   x,#$1c
08fd: b0 1f     bcs   $091e
08ff: 1f 02 09  jmp   ($0902+x)

.ORG $0902
SysFuncJumpTable:
	  dw $091e,                         ; Jumps to Start
	  dw $095a,
	  dw $097b,                         ; Jumps to Start
	  dw $097e,
	  dw $09b9,
	  dw $0a1a,
	  dw $0a31,
	  dw $0a0f,
	  dw $0ab1,
	  dw $0ab9,
	  dw $0a4a,
	  dw $0a4e,
	  dw $0aee,                         ; $25 = #00
	  dw $0af2,                         ; $25 = #FF

091e: 5f 00 08  jmp   Start

0921: f8 19     mov   x,DRIVER_STATE2
0923: 3e 18     cmp   x,DRIVER_STATE1
0925: f0 0e     beq   $0935
0927: f5 00 02  mov   a,$0200+x
092a: 2d        push  a
092b: 3d        inc   x
092c: f5 00 02  mov   a,$0200+x
092f: fd        mov   y,a
0930: ae        pop   a
0931: 3d        inc   x
0932: d8 19     mov   $19,x
0934: 6f        ret

0935: e5 f4 00  mov   a,PORT0
0938: 10 fb     bpl   $0935
093a: e5 f6 00  mov   a,PORT2
093d: ec f7 00  mov   y,PORT3
0940: 2d        push  a
0941: e4 04     mov   a,$04
0943: 28 7f     and   a,#$7f
0945: c5 f4 00  mov   PORT0,a
0948: c4 04     mov   $04,a
094a: e5 f4 00  mov   a,PORT0
094d: 30 fb     bmi   $094a
094f: e4 04     mov   a,$04
0951: 08 80     or    a,#$80
0953: c5 f4 00  mov   PORT0,a
0956: c4 04     mov   $04,a
0958: ae        pop   a
0959: 6f        ret

095a: 3f 21 09  call  $0921
095d: da d0     movw  DRV_TMP_LO,ya
095f: 3f 21 09  call  $0921
0962: da d2     movw  NXT_PITCH_LO,ya
0964: 3f 21 09  call  $0921
0967: cd 00     mov   x,#0
0969: c7 d0     mov   (DRV_TMP_LO+x),a
096b: 3a d0     incw  DRV_TMP_LO
096d: 1a d2     decw  NXT_PITCH_LO
096f: f0 09     beq   $097a
0971: dd        mov   a,y
0972: c7 d0     mov   (DRV_TMP_LO+x),a
0974: 3a d0     incw  DRV_TMP_LO
0976: 1a d2     decw  NXT_PITCH_LO
0978: d0 ea     bne   $0964
097a: 6f        ret

097b: 5f 00 08  jmp   Start

097e: dd        mov   a,y
097f: 5d        mov   x,a
0980: c5 f5 00  mov   PORT1,a
0983: c4 05     mov   $05,a
0985: 1c        asl   a
0986: 8d 00     mov   y,#$00
0988: da d0     movw  DRV_TMP_LO,ya
098a: 98 00 d1  adc   DRV_TMP_HI,#$00
098d: ec de 10  mov   y,$10de
0990: e5 dd 10  mov   a,$10dd
0993: 7a d0     addw  ya,DRV_TMP_LO
0995: da d2     movw  NXT_PITCH_LO,ya
0997: 8d 00     mov   y,#0
0999: f7 d2     mov   a,(NXT_PITCH_LO)+y
099b: c4 d0     mov   DRV_TMP_LO,a
099d: fc        inc   y
099e: f7 d2     mov   a,(NXT_PITCH_LO)+y
09a0: c4 d1     mov   DRV_TMP_HI,a
09a2: 8d 06     mov   y,#$06            ; $06XX are music tracks
09a4: e8 00     mov   a,#$00            ;    ↑
09a6: da 10     movw  CHAN_PTR,ya
09a8: 8f 08 13  mov   CUR_TRACK,#$08    ; Process music tracks only
09ab: 3f e8 09  call  $09e8
09ae: 3f b8 08  call  SetNextChanPtr
09b1: 3a d0     incw  DRV_TMP_LO
09b3: 3a d0     incw  DRV_TMP_LO
09b5: 6e 13 f3  dbnz  CUR_TRACK,$09ab    ; Did we finish with all tracks?
09b8: 6f        ret

09b9: 6d        push  y
09ba: 3f 31 0a  call  $0a31
09bd: ee        pop   y
09be: dd        mov   a,y
09bf: 5d        mov   x,a
09c0: 1c        asl   a
09c1: 8d 00     mov   y,#0
09c3: da d0     movw  DRV_TMP_LO,ya
09c5: 98 00 d1  adc   DRV_TMP_HI,#0
09c8: ec e0 10  mov   y,$10e0
09cb: e5 df 10  mov   a,$10df
09ce: 7a d0     addw  ya,DRV_TMP_LO
09d0: da d0     movw  DRV_TMP_LO,ya
09d2: 8d 04     mov   y,#$04
09d4: e8 00     mov   a,#$00
09d6: da 10     movw  CHAN_PTR,ya
09d8: 8f 08 13  mov   CUR_TRACK,#8

09db: 8d 00     mov   y,TRACK_STATUS
09dd: f7 10     mov   a,(CHAN_PTR)+y
09df: 10 0c     bpl   $09ed
09e1: 3f b8 08  call  SetNextChanPtr
09e4: 6e 13 f4  dbnz  CUR_TRACK,$09db    ; Did we finish with all tracks?
09e7: 6f        ret

09e8: 4d        push  x
09e9: 3f 68 0a  call  CmdB1
09ec: ce        pop   x
09ed: 8d 00     mov   y,TRACK_STATUS
09ef: f6 6f 10  mov   a,Data106f+y      ; $80 at that address
09f2: d7 10     mov   (CHAN_PTR)+y,a
09f4: fc        inc   y
09f5: ad 1b     cmp   y,#$1b
09f7: 90 f6     bcc   $09ef
09f9: 8d 0c     mov   y,#WORK_0C
09fb: 7d        mov   a,x
09fc: d7 10     mov   (CHAN_PTR)+y,a
09fe: 8d 00     mov   y,#TRACK_STATUS
0a00: f7 d0     mov   a,(DRV_TMP_LO)+y
0a02: 8d 02     mov   y,#SEQ_PTR
0a04: d7 10     mov   (CHAN_PTR)+y,a
0a06: 8d 01     mov   y,#RAW_CMD
0a08: f7 d0     mov   a,(DRV_TMP_LO)+y
0a0a: 8d 03     mov   y,#SEQ_PTR_HI
0a0c: d7 10     mov   (CHAN_PTR)+y,a
0a0e: 6f        ret

0a0f: 8d 04     mov   y,#$04            ; $04XX are SFX tracks
0a11: e8 00     mov   a,#$00            ;   ↑
0a13: da 10     movw  CHAN_PTR,ya
0a15: 8f 10 13  mov   CUR_TRACK,#$10
0a18: 2f 09     bra   $0a23

0a1a: 8d 06     mov   y,#$06
0a1c: e8 00     mov   a,#$00
0a1e: da 10     movw  CHAN_PTR,ya
0a20: 8f 08 13  mov   CUR_TRACK,#$08
0a23: 3f 68 0a  call  CmdB1
0a26: 3f b8 08  call  SetNextChanPtr
0a29: 3a d0     incw  DRV_TMP_LO
0a2b: 3a d0     incw  DRV_TMP_LO
0a2d: 6e 13 f3  dbnz  CUR_TRACK,$0a23    ; Did we finish with all tracks?
0a30: 6f        ret

0a31: dd        mov   a,y
0a32: 5d        mov   x,a
0a33: 8d 04     mov   y,#$04
0a35: e8 00     mov   a,#$00
0a37: da 10     movw  CHAN_PTR,ya
0a39: 8f 08 13  mov   CUR_TRACK,#$08
0a3c: 7d        mov   a,x               ; <-.
0a3d: 8d 0c     mov   y,#$0c            ;   |
0a3f: 77 10     cmp   a,(CHAN_PTR)+y    ;  /
0a41: f0 25     beq   CmdB1             ; |
0a43: 3f b8 08  call  SetNextChanPtr ; `,
0a46: 6e 13 f3  dbnz  CUR_TRACK,$0a3c   ; ´
0a49: 6f        ret

0a4a: 8f 00 24  mov   $24,#$00
0a4d: 6f        ret

0a4e: 8d 04     mov   y,#$04
0a50: e8 00     mov   a,#$00
0a52: da 10     movw  CHAN_PTR,ya
0a54: 8f 10 13  mov   CUR_TRACK,#$10
0a57: 3f 76 0a  call  $0a76
0a5a: 3f b8 08  call  SetNextChanPtr
0a5d: 3a d0     incw  DRV_TMP_LO
0a5f: 3a d0     incw  DRV_TMP_LO
0a61: 6e 13 f3  dbnz  CUR_TRACK,$0a57
0a64: 8f ff 24  mov   $24,#$ff
0a67: 6f        ret

CmdB1:
0a68: 8d 00     mov   y,#TRACK_STATUS
0a6a: f7 10     mov   a,(CHAN_PTR)+y
0a6c: 5d        mov   x,a
0a6d: e8 00     mov   a,#TRACK_STATUS
0a6f: d7 10     mov   (CHAN_PTR)+y,a
0a71: c8 c0     cmp   x,#$c0
0a73: b0 0f     bcs   KOFChannel        ; X ≥ $c0
0a75: 6f        ret

0a76: 8d 00     mov   y,#TRACK_STATUS
0a78: f7 10     mov   a,(CHAN_PTR)+y
0a7a: 5d        mov   x,a
0a7b: 28 9f     and   a,#$9f
0a7d: d7 10     mov   (CHAN_PTR)+y,a
0a7f: c8 c0     cmp   x,#$c0
0a81: b0 01     bcs   KOFChannel
0a83: 6f        ret

KOFChannel:
0a84: 8d 0b     mov   y,#DSP_CHANNEL
0a86: f7 10     mov   a,(CHAN_PTR)+y
0a88: 5d        mov   x,a               ; X = current output channel
0a89: e8 00     mov   a,#0              ; A = 0
0a8b: d4 c0     mov   DSP_CHAN_STAT+x,a ; $c0~$c7 are dsp channel statuses?
0a8d: f5 8a 10  mov   a,Power2+x
0a90: 8d 5c     mov   y,#DSP_KOF

WriteDSP:                      		    ; A = Value, Y = Address
0a92: cc f2 00  mov   DSP_ADDR,y
0a95: c5 f3 00  mov   DSP_DATA,a		; ENTRYPOINT FROM SPC FILE
0a98: 6f        ret

WriteMasked:
0a99: 2d        push  a				; A = Value, Y = Address
0a9a: dd        mov   a,y
0a9b: 04 09     or    a,WRITE_MASK
0a9d: c5 f2 00  mov   DSP_ADDR,a
0aa0: ae        pop   a
0aa1: c5 f3 00  mov   DSP_DATA,a
0aa4: 6f        ret

ResetTrackStatus:
0aa5: 3f 84 0a  call  KOFChannel
0aa8: 8d 00     mov   y,#TRACK_STATUS
0aaa: f7 10     mov   a,(CHAN_PTR)+y
0aac: 28 9f     and   a,#$9f            ; 0b10011111 are valid track status flags?
0aae: d7 10     mov   (CHAN_PTR)+y,a
0ab0: 6f        ret

0ab1: 8f 01 20  mov   $20,#1
0ab4: 8f 00 23  mov   $23,#0
0ab7: 2f 06     bra   $0abf

0ab9: 8f ff 20  mov   $20,#$ff
0abc: 8f ff 23  mov   $23,#$ff

0abf: cb 22     mov   $22,y
0ac1: 8f 00 21  mov   $21,#$00
0ac4: 6f        ret

0ac5: e4 22     mov   a,$22             ; Load
0ac7: f0 16     beq   $0adf             ; Jump if it's 0
0ac9: 60        clrc
0aca: 84 21     adc   a,$21             ; Add value from $22 to $21
0acc: c4 21     mov   $21,a             ; and store back
0ace: 90 0f     bcc   $0adf             ; Return if we didn't overflow
0ad0: 60        clrc
0ad1: e4 20     mov   a,$20             ; Load from $20 and store into...
0ad3: 84 23     adc   a,$23             ; Add from $23
0ad5: d0 06     bne   $0add             ; A == 0?
0ad7: e3 20 05  bbs7  $20,$0adf         ; Return if $20 > 7F
0ada: 8f 00 22  mov   $22,#0            ; Reset $22 after overload
0add: c4 23     mov   $23,a             ; ...store into $23 if OK
0adf: 6f        ret

0ae0: 03 17 0a  bbs0  DRV_FLAGS,$0aed
0ae3: eb 22     mov   y,$22
0ae5: f0 06     beq   $0aed
0ae7: 3f a2 0e  call  SetChannelBusyMask
0aea: 3f b0 0e  call  SetupVolume
0aed: 6f        ret

0aee: 8f 00 25  mov   $25,#0
0af1: 6f        ret

0af2: 8f ff 25  mov   $25,#$ff
0af5: 6f        ret

ResetChanLoop16Tr:
0af6: 8d 04     mov   y,#$04
0af8: e8 00     mov   a,#$00
0afa: da 10     movw  CHAN_PTR,ya
0afc: 8f 08 13  mov   CUR_TRACK,#$08
0aff: 8f ff 17  mov   DRV_FLAGS,#$ff
0b02: 2f 0c     bra   $0b10

ResetChanLoop8Tr:
0b04: 8d 06     mov   y,#$06
0b06: e8 00     mov   a,#$00
0b08: da 10     movw  CHAN_PTR,ya
0b0a: 8f 08 13  mov   CUR_TRACK,#$08
0b0d: 8f 00 17  mov   DRV_FLAGS,#$00

0b10: 8d 5c     mov   y,#DSP_KOF
0b12: e8 00     mov   a,#$00
0b14: 3f 92 0a  call  WriteDSP          ; Sends Key Off to all channels

ProcTrackStatus:
0b17: 8d 00     mov   y,#TRACK_STATUS   ; $D0/F0 when playing, $90 when note cut
0b19: f7 10     mov   a,(CHAN_PTR)+y
0b1b: c4 12     mov   CUR_TRACK_STAT,a
0b1d: f3 12 3a  bbc7  CUR_TRACK_STAT,TrackDisabled   ; $80
0b20: d3 12 20  bbc6  CUR_TRACK_STAT,ProcNoteTick    ; $40
0b23: b3 12 07  bbc5  CUR_TRACK_STAT,ProcNoteCutTick ; $20

Proc00To1F:
0b26: 28 df     and   a,#$df            ; $00 - $1f
0b28: d7 10     mov   (CHAN_PTR)+y,a
0b2a: 3f 49 0e  call  $0e49

ProcNoteCutTick:
0b2d: 8d 06     mov   y,#REMAIN_CUT
0b2f: f7 10     mov   a,(CHAN_PTR)+y
0b31: f0 0a     beq   $0b3d
0b33: 9c        dec   a
0b34: d7 10     mov   (CHAN_PTR)+y,a
0b36: d0 05     bne   $0b3d
0b38: 3f a5 0a  call  ResetTrackStatus
0b3b: 2f 06     bra   ProcNoteTick
0b3d: 3f 12 10  call  UpdateVibrato
0b40: 3f e0 0a  call  $0ae0

ProcNoteTick:
0b43: 8d 04     mov   y,#REMAIN_LEN
0b45: f7 10     mov   a,(CHAN_PTR)+y    ; Load tick counter for channel
0b47: d0 0e     bne   $0b57             ; Jump if nonzero
0b49: 8d 00     mov   y,#TRACK_STATUS
0b4b: f7 10     mov   a,(CHAN_PTR)+y    ; Load track status
0b4d: c4 12     mov   CUR_TRACK_STAT,a             ; Store
0b4f: f3 12 08  bbc7  CUR_TRACK_STAT,TrackDisabled    ; If bit 7 is not set, jump
0b52: 3f 61 0b  call  ProcessSeqData
0b55: 2f ec     bra   ProcNoteTick
0b57: 9c        dec   a
0b58: d7 10     mov   (CHAN_PTR)+y,a

TrackDisabled:
0b5a: 3f b8 08  call  SetNextChanPtr
0b5d: 6e 13 b7  dbnz  CUR_TRACK, ProcTrackStatus ; if CurTrack > 0
0b60: 6f        ret

ProcessSeqData:
0b61: 3f c1 08  call  CheckSFX
0b64: 8d 02     mov   y,#SEQ_PTR        ; <--.
0b66: f7 10     mov   a,(CHAN_PTR)+y    ;    |
0b68: c4 14     mov   CUR_SEQ_PTR,a     ;   /
0b6a: fc        inc   y                 ;  |
0b6b: f7 10     mov   a,(CHAN_PTR)+y    ;  `,
0b6d: c4 15     mov   CUR_SEQ_PTR_HI,a  ; Store current sequence ptr to $14, WORD
0b6f: 8d 00     mov   y,#0
; ################################ First CMD byte is read from here
0b71: f7 14     mov   a,(CUR_SEQ_PTR)+y ; A = data at CUR_SEQ_PTR, P.N = A.7
0b73: 30 09     bmi   $0b7e             ; data > $7f? branch on bit 7 of input data

0b75: 8f 00 16  mov   CMD_PARAM_OFC,#0
0b78: 8d 01     mov   y,#RAW_CMD        ; If we got here, we overwrite command in A and
0b7a: f7 10     mov   a,(CHAN_PTR)+y    ; re-execute the last command stored in RAW_CMD
0b7c: 2f 0b     bra   $0b89             ; our value becomes the first argument for that command

0b7e: 8f 01 16  mov   CMD_PARAM_OFC,#1
0b81: 68 c0     cmp   a,#$c0
0b83: 90 04     bcc   $0b89             ; data < $c0?

0b85: 8d 01     mov   y,#RAW_CMD      ; C0 - CF commands get stored into fnum buffer
0b87: d7 10     mov   (CHAN_PTR)+y,a

0b89: 68 cf     cmp   a,#$cf
0b8b: 90 03     bcc   $0b90             ; data < $cf?
0b8d: 5f d5 0d  jmp   ProcessNoteCmd   ; > $cf are notes
0b90: 68 b1     cmp   a,#$b1
0b92: b0 12     bcs   CmdSwitch         ; data ≥ $b1?

SetNoteLength:
0b94: a8 7f     sbc   a,#$7f            ; data -= $7f
0b96: 78 01 1f  cmp   $1f,#1            ; Set by CmdBE
0b99: f0 04     beq   $0b9f             ; if $1f is set, reuse event length?
0b9b: 5d        mov   x,a               ;   `-.
0b9c: f5 ac 10  mov   a,NoteLenTbl+x    ;     |
0b9f: 8d 05     mov   y,#NOTE_LEN       ; <--´
0ba1: d7 10     mov   (CHAN_PTR)+y,a
0ba3: 5f b7 0b  jmp   UpdateSeqPtr

CmdSwitch:
0ba6: 1c        asl   a                 ; And here we shift cmd left by 1 bit
0ba7: 5d        mov   x,a               ; then use remaining value as function
0ba8: 1f 65 0b  jmp   ($0b65+x)         ; Goes into FuncJumptable
                                        ; Command range is $b1~$bf

StoreDrvSetting:                        ; A = Value, Y = Channel work area Ptr
0bab: d7 10     mov   (CHAN_PTR)+y,a

AddCmdLenResetNoteTicks:
0bad: ab 16     inc   CMD_PARAM_OFC

ResetNoteTicks:
0baf: 8d 05     mov   y,#NOTE_LEN       ; Note Len
0bb1: f7 10     mov   a,(CHAN_PTR)+y    ; A = Note length
0bb3: 8d 04     mov   y,#REMAIN_LEN     ; Remaining note length
0bb5: d7 10     mov   (CHAN_PTR)+y,a    ; REMAIN_LEN = A

; Funny, after each tick we update track pointer, even if it's just
UpdateSeqPtr:
0bb7: 8d 00     mov   y,#0
0bb9: e4 16     mov   a,CMD_PARAM_OFC
0bbb: 7a 14     addw  ya,CUR_SEQ_PTR    ; YA = Number of commands processed-1
0bbd: 6d        push  y                 ; Push segment addr
0bbe: 8d 02     mov   y,#SEQ_PTR        ;
0bc0: d7 10     mov   (CHAN_PTR)+y,a    ; Store lower byte in driver
0bc2: fc        inc   y                 ; Go to CHAN_PTR_HI
0bc3: ae        pop   a                 ; Pop segment addr
0bc4: d7 10     mov   (CHAN_PTR)+y,a    ; Store upper byte in driver
0bc6: 6f        ret

.ORG $0bc7
FuncJumptable:
	  dw CmdB1                          ; $b1
	  dw CmdB2                          ; $b2
	  dw CmdB3                          ; $b3
	  dw CmdB4                          ; $b4
	  dw SetLoopStart                   ; $b5
	  dw ProcessLoopEnd                 ; $b6
	  dw ResetNoteTicks                 ; $b7
	  dw SetTrackStatusLowNibble        ; $b8  ; Resets instrument table if set to 1?
	  dw SetFineTune                    ; $b9
	  dw SetCoarseTune                  ; $ba
	  dw SetupEcho                      ; $bb
	  dw SetTrackStatusBit4             ; $bc  ; Changing this to 0 disables echo write
	  dw ResetNoteTicks                 ; $bd
	  dw CmdBE                          ; $be
	  dw TrackRest                      ; $bf
	  dw SetSpeed                       ; $c0
	  dw SetInstrument                  ; $c1
	  dw SetVol                         ; $c2
	  dw SetPan                         ; $c3
	  dw SetVibratoSpeed                ; $c4
	  dw SetVibratoLevel                ; $c5
	  dw ResetNoteTicks                 ; $c6
	  dw SetGlobalTune                  ; $c7
	  dw ResetNoteTicks                 ; $c8
	  dw ResetNoteTicks                 ; $c9
	  dw ResetNoteTicks                 ; $ca
	  dw ResetNoteTicks                 ; $cb
	  dw ResetNoteTicks                 ; $cc
	  dw ResetNoteTicks                 ; $cd
	  dw ResetNoteTicks                 ; $cf

; So this command stores argument into $1f, possible for loop?
CmdBE:
0c03: eb 16     mov   y,CMD_PARAM_OFC
0c05: f7 14     mov   a,(CUR_SEQ_PTR)+y
0c07: c4 1f     mov   $1f,a
0c09: 5f ad 0b  jmp   AddCmdLenResetNoteTicks

CmdB3:
0c0c: 8d 0f     mov   y,#WORK_0F
0c0e: f7 10     mov   a,(CHAN_PTR)+y
0c10: 9c        dec   a
0c11: 9c        dec   a
0c12: d7 10     mov   (CHAN_PTR)+y,a
0c14: fd        mov   y,a
0c15: 60        clrc
0c16: e4 16     mov   a,CMD_PARAM_OFC
0c18: bc        inc   a
0c19: bc        inc   a
0c1a: 84 14     adc   a,CUR_SEQ_PTR
0c1c: d7 10     mov   (CHAN_PTR)+y,a
0c1e: fc        inc   y
0c1f: e8 00     mov   a,#$00
0c21: 84 15     adc   a,$15
0c23: d7 10     mov   (CHAN_PTR)+y,a

CmdB2:
0c25: eb 16     mov   y,CMD_PARAM_OFC
0c27: f7 14     mov   a,(CUR_SEQ_PTR)+y
0c29: 2d        push  a
0c2a: fc        inc   y
0c2b: f7 14     mov   a,(CUR_SEQ_PTR)+y
0c2d: fd        mov   y,a
0c2e: ae        pop   a
0c2f: da 14     movw  CUR_SEQ_PTR,ya
0c31: 8f 00 16  mov   CMD_PARAM_OFC,#$00
0c34: 5f b7 0b  jmp   UpdateSeqPtr

CmdB4:
0c37: 8d 0f     mov   y,#WORK_0F
0c39: f7 10     mov   a,(CHAN_PTR)+y
0c3b: 68 40     cmp   a,#$40
0c3d: b0 f5     bcs   $0c34
0c3f: 2d        push  a
0c40: bc        inc   a
0c41: bc        inc   a
0c42: d7 10     mov   (CHAN_PTR)+y,a
0c44: ee        pop   y
0c45: f7 10     mov   a,(CHAN_PTR)+y
0c47: c4 14     mov   CUR_SEQ_PTR,a
0c49: fc        inc   y
0c4a: f7 10     mov   a,(CHAN_PTR)+y
0c4c: c4 15     mov   $15,a
0c4e: 2f e1     bra   $0c31

SetLoopStart:
0c50: 8d 1a     mov   y,#PLAY_MODE
0c52: f7 10     mov   a,(CHAN_PTR)+y
0c54: fd        mov   y,a
0c55: 60        clrc
0c56: e4 16     mov   a,CMD_PARAM_OFC
0c58: 84 14     adc   a,CUR_SEQ_PTR
0c5a: d7 10     mov   (CHAN_PTR)+y,a
0c5c: fc        inc   y
0c5d: e8 00     mov   a,#0
0c5f: 84 15     adc   a,$15
0c61: d7 10     mov   (CHAN_PTR)+y,a
0c63: fc        inc   y
0c64: e8 01     mov   a,#RAW_CMD
0c66: d7 10     mov   (CHAN_PTR)+y,a
0c68: fc        inc   y
0c69: dd        mov   a,y
0c6a: 8d 1a     mov   y,#PLAY_MODE
0c6c: d7 10     mov   (CHAN_PTR)+y,a
0c6e: 5f b7 0b  jmp   UpdateSeqPtr

ProcessLoopEnd:
0c71: 8d 1a     mov   y,#PLAY_MODE
0c73: f7 10     mov   a,(CHAN_PTR)+y
0c75: 68 25     cmp   a,#$25            ; See if we are inside loop
0c77: 90 29     bcc   $0ca2             ; and ignore loop set command?

0c79: 2d        push  a
0c7a: eb 16     mov   y,CMD_PARAM_OFC
0c7c: f7 14     mov   a,(CUR_SEQ_PTR)+y
0c7e: ee        pop   y
0c7f: dc        dec   y
0c80: 77 10     cmp   a,(CHAN_PTR)+y
0c82: f0 17     beq   $0c9b
0c84: 90 05     bcc   $0c8b
0c86: f7 10     mov   a,(CHAN_PTR)+y
0c88: bc        inc   a
0c89: d7 10     mov   (CHAN_PTR)+y,a
0c8b: dc        dec   y
0c8c: f7 10     mov   a,(CHAN_PTR)+y
0c8e: c4 15     mov   $15,a
0c90: dc        dec   y
0c91: f7 10     mov   a,(CHAN_PTR)+y
0c93: c4 14     mov   CUR_SEQ_PTR,a
0c95: 8f 00 16  mov   CMD_PARAM_OFC,#$00
0c98: 5f b7 0b  jmp   UpdateSeqPtr
0c9b: dc        dec   y
0c9c: dc        dec   y
0c9d: dd        mov   a,y
0c9e: 8d 1a     mov   y,#PLAY_MODE
0ca0: d7 10     mov   (CHAN_PTR)+y,a

0ca2: ab 16     inc   CMD_PARAM_OFC
0ca4: 5f b7 0b  jmp   UpdateSeqPtr

SetTrackStatusLowNibble:
0ca7: eb 16     mov   y,CMD_PARAM_OFC
0ca9: f7 14     mov   a,(CUR_SEQ_PTR)+y
0cab: 28 0f     and   a,#$0f             ; Get only lower nibble
0cad: 8d 00     mov   y,#TRACK_STATUS    ; Load track status
0caf: 17 10     or    a,(CHAN_PTR)+y     ; Set lower nibble of track status with this
0cb1: 5f ab 0b  jmp   StoreDrvSetting

SetGlobalTune
0cb4: eb 16     mov   y,CMD_PARAM_OFC
0cb6: f7 14     mov   a,(CUR_SEQ_PTR)+y
0cb8: 1c        asl   a
0cb9: 9f        xcn   a
0cba: 2d        push  a
0cbb: 28 0f     and   a,#$0f
0cbd: 80        setc
0cbe: a8 08     sbc   a,#$08
0cc0: 8d 18     mov   y,#COARSE_TUNE2
0cc2: d7 10     mov   (CHAN_PTR)+y,a
0cc4: ae        pop   a
0cc5: 28 e0     and   a,#$e0
0cc7: 8d 19     mov   y,#FINE_TUNE2
0cc9: 2f 12     bra   StoreSettingAndApply

SetFineTune:
0ccb: eb 16     mov   y,CMD_PARAM_OFC
0ccd: f7 14     mov   a,(CUR_SEQ_PTR)+y
0ccf: 1c        asl   a
0cd0: 8d 14     mov   y,#FINE_TUNE
0cd2: 2f 09     bra   StoreSettingAndApply

SetCoarseTune:
0cd4: eb 16     mov   y,CMD_PARAM_OFC
0cd6: f7 14     mov   a,(CUR_SEQ_PTR)+y
0cd8: 80        setc
0cd9: a8 40     sbc   a,#$40
0cdb: 8d 0a     mov   y,#COARSE_TUNE

StoreSettingAndApply:                   ; So there is another one...
0cdd: d7 10     mov   (CHAN_PTR)+y,a
0cdf: d3 12 06  bbc6  CUR_TRACK_STAT,$0ce8
0ce2: 3f a2 0e  call  SetChannelBusyMask
0ce5: 3f 22 0f  call  WritePitch
0ce8: 5f ad 0b  jmp   AddCmdLenResetNoteTicks

SetupEcho:
0ceb: eb 16     mov   y,CMD_PARAM_OFC
0ced: f7 14     mov   a,(CUR_SEQ_PTR)+y ; arg1: Raw echo volume
0cef: 8d 2c     mov   y,#DSP_EVOLL      ; Echo VolL
0cf1: 3f 92 0a  call  WriteDSP
0cf4: 8d 3c     mov   y,#DSP_EVOLR      ; Echo VolR
0cf6: 3f 92 0a  call  WriteDSP
0cf9: ab 16     inc   CMD_PARAM_OFC
0cfb: eb 16     mov   y,CMD_PARAM_OFC
0cfd: f7 14     mov   a,(CUR_SEQ_PTR)+y ; arg2: Echo delay
0cff: 68 04     cmp   a,#4
0d01: 90 02     bcc   $0d05
0d03: e8 04     mov   a,#4              ; if delay < 4, delay = 4

0d05: 8d 7d     mov   y,#DSP_EDL        ; Echo delay set
0d07: 3f 92 0a  call  WriteDSP
0d0a: ab 16     inc   CMD_PARAM_OFC
0d0c: eb 16     mov   y,CMD_PARAM_OFC
0d0e: f7 14     mov   a,(CUR_SEQ_PTR)+y ; arg3: Echo feedback
0d10: 8d 0d     mov   y,#DSP_EFB        ; Echo feedback
0d12: 3f 92 0a  call  WriteDSP
0d15: 5f ad 0b  jmp   AddCmdLenResetNoteTicks

SetTrackStatusBit4:
0d18: eb 16     mov   y,CMD_PARAM_OFC
0d1a: f7 14     mov   a,(CUR_SEQ_PTR)+y
0d1c: f0 09     beq   $0d27             ; A == 0?

0d1e: e8 10     mov   a,#$10
0d20: 8d 00     mov   y,#TRACK_STATUS
0d22: 17 10     or    a,(CHAN_PTR)+y    ; TRACK_STATUS | %00010000 if A != 0
0d24: 5f ab 0b  jmp   StoreDrvSetting

0d27: e8 ef     mov   a,#$ef
0d29: 8d 00     mov   y,#TRACK_STATUS
0d2b: 37 10     and   a,(CHAN_PTR)+y    ; TRACK_STATUS & %11101111 if A == 0
0d2d: 5f ab 0b  jmp   StoreDrvSetting

SetSpeed:
0d30: 03 17 12  bbs0  DRV_FLAGS,$0d45   ; Ignore if bit0 at $17 is set
0d33: e8 01     mov   a,#START_TIM0
0d35: c5 f1 00  mov   DSP_CTRL,a
0d38: eb 16     mov   y,CMD_PARAM_OFC
0d3a: f7 14     mov   a,(CUR_SEQ_PTR)+y
0d3c: 5d        mov   x,a               ; X = arg
0d3d: 8d 13     mov   y,#$13
0d3f: e8 88     mov   a,#$88             ; $1388 == 5000
0d41: 9e        div   ya,x              ; Y= 5000 % X; A = 5000 / X
0d42: 3f 48 0d  call  SetStartTimer1
0d45: 5f ad 0b  jmp   AddCmdLenResetNoteTicks

SetStartTimer1:
0d48: c5 fb 00  mov   TIMER1,a
0d4b: c4 01     mov   $01,a
0d4d: e8 03     mov   a,#START_TIM0 & START_TIM1
0d4f: c5 f1 00  mov   DSP_CTRL,a
0d52: 6f        ret

SetInstrument:
0d53: eb 16     mov   y,CMD_PARAM_OFC
0d55: f7 14     mov   a,(CUR_SEQ_PTR)+y
0d57: 3f 5d 0d  call  TransferDSPInstr
0d5a: 5f ad 0b  jmp   AddCmdLenResetNoteTicks

TransferDSPInstr:
0d5d: 8d 06     mov   y,#$06
0d5f: cf        mul   ya
0d60: da d0     movw  $d0,ya
0d62: 8d 3e     mov   y,#$3e
0d64: e8 00     mov   a,#$00
0d66: 7a d0     addw  ya,$d0
0d68: da d0     movw  $d0,ya
0d6a: cd 00     mov   x,#$00

; Setup first register from driver work area
0d6c: 8d 1c     mov   y,#SPC_SCRN     ; Transfers values stored at $1c-$21
                                      ; As DSP channel registers.
0d6e: e7 d0     mov   a,($d0+x)       ; SCRN,
0d70: 3a d0     incw  $d0             ; ADSR1
0d72: d7 10     mov   (CHAN_PTR)+y,a  ; ADSR2
0d74: fc        inc   y               ; GAIN
0d75: ad 22     cmp   y,#SEQ_START    ; Loop end cmp
0d77: 90 f5     bcc   $0d6e           ;
0d79: 6f        ret

SetPan:
0d7a: eb 16     mov   y,CMD_PARAM_OFC
0d7c: f7 14     mov   a,(CUR_SEQ_PTR)+y
0d7e: 1c        asl   a
0d7f: 8d 13     mov   y,#PAN_TMP
0d81: d7 10     mov   (CHAN_PTR)+y,a
0d83: 2f 0c     bra   $0d91

SetVol:
0d85: eb 16     mov   y,CMD_PARAM_OFC
0d87: f7 14     mov   a,(CUR_SEQ_PTR)+y
0d89: 8d 12     mov   y,#VOLUME_LEV
0d8b: d7 10     mov   (CHAN_PTR)+y,a
0d8d: 8d 13     mov   y,#PAN_TMP          ;
0d8f: f7 10     mov   a,(CHAN_PTR)+y      ; Load W13 to A

0d91: c4 d0     mov   DRV_TMP_LO,a
0d93: 48 ff     eor   a,#$ff
0d95: c4 d1     mov   DRV_TMP_HI,a
0d97: 8d 12     mov   y,#VOLUME_LEV
0d99: f7 10     mov   a,(CHAN_PTR)+y
0d9b: 2d        push  a
0d9c: eb d0     mov   y,DRV_TMP_LO
0d9e: cf        mul   ya
0d9f: dd        mov   a,y
0da0: 8d 10     mov   y,#VOLUME_OUT_L
0da2: d7 10     mov   (CHAN_PTR)+y,a
0da4: ae        pop   a
0da5: eb d1     mov   y,DRV_TMP_HI
0da7: cf        mul   ya
0da8: dd        mov   a,y
0da9: 8d 11     mov   y,#VOLUME_OUT_L
0dab: d7 10     mov   (CHAN_PTR)+y,a
0dad: d3 12 06  bbc6  CUR_TRACK_STAT,$0db6
0db0: 3f a2 0e  call  SetChannelBusyMask
0db3: 3f b0 0e  call  SetupVolume
0db6: 5f ad 0b  jmp   AddCmdLenResetNoteTicks

SetVibratoSpeed:
0db9: eb 16     mov   y,CMD_PARAM_OFC
0dbb: f7 14     mov   a,(CUR_SEQ_PTR)+y
0dbd: 8d 0e     mov   y,#VIBRATO_SPD
0dbf: 5f ab 0b  jmp   StoreDrvSetting

SetVibratoLevel:
0dc2: eb 16     mov   y,CMD_PARAM_OFC
0dc4: f7 14     mov   a,(CUR_SEQ_PTR)+y
0dc6: 1c        asl   a
0dc7: 8d 15     mov   y,#VIBRATO_LEV
0dc9: 5f ab 0b  jmp   StoreDrvSetting

TrackRest:
0dcc: d3 12 03  bbc6  $12,$0dd2
0dcf: 3f a5 0a  call  ResetTrackStatus
0dd2: 5f af 0b  jmp   ResetNoteTicks

ProcessNoteCmd:
0dd5: 80        setc                    ; $ff ≥ A ≥ $cf
0dd6: a8 d0     sbc   a,#d0             ; substract $d0 from note param
0dd8: 8d 08     mov   y,#NOTE_NUM
0dda: d7 10     mov   (CHAN_PTR)+y,a
0ddc: 8f 00 d8  mov   $d8,#0            ; Reset flag at $d8
0ddf: eb 16     mov   y,CMD_PARAM_OFC
0de1: f7 14     mov   a,(CUR_SEQ_PTR)+y ; Load first byte after CMD
0de3: 30 21     bmi   $0e06             ; jump if A > $7f, so argument is 0-7f
0de5: 68 31     cmp   a,#$31
0de7: b0 0d     bcs   $0df6             ; A ≥ $31?
0de9: 03 d8 1a  bbs0  $d8,$0e06         ; If bit 0 at $d8 is set, jump
0dec: 02 d8     set0  $d8               ; Set bit 0 at $d8, param is < $31
0dee: ab 16     inc   CMD_PARAM_OFC
0df0: 8d 07     mov   y,#NOTE_CUT       ; No need to substract, store as note cut
0df2: d7 10     mov   (CHAN_PTR)+y,a
0df4: 2f e9     bra   $0ddf

0df6: 23 d8 0d  bbs1  $d8,$0e06         ; If bit 1 is set at $d8, ignore
0df9: 22 d8     set1  $d8               ; Set bit 1 at $d8, param is $31 ≤ PP ≤ $7f
0dfb: ab 16     inc   CMD_PARAM_OFC
0dfd: 80        setc
0dfe: a8 31     sbc   a,#$31            ; Substract $31 from parameter
0e00: 8d 09     mov   y,#NOTE_VEL
0e02: d7 10     mov   (CHAN_PTR)+y,a    ; Store velocity for this note
0e04: 2f d9     bra   $0ddf

; We got here after reading note parameters, if any
0e06: d3 12 08  bbc6  CUR_TRACK_STAT,$0e11
0e09: 8d 06     mov   y,#REMAIN_CUT
0e0b: f7 10     mov   a,(CHAN_PTR)+y    ; If bit 6 is set we load remaining note cut into
0e0d: d0 02     bne   $0e11             ; A and jump if note cut timer is 0
0e0f: a2 12     set5  CUR_TRACK_STAT    ; bit5 - cut timer nonzero?

0e11: 8d 07     mov   y,#NOTE_CUT
0e13: f7 10     mov   a,(CHAN_PTR)+y
0e15: 78 01 1f  cmp   $1f,#$01          ; Set by CmdBE
0e18: f0 04     beq   $0e1e
0e1a: 5d        mov   x,a
0e1b: f5 ac 10  mov   a,NoteLenTbl+x    ; Load note cut value from table into A

0e1e: 8d 06     mov   y,#REMAIN_CUT
0e20: d7 10     mov   (CHAN_PTR)+y,a
0e22: 3f c1 08  call  CheckSFX
0e25: a3 12 1e  bbs5  CUR_TRACK_STAT,JmpResNoteTicks ; Jump if remaining note cut is nonzero
0e28: c3 12 09  bbs6  CUR_TRACK_STAT,$0e34  ; Reset channel status if b6 is set, hm
0e2b: 3f ca 0f  call  $0fca                 ; Possible check for chan reallocaction need
0e2e: 30 16     bmi   JmpResNoteTicks       ; Branch on negative flag after call
0e30: 8d 0b     mov   y,#DSP_CHANNEL
0e32: d7 10     mov   (CHAN_PTR)+y,a        ; A contains new output channel

0e34: 8d 00     mov   y,#TRACK_STATUS
0e36: f7 10     mov   a,(CHAN_PTR)+y
0e38: 08 60     or    a,#$60            ; %01100000
0e3a: d7 10     mov   (CHAN_PTR)+y,a    ; Set channel bits 5 and 6, making it busy
0e3c: 3f a2 0e  call  SetChannelBusyMask
0e3f: 8d 5c     mov   y,#DSP_KOF
0e41: e4 0a     mov   a,$0a
0e43: 3f 92 0a  call  WriteDSP

JmpResNoteTicks:
0e46: 5f af 0b  jmp   ResetNoteTicks

0e49: 3f a2 0e  call  SetChannelBusyMask
0e4c: 3f b0 0e  call  SetupVolume
0e4f: 13 12 07  bbc0  CUR_TRACK_STAT,$0e59
0e52: 8d 08     mov   y,#NOTE_NUM
0e54: f7 10     mov   a,(CHAN_PTR)+y
0e56: 3f 5d 0d  call  TransferDSPInstr
0e59: 3f 0a 0f  call  $0f0a
0e5c: 3f c1 08  call  CheckSFX
0e5f: 8d 08     mov   y,#NOTE_NUM
0e61: f7 10     mov   a,(CHAN_PTR)+y
0e63: 10 0d     bpl   $0e72
0e65: e4 0a     mov   a,$0a
0e67: 04 07     or    a,$07
0e69: c4 07     mov   $07,a
0e6b: 8d 3d     mov   y,#$3d
0e6d: 3f 92 0a  call  WriteDSP
0e70: 2f 15     bra   $0e87
0e72: 13 12 02  bbc0  CUR_TRACK_STAT,$0e77
0e75: e8 24     mov   a,#WORK_24
0e77: 3f 26 0f  call  WritePitchNoBase
0e7a: 8d 3d     mov   y,#$3d
0e7c: e4 0a     mov   a,$0a
0e7e: 48 ff     eor   a,#$ff
0e80: 24 07     and   a,$07
0e82: c4 07     mov   $07,a
0e84: 3f 92 0a  call  WriteDSP
0e87: e4 0a     mov   a,$0a
0e89: 93 12 04  bbc4  CUR_TRACK_STAT,$0e90
0e8c: 04 08     or    a,$08
0e8e: 2f 04     bra   $0e94
0e90: 48 ff     eor   a,#$ff
0e92: 24 08     and   a,$08
0e94: c4 08     mov   $08,a
0e96: 8d 4d     mov   y,#$4d
0e98: 3f 92 0a  call  WriteDSP
0e9b: 8d 4c     mov   y,#DSP_KON
0e9d: e4 0a     mov   a,$0a
0e9f: 5f 92 0a  jmp   WriteDSP

SetChannelBusyMask:                     ; Not sure
0ea2: 8d 0b     mov   y,#DSP_CHANNEL
0ea4: f7 10     mov   a,(CHAN_PTR)+y
0ea6: 5d        mov   x,a
0ea7: 9f        xcn   a                 ; Exchanges X register nibbles
0ea8: c4 09     mov   WRITE_MASK,a
0eaa: f5 8a 10  mov   a,Power2+x
0ead: c4 0a     mov   $0a,a
0eaf: 6f        ret

SetupVolume:
0eb0: 8d 10     mov   y,#VOLUME_OUT_L
0eb2: f7 10     mov   a,(CHAN_PTR)+y
0eb4: c4 d6     mov   $d6,a             ; $D6 = Vol_L
0eb6: 8d 11     mov   y,#VOLUME_OUT_R
0eb8: f7 10     mov   a,(CHAN_PTR)+y
0eba: c4 d7     mov   $d7,a             ; $D6 = Vol_R
0ebc: 03 17 14  bbs0  DRV_FLAGS,$0ed3
0ebf: e4 22     mov   a,$22
0ec1: f0 10     beq   $0ed3
0ec3: e4 d6     mov   a,$d6
0ec5: eb 23     mov   y,$23
0ec7: cf        mul   ya                ; YA = $23 * Vol_L
0ec8: dd        mov   a,y               ; save only upper multiplication value
0ec9: c4 d6     mov   $d6,a             ; store back into Vol_L
0ecb: e4 d7     mov   a,$d7
0ecd: eb 23     mov   y,$23
0ecf: cf        mul   ya                ; YA = $23 * Vol_R
0ed0: dd        mov   a,y               ; save only upper multiplication value
0ed1: c4 d7     mov   $d7,a             ; store back into Vol_R

0ed3: cd 32     mov   x,#$32
0ed5: 8d 09     mov   y,#NOTE_VEL
0ed7: f7 10     mov   a,(CHAN_PTR)+y
0ed9: 2d        push  a
0eda: eb d6     mov   y,$d6
0edc: cf        mul   ya
0edd: 9e        div   ya,x
0ede: 10 02     bpl   $0ee2
0ee0: e8 7f     mov   a,#$7f
0ee2: c4 d6     mov   $d6,a
0ee4: ae        pop   a
0ee5: eb d7     mov   y,$d7
0ee7: cf        mul   ya
0ee8: 9e        div   ya,x
0ee9: 10 02     bpl   $0eed
0eeb: e8 7f     mov   a,#$7f
0eed: c4 d7     mov   $d7,a
0eef: 13 25 0a  bbc0  $25,$0efc
0ef2: 60        clrc
0ef3: e4 d6     mov   a,$d6
0ef5: 84 d7     adc   a,$d7
0ef7: 5c        lsr   a
0ef8: c4 d6     mov   $d6,a
0efa: c4 d7     mov   $d7,a
0efc: 8d 00     mov   y,#$00
0efe: e4 d6     mov   a,$d6
0f00: 3f 99 0a  call  WriteMasked
0f03: 8d 01     mov   y,#$01
0f05: e4 d7     mov   a,$d7
0f07: 5f 99 0a  jmp   WriteMasked
0f0a: 8f 1c d8  mov   $d8,#SPC_SCRN
0f0d: 8f 04 d9  mov   $d9,#$04
0f10: eb d8     mov   y,$d8
0f12: f7 10     mov   a,(CHAN_PTR)+y
0f14: eb d9     mov   y,$d9
0f16: 3f 99 0a  call  WriteMasked
0f19: ab d8     inc   $d8
0f1b: ab d9     inc   $d9
0f1d: ad 07     cmp   y,#$07
0f1f: 90 ef     bcc   $0f10
0f21: 6f        ret

WritePitch:
0f22: 8d 08     mov   y,#NOTE_NUM
0f24: f7 10     mov   a,(CHAN_PTR)+y

WritePitchNoBase:
0f26: 60        clrc                    ; Reset Carry
0f27: 88 18     adc   a,#$18            ; A = A+24
0f29: 60        clrc                    ; don't care about overflow
0f2a: 8d 0a     mov   y,#COARSE_TUNE
0f2c: 97 10     adc   a,(CHAN_PTR)+y    ; Add coarse tuning to A
0f2e: 60        clrc                    ; don't care about overflow
0f2f: 8d 16     mov   y,#DRVPARAM_TMP
0f31: 97 10     adc   a,(CHAN_PTR)+y    ; A += Tone offset (from vibrato?)
0f33: 60        clrc                    ; don't care about overflow
0f34: 8d 18     mov   y,#COARSE_TUNE2
0f36: 97 10     adc   a,(CHAN_PTR)+y    ; Add second coarse tuning (from instr def?)
0f38: 1c        asl   a                 ; A*2, so we get even offsets
0f39: 8d 00     mov   y,#$00            ; Y = 0
0f3b: cd 18     mov   x,#$18            ; X = 24
0f3d: 9e        div   ya,x
0f3e: 5d        mov   x,a               ; X = A/24 (Y is 0, so we don't care)
0f3f: f6 93 10  mov   a,PitchTable+1+y  ; Y = A%24
0f42: c4 d1     mov   DRV_TMP_HI,a      ; $d1 = high pitch byte
0f44: f6 92 10  mov   a,PitchTable+y
0f47: c4 d0     mov   CUR_PITCH,a       ; $d0 = low pitch byte
0f49: f6 95 10  mov   a,PitchTable+3+y  ; Load and store next semitone low
0f4c: 2d        push  a
0f4d: f6 94 10  mov   a,PitchTable+2+y
0f50: ee        pop   y
0f51: 9a d0     subw  ya,DRV_TMP_LO
0f53: c4 d2     mov   NXT_PITCH_LO,a
0f55: 8d 14     mov   y,#FINE_TUNE
0f57: f7 10     mov   a,(CHAN_PTR)+y
0f59: 8f 00 d3  mov   NXT_PITCH_HI,#$00
0f5c: 60        clrc
0f5d: 8d 17     mov   y,#DRVPARAM_TMP2
0f5f: 97 10     adc   a,(CHAN_PTR)+y
0f61: 98 00 d3  adc   NXT_PITCH_HI,#$00
0f64: 60        clrc
0f65: 8d 19     mov   y,#FINE_TUNE2
0f67: 97 10     adc   a,(CHAN_PTR)+y
0f69: 98 00 d3  adc   NXT_PITCH_HI,#$00
0f6c: eb d2     mov   y,NXT_PITCH_LO
0f6e: cf        mul   ya
0f6f: 6d        push  y
0f70: ba d2     movw  ya,NXT_PITCH_LO
0f72: cf        mul   ya
0f73: 7a d0     addw  ya,DRV_TMP_LO
0f75: da d0     movw  DRV_TMP_LO,ya
0f77: ae        pop   a
0f78: 8d 00     mov   y,#$00
0f7a: 7a d0     addw  ya,DRV_TMP_LO
0f7c: da d0     movw  DRV_TMP_LO,ya
0f7e: 0b d0     asl   DRV_TMP_LO
0f80: 2b d1     rol   DRV_TMP_HI
0f82: c8 08     cmp   x,#$08
0f84: b0 07     bcs   $0f8d
0f86: 4b d1     lsr   DRV_TMP_HI
0f88: 6b d0     ror   DRV_TMP_LO
0f8a: 3d        inc   x
0f8b: 2f f5     bra   $0f82
0f8d: 3f c1 08  call  CheckSFX
0f90: 8d 20     mov   y,#FREQ_MULT
0f92: f7 10     mov   a,(CHAN_PTR)+y
0f94: c4 d3     mov   NXT_PITCH_HI,a
0f96: fc        inc   y
0f97: f7 10     mov   a,(CHAN_PTR)+y
0f99: c4 d2     mov   NXT_PITCH_LO,a
0f9b: e4 d2     mov   a,NXT_PITCH_LO
0f9d: eb d1     mov   y,DRV_TMP_HI
0f9f: cf        mul   ya
0fa0: da d4     movw  $d4,ya
0fa2: e4 d2     mov   a,NXT_PITCH_LO
0fa4: eb d0     mov   y,DRV_TMP_LO
0fa6: cf        mul   ya
0fa7: 6d        push  y
0fa8: e4 d3     mov   a,NXT_PITCH_HI
0faa: eb d0     mov   y,DRV_TMP_LO
0fac: cf        mul   ya
0fad: 7a d4     addw  ya,$d4
0faf: da d4     movw  $d4,ya
0fb1: e4 d3     mov   a,NXT_PITCH_HI
0fb3: eb d1     mov   y,DRV_TMP_HI
0fb5: cf        mul   ya
0fb6: fd        mov   y,a
0fb7: ae        pop   a
0fb8: 7a d4     addw  ya,$d4
0fba: da d4     movw  $d4,ya
0fbc: 8d 02     mov   y,#$02
0fbe: e4 d4     mov   a,$d4
0fc0: 3f 99 0a  call  WriteMasked
0fc3: 8d 03     mov   y,#$03
0fc5: e4 d5     mov   a,$d5
0fc7: 5f 99 0a  jmp   WriteMasked

0fca: 13 17 04  bbc0  DRV_FLAGS,$0fd1   ; Branch if b0 is unset
0fcd: 8d 7f     mov   y,#$7f            ; set Y to 0b01111111
0fcf: 2f 02     bra   $0fd3             ; Ignore current music track n
0fd1: eb 13     mov   y,CUR_TRACK       ; Get current music track num
0fd3: cd 00     mov   x,#0
0fd5: cb d8     mov   $d8,y             ; Store current track being used to $d8
0fd7: 8f ff d9  mov   $d9,#$ff          ; Set all bits on $d8

0fda: f4 c0     mov   a,DSP_CHAN_STAT+x ; Read DSP 0 channel status
0fdc: f0 12     beq   $0ff0             ; Jump if A > $7F
0fde: 64 d8     cmp   a,$d8             ; Current track num is here
0fe0: b0 04     bcs   $0fe6             ; Jump if A >= $D8
0fe2: c4 d8     mov   $d8,a             ; Store track back to $d8
0fe4: d8 d9     mov   $d9,x             ; Store chan status to $d9
0fe6: 3d        inc   x                 ; next X
0fe7: c8 08     cmp   x,#8
0fe9: 90 ef     bcc   $0fda             ; Loop if X < 8

0feb: f8 d9     mov   x,$d9             ; X will be our output channel?
0fed: 10 05     bpl   $0ff4
0fef: 6f        ret

0ff0: db c0     mov   DSP_CHAN_STAT+x,y
0ff2: 7d        mov   a,x
0ff3: 6f        ret

0ff4: db c0     mov   DSP_CHAN_STAT+x,y
0ff6: e8 08     mov   a,#$08
0ff8: 80        setc
0ff9: a4 d8     sbc   a,$d8
0ffb: 8d 40     mov   y,#$40
0ffd: cf        mul   ya
0ffe: da d0     movw  DRV_TMP_LO,ya
1000: 8d 06     mov   y,#$06
1002: e8 00     mov   a,#$00
1004: 7a d0     addw  ya,DRV_TMP_LO
1006: da d0     movw  DRV_TMP_LO,ya
1008: 8d 00     mov   y,#$00
100a: f7 d0     mov   a,(DRV_TMP_LO)+y
100c: 28 9f     and   a,#$9f
100e: d7 d0     mov   (DRV_TMP_LO)+y,a
1010: 7d        mov   a,x
1011: 6f        ret

UpdateVibrato:
1012: 3f c1 08  call  CheckSFX
1015: 8d 0e     mov   y,#VIBRATO_SPD
1017: f7 10     mov   a,(CHAN_PTR)+y
1019: 60        clrc
101a: 8d 0d     mov   y,#CUR_DETUNE
101c: 97 10     adc   a,(CHAN_PTR)+y
101e: d7 10     mov   (CHAN_PTR)+y,a
1020: 1c        asl   a
1021: 90 02     bcc   $1025
1023: 48 ff     eor   a,#$ff
1025: c4 d0     mov   DRV_TMP_LO,a
1027: 8d 15     mov   y,#VIBRATO_LEV
1029: f7 10     mov   a,(CHAN_PTR)+y
102b: f0 1f     beq   $104c
102d: c4 d1     mov   DRV_TMP_HI,a
102f: 5c        lsr   a
1030: c4 d2     mov   NXT_PITCH_LO,a
1032: ba d0     movw  ya,DRV_TMP_LO
1034: cf        mul   ya
1035: dd        mov   a,y
1036: 8d 00     mov   y,#$00
1038: cb d3     mov   NXT_PITCH_HI,y
103a: 9a d2     subw  ya,NXT_PITCH_LO
103c: 6d        push  y
103d: 8d 17     mov   y,#DRVPARAM_TMP2
103f: d7 10     mov   (CHAN_PTR)+y,a
1041: ae        pop   a
1042: 8d 16     mov   y,#DRVPARAM_TMP
1044: d7 10     mov   (CHAN_PTR)+y,a
1046: 3f a2 0e  call  SetChannelBusyMask
1049: 3f 22 0f  call  WritePitch
104c: 6f        ret

.ORG $104d
DSPInitData:
	  ; DSP Init sequence in ADDR, VAL, 0x22 bytes
	  ; Flag Register: Reset=1, Mute=1, Echo=1, NoiseCLK=$12 (800Hz)
      db DSP_FLG, $f2
      ; DSP Echo buffer segment, $df00
      db DSP_ESA, $df
      ; Echo Delay
      db DSP_EDL, $04
      ; Instrument Source directory, $3c00
      db $5d, $3c
      ; Pitch modulation enable
      db $2d, $00
      ; Left volume main
      db $0c, $7f
      ; Right volume main
      db $1c, $7f
      ; Echo volume left
      db $2c, $00
      ; Echo volume right
      db $3c, $00
      ; FIR Filter setup
      db DSP_C0, $7f
      db DSP_C1, $00
      db DSP_C2, $00
      db DSP_C3, $00
      db DSP_C4, $00
      db DSP_C5, $00
      db DSP_C6, $00
      db DSP_C7, $00

.ORG $106F
Data106f:
      db $80

1070: $00,
1071: $00,
1072: $00,
1073: $00,
1074: $00,
1075: $00,
1076: $00,
1077: $00,
1078: $32,
1079: $00,
107a: $00,
107b: $00,
107c: $00,
107d: $14,
107e: $40,
107f: $7f,
1080: $7f,
1081: $7f,
1082: $80,
1083: $80,
1084: $00,
1085: $00,
1086: $00,
1087: $00,
1088: $00,
1089: $22,

.ORG $108a
Power2:
      db $01, $02, $04, $08, $10, $20, $40, $80,

.ORG $1092
PitchTable:
      db $5f, $08, ; 2143Hz C
      db $de, $08, ; 2270Hz C♯
      db $65, $09, ; 2405Hz D
      db $f4, $09, ; 2548Hz D♯
      db $8c, $0a, ; 2700Hz E
      db $2c, $0b, ; 2860Hz F
      db $d6, $0b, ; 3030Hz F♯
      db $8b, $0c, ; 3211Hz G
      db $4a, $0d, ; 3402Hz G♯
      db $14, $0e, ; 3604Hz A  // 450.5Hz tune ref
      db $ea, $0e, ; 3818Hz A♯
      db $cd, $0f, ; 4045Hz B
      db $be, $10, ; 4286Hz C

.ORG $10ac
NoteLenTbl:
      db $00, $01, $02, $03, $04, $05, $06, $07,
      db $08, $09, $0a, $0b, $0c, $0e, $10, $12,
      db $14, $16, $18, $1a, $1c, $1e, $20, $22,
      db $24, $26, $28, $2a, $2c, $2e, $30, $3c,
      db $40, $48, $50, $54, $60, $6c, $70, $78,
      db $80, $84, $90, $9c, $a0, $a8, $b0, $b4, $c0,


10dd: $00,
10de: $14,
10df: $00,
10e0: $c8,


; Data split by pointer updates
; as seen by stopping at $0b6b
; Track 1
═════════╤════════════════
1412   +1│∙ 80
1413   +2│∙ c0 3f
1415   +4│∙ bb 46 04 32
1419   +2│∙ bc 7f
141B   +2│∙ b8 00
141D   +2│∙ ba 4c
141F   +2│∙ c2 10
1421   +2│∙ c5 15
1423   +2│∙ c3 22
1425   +2│∙ c1 01
1427   +1│∙ b5
1428   +1│∙ 92
1429   +1│∙ bf
142A   +3│∙ f4 62 10
142D   +2│∙ ef 5d
142F   +2│∙ ec 57
1431   +2│∙ ef 62
1433   +2│∙ ed 5d
1435   +2│∙ ea 57
1437   +2│∙ e7 62
1439   +1│∙ a1
143A   +2│∙ e8 21
143C   +1│∙ 92
143D   +3│∙ e3 68 12
1440   +1│∙ a4
1441   +1│∙ bf
1442   +1│∙ 92
1443   +1│∙ bf
1444   +3│∙ f4 62 10
1447   +2│∙ ef 5d
1449   +2│∙ ec 57
144B   +2│∙ ef 62
144D   +2│∙ ed 5d
144F   +2│∙ ea 57
1451   +2│∙ e7 62
1453   +1│∙ a1
1454   +2│∙ e8 21
1456   +1│∙ 92
1457   +3│∙ e3 68 12
145A   +1│∙ a4
145B   +1│∙ bf
145C   +1│∙ 92
145D   +1│∙ bf
145E   +3│∙ f2 62 10
1461   +2│∙ ef 5d
1463   +2│∙ ea 57
1465   +2│∙ ef 62
1467   +2│∙ ec 5d
1469   +2│∙ e8 57
146B   +2│∙ e6 62
146D   +2│∙ e5 5d
146F   +2│∙ ea 5f
1471   +2│∙ ed 62
1473   +2│∙ f1 68
1475   +1│∙ a4
1476   +1│∙ bf
1477   +1│∙ 92
1478   +2│∙ e7 5d
147A   +2│∙ ea 5f
147C   +2│∙ ef 62
147E   +2│∙ f3 68
1480   +1│∙ a4
1481   +1│∙ bf
1482   +1│∙ 92
1483   +2│∙ e8 5d
1485   +2│∙ ec 5f
1487   +2│∙ ef 62
1489   +1│∙ 9e
148A   +3│∙ f4 68 1e
148D   +1│∙ 92
148E   +3│∙ f3 62 10
1491   +2│∙ ee 57
1493   +3│∙ f1 68 00
1496   +1│∙ 10
1497   +2│∙ ef 62
1499   +2│∙ ea 57
149B   +1│∙ 9e
149C   +3│∙ ed 68 1e
149F   +1│∙ 92
14A0   +3│∙ ec 62 10
14A3   +2│∙ ea 57
14A5   +2│∙ e3 68
14A7   +1│∙ bf
14A8   +2│∙ f4 62
14AA   +2│∙ ef 5d
14AC   +2│∙ ec 57
14AE   +2│∙ ef 62
14B0   +2│∙ ed 5d
14B2   +2│∙ ea 57
14B4   +2│∙ e7 62
14B6   +1│∙ a1
14B7   +2│∙ e8 21
14B9   +1│∙ 92
14BA   +3│∙ e3 68 12
14BD   +1│∙ a4
14BE   +1│∙ bf
14BF   +1│∙ 92
14C0   +1│∙ bf
14C1   +3│∙ f4 62 10
14C4   +2│∙ ef 5d
14C6   +2│∙ ec 57
14C8   +2│∙ ef 62
14CA   +2│∙ ed 5d
14CC   +2│∙ ea 57
14CE   +2│∙ e7 62
14D0   +1│∙ a1
14D1   +2│∙ e8 21
14D3   +1│∙ 92
14D4   +3│∙ e3 68 12
14D7   +1│∙ a4
14D8   +1│∙ bf
14D9   +1│∙ 92
14DA   +1│∙ bf
14DB   +3│∙ f2 62 10
14DE   +2│∙ ef 5d
14E0   +2│∙ ea 57
14E2   +2│∙ ef 62
14E4   +2│∙ ec 5d
14E6   +2│∙ e8 57
14E8   +2│∙ e6 62
14EA   +2│∙ e5 5d
14EC   +2│∙ ea 5f
14EE   +2│∙ ed 62
14F0   +2│∙ f1 68
14F2   +1│∙ a4
14F3   +1│∙ bf
14F4   +1│∙ 92
14F5   +2│∙ e7 5d
14F7   +2│∙ ea 5f
14F9   +2│∙ ef 62
14FB   +2│∙ f3 68
14FD   +1│∙ a4
14FE   +1│∙ bf
14FF   +1│∙ 92
1500   +2│∙ e8 5d
1502   +2│∙ ec 5f
1504   +2│∙ ef 62
1506   +1│∙ 9e
1507   +3│∙ f4 68 1e
150A   +1│∙ 92
150B   +3│∙ f3 62 10
150E   +2│∙ ee 57
1510   +3│∙ f1 68 00
1513   +1│∙ 10
1514   +2│∙ ef 5d
1516   +2│∙ ea 57
1518   +1│∙ 9e
1519   +3│∙ ed 68 1a
151C   +1│∙ 92
151D   +3│∙ ec 57 12
1520   +2│∙ ef 73
1522   +2│∙ ed 68
1524   +1│∙ b0
1525   +1│∙ bf
1526   +1│∙ a7
1527   +1│∙ bf
1528   +1│∙ 92
1529   +2│∙ ec 62
152B   +2│∙ ef 68
152D   +2│∙ ed 62
152F   +1│∙ a1
1530   +3│∙ ec 5d 21
1533   +1│∙ 92
1534   +3│∙ e4 62 12
1537   +1│∙ bf
1538   +2│∙ e6 5d
153A   +2│∙ e8 62
153C   +2│∙ ea 68
153E   +1│∙ a1
153F   +3│∙ eb 5d 1e
1542   +1│∙ 92
1543   +3│∙ f0 68 12
1546   +1│∙ a4
1547   +1│∙ bf
1548   +1│∙ a1
1549   +2│∙ ea 21
154B   +1│∙ 9e
154C   +3│∙ e3 5d 1e
154F   +1│∙ 92
1550   +3│∙ e4 62 12
1553   +2│∙ e6 68
1555   +2│∙ e8 6d
1557   +1│∙ 9e
1558   +3│∙ e9 68 1e
155B   +1│∙ 92
155C   +3│∙ df 5d 12
155F   +2│∙ eb 68
1561   +2│∙ ed 5d
1563   +2│∙ ee 68
1565   +2│∙ ef 5d
1567   +2│∙ f0 68
1569   +1│∙ f1
156A   +2│∙ ea 5d
156C   +2│∙ e5 57
156E   +2│∙ ea 68
1570   +1│∙ a4
1571   +1│∙ bf
1572   +1│∙ 92
1573   +1│∙ f0
1574   +2│∙ ea 5d
1576   +2│∙ e7 57
1578   +2│∙ e4 68
157A   +1│∙ a4
157B   +1│∙ bf
157C -154│◄ b6 00 b1

;Track 2
═════════╤════════════════
157F   +1│∙ 80
1580   +2│∙ bc 7f
1582   +2│∙ b8 00
1584   +2│∙ ba 40
1586   +2│∙ c2 10
1588   +2│∙ c5 14
158A   +2│∙ c3 40
158C   +2│∙ c1 01
158E   +1│∙ b5
158F   +1│∙ 92
1590   +1│∙ bf
1591   +3│∙ fb 62 10
1594   +2│∙ f8 5d
1596   +2│∙ f4 57
1598   +2│∙ f8 62
159A   +2│∙ f6 5d
159C   +2│∙ f3 57
159E   +2│∙ ed 62
15A0   +1│∙ a1
15A1   +2│∙ f1 21
15A3   +1│∙ 92
15A4   +3│∙ ec 68 12
15A7   +1│∙ a4
15A8   +1│∙ bf
15A9   +1│∙ 92
15AA   +1│∙ bf
15AB   +3│∙ fd 62 10
15AE   +2│∙ f8 5d
15B0   +2│∙ f4 57
15B2   +2│∙ f9 62
15B4   +2│∙ f6 5d
15B6   +2│∙ f3 57
15B8   +2│∙ f0 62
15BA   +1│∙ a1
15BB   +2│∙ f1 21
15BD   +1│∙ 92
15BE   +3│∙ ec 68 12
15C1   +1│∙ a4
15C2   +1│∙ bf
15C3   +1│∙ 92
15C4   +1│∙ bf
15C5   +3│∙ fb 62 10
15C8   +2│∙ f6 5d
15CA   +2│∙ f2 57
15CC   +2│∙ f8 62
15CE   +2│∙ f4 5d
15D0   +2│∙ f1 57
15D2   +2│∙ ef 62
15D4   +2│∙ ed 5d
15D6   +2│∙ f1 5f
15D8   +2│∙ f6 62
15DA   +2│∙ f9 68
15DC   +1│∙ a4
15DD   +1│∙ bf
15DE   +1│∙ 92
15DF   +2│∙ ef 5d
15E1   +2│∙ f3 5f
15E3   +2│∙ f6 62
15E5   +2│∙ fb 68
15E7   +1│∙ a4
15E8   +1│∙ bf
15E9   +1│∙ 92
15EA   +2│∙ f1 5d
15EC   +2│∙ f4 5f
15EE   +2│∙ f8 62
15F0   +1│∙ 9e
15F1   +3│∙ fd 68 1e
15F4   +1│∙ 92
15F5   +3│∙ fa 62 10
15F8   +2│∙ f4 57
15FA   +3│∙ f9 68 00
15FD   +1│∙ 10
15FE   +2│∙ f6 62
1600   +2│∙ f3 57
1602   +1│∙ 9e
1603   +3│∙ f4 68 1e
1606   +1│∙ 92
1607   +2│∙ 62 10       ; What is happening here
1609   +2│∙ f3 57
160B   +2│∙ ed 68
160D   +1│∙ bf
160E   +2│∙ fb 62
1610   +2│∙ f8 5d
1612   +2│∙ f4 57
1614   +2│∙ f8 62
1616   +2│∙ f6 5d
1618   +2│∙ f3 57
161A   +2│∙ ed 62
161C   +1│∙ a1
161D   +2│∙ f1 21
161F   +1│∙ 92
1620   +3│∙ ec 68 12
1623   +1│∙ a4
1624   +1│∙ bf
1625   +1│∙ 92
1626   +1│∙ bf
1627   +3│∙ fd 62 10
162A   +2│∙ f8 5d
162C   +2│∙ f4 57
162E   +2│∙ f9 62
1630   +2│∙ f6 5d
1632   +2│∙ f3 57
1634   +2│∙ f0 62
1636   +1│∙ a1
1637   +2│∙ f1 21
1639   +1│∙ 92
163A   +3│∙ ec 68 12
163D   +1│∙ a4
163E   +1│∙ bf
163F   +1│∙ 92
1640   +1│∙ bf
1641   +3│∙ fb 62 10
1644   +2│∙ f6 5d
1646   +2│∙ f2 57
1648   +2│∙ f8 62
164A   +2│∙ f4 5d
164C   +2│∙ f1 57
164E   +2│∙ ef 62
1650   +2│∙ ed 5d
1652   +2│∙ f1 5f
1654   +2│∙ f6 62
1656   +2│∙ f9 68
1658   +1│∙ a4
1659   +1│∙ bf
165A   +1│∙ 92
165B   +2│∙ ef 5d
165D   +2│∙ f3 5f
165F   +2│∙ f6 62
1661   +2│∙ fb 68
1663   +1│∙ a4
1664   +1│∙ bf
1665   +1│∙ 92
1666   +2│∙ f1 5d
1668   +2│∙ f4 5f
166A   +2│∙ f8 62
166C   +1│∙ 9e
166D   +3│∙ fd 68 1e
1670   +1│∙ 92
1671   +3│∙ fa 62 10
1674   +2│∙ f4 57
1676   +3│∙ f9 68 00
1679   +1│∙ 10
167A   +2│∙ f6 5d
167C   +2│∙ f3 57
167E   +1│∙ 9e
167F   +3│∙ f5 68 1a
1682   +1│∙ 92
1683   +2│∙ 57 12     ; Wha, again
1685   +2│∙ f8 73
1687   +2│∙ f5 68
1689   +1│∙ b0
168A   +1│∙ bf
168B   +1│∙ a7
168C   +1│∙ bf
168D   +1│∙ 92
168E   +2│∙ f4 62
1690   +2│∙ f8 68
1692   +2│∙ f6 62
1694   +1│∙ a1
1695   +3│∙ f4 5d 21
1698   +1│∙ 92
1699   +3│∙ ed 62 12
169C   +1│∙ bf
169D   +2│∙ ef 5d
169F   +2│∙ f0 62
16A1   +2│∙ f2 68
16A3   +1│∙ a1
16A4   +3│∙ f2 5d 1e
16A7   +1│∙ 92
16A8   +3│∙ f7 68 12
16AB   +1│∙ a4
16AC   +1│∙ bf
16AD   +1│∙ a3
16AE   +3│∙ f6 5d 23
16B1   +1│∙ 9e
16B2   +3│∙ ef 52 1e
16B5   +1│∙ 92
16B6   +3│∙ f0 57 12
16B9   +2│∙ f2 5d
16BB   +1│∙ 8c
16BC   +3│∙ f4 62 0c
16BF   +1│∙ 9e
16C0   +3│∙ f2 68 1e
16C3   +1│∙ 92
16C4   +3│∙ eb 5d 12
16C7   +2│∙ ee 68
16C9   +2│∙ f2 5d
16CB   +2│∙ fa 68
16CD   +2│∙ f5 5d
16CF   +2│∙ fc 68
16D1   +1│∙ f9
16D2   +2│∙ f6 5d
16D4   +2│∙ f1 57
16D6   +2│∙ ed 68
16D8   +1│∙ a4
16D9   +1│∙ bf
16DA   +1│∙ 92
16DB   +1│∙ f9
16DC   +2│∙ f6 5d
16DE   +2│∙ f3 57
16E0   +2│∙ ec 68
16E2   +1│∙ a4
16E3   +1│∙ bf
16E4 -155│◄ b6 00 b1

; Track 4
═════════╤════════════════
17E1   +1│∙ 80
17E2   +2│∙ bc 7f
17E4   +2│∙ b8 00
17E6   +2│∙ ba 40
17E8   +2│∙ c2 12
17EA   +2│∙ c5 18
17EC   +2│∙ c3 40
17EE   +2│∙ c1 00
17F0   +1│∙ b0
17F1   +1│∙ bf
17F2   +1│∙ b5
17F3   +1│∙ 92
17F4   +1│∙ bf
17F5   +3│∙ e5 52 10
17F8   +2│∙ e8 57
17FA   +2│∙ ea 62
17FC   +1│∙ bf
17FD   +2│∙ e7 52
17FF   +2│∙ ec 57
1801   +2│∙ ef 62
1803   +1│∙ bf
1804   +2│∙ e5 52
1806   +2│∙ e8 57
1808   +2│∙ ec 62
180A   +1│∙ bf
180B   +3│∙ e7 52 12
180E   +2│∙ ea 57
1810   +2│∙ ed 62
1812   +1│∙ bf
1813   +2│∙ e5 52
1815   +2│∙ e8 57
1817   +2│∙ ec 62
1819   +1│∙ bf
181A   +2│∙ e8 52
181C   +2│∙ ec 57
181E   +2│∙ ef 62
1820   +1│∙ bf
1821   +2│∙ e6 52
1823   +2│∙ ea 57
1825   +2│∙ ef 62
1827   +1│∙ bf
1828   +2│∙ e6 52
182A   +2│∙ e8 57
182C   +2│∙ ec 62
182E   +1│∙ bf
182F   +2│∙ e5 52
1831   +2│∙ ea 57
1833   +2│∙ ed 62
1835   +1│∙ bf
1836   +2│∙ ea 52
1838   +2│∙ ed 57
183A   +2│∙ f1 62
183C   +1│∙ bf
183D   +2│∙ e7 52
183F   +2│∙ ec 57
1841   +2│∙ ef 62
1843   +1│∙ bf
1844   +2│∙ ec 52
1846   +2│∙ ef 57
1848   +2│∙ f3 62
184A   +1│∙ bf
184B   +2│∙ e8 52
184D   +2│∙ ec 57
184F   +2│∙ f1 62
1851   +1│∙ bf
1852   +2│∙ ee 52
1854   +2│∙ f1 57
1856   +2│∙ f6 62
1858   +1│∙ bf
1859   +2│∙ ef 57
185B   +2│∙ f3 62
185D   +1│∙ 9e
185E   +3│∙ ea 57 1e
1861   +1│∙ 92
1862   +2│∙ ed 12
1864   +2│∙ f1 62
1866   +2│∙ ea 57
1868   +1│∙ b0
1869   +1│∙ bf
186A   +1│∙ 92
186B   +1│∙ bf
186C   +3│∙ e5 52 10
186F   +2│∙ e8 57
1871   +2│∙ ea 62
1873   +1│∙ bf
1874   +2│∙ e7 52
1876   +2│∙ ec 57
1878   +2│∙ ef 62
187A   +1│∙ bf
187B   +2│∙ e5 52
187D   +2│∙ e8 57
187F   +2│∙ ec 62
1881   +1│∙ bf
1882   +3│∙ e7 52 12
1885   +2│∙ ea 57
1887   +2│∙ ed 62
1889   +1│∙ bf
188A   +2│∙ e5 52
188C   +2│∙ e8 57
188E   +2│∙ ec 62
1890   +1│∙ bf
1891   +2│∙ e8 52
1893   +2│∙ ec 57
1895   +2│∙ ef 62
1897   +1│∙ bf
1898   +2│∙ e6 52
189A   +2│∙ ea 57
189C   +2│∙ ef 62
189E   +1│∙ bf
189F   +2│∙ e6 52
18A1   +2│∙ e8 57
18A3   +2│∙ ec 62
18A5   +1│∙ bf
18A6   +2│∙ e5 52
18A8   +2│∙ ea 57
18AA   +2│∙ ed 62
18AC   +1│∙ bf
18AD   +2│∙ ea 52
18AF   +2│∙ ed 57
18B1   +2│∙ f1 62
18B3   +1│∙ bf
18B4   +2│∙ e7 52
18B6   +2│∙ ec 57
18B8   +2│∙ ef 62
18BA   +1│∙ bf
18BB   +2│∙ ec 52
18BD   +2│∙ ef 57
18BF   +2│∙ f3 62
18C1   +1│∙ bf
18C2   +2│∙ e8 52
18C4   +2│∙ ec 57
18C6   +2│∙ f1 62
18C8   +1│∙ bf
18C9   +2│∙ ee 52
18CB   +2│∙ f1 57
18CD   +2│∙ f6 62
18CF   +1│∙ bf
18D0   +2│∙ ef 52
18D2   +2│∙ f3 57
18D4   +3│∙ f5 62 0c
18D7   +1│∙ bf
18D8   +3│∙ ec 5d 12
18DB   +2│∙ ef 62
18DD   +2│∙ f2 68
18DF   +1│∙ bf
18E0   +1│∙ 9e
18E1   +3│∙ ed 5d 1e
18E4   +1│∙ 68
18E5   +1│∙ 92
18E6   +3│∙ ec 5d 12
18E9   +1│∙ 9e
18EA   +3│∙ ed 68 1e
18ED   +1│∙ 92
18EE   +1│∙ bf
18EF   +1│∙ 9e
18F0   +1│∙ 5d
18F1   +1│∙ 68
18F2   +1│∙ 92
18F3   +3│∙ ec 5d 12
18F6   +1│∙ 9e
18F7   +3│∙ ed 68 1e
18FA   +1│∙ 92
18FB   +1│∙ bf
18FC   +1│∙ 9e
18FD   +1│∙ 5d
18FE   +1│∙ 68
18FF   +1│∙ 92
1900   +3│∙ ec 5d 12
1903   +1│∙ 9e
1904   +3│∙ ed 68 1e
1907   +1│∙ 92
1908   +1│∙ bf
1909   +1│∙ 9e
190A   +1│∙ 5d
190B   +1│∙ 68
190C   +1│∙ 92
190D   +3│∙ ec 5d 12
1910   +1│∙ 9e
1911   +3│∙ ed 68 1e
1914   +1│∙ 92
1915   +1│∙ bf
1916   +1│∙ 9e
1917   +2│∙ eb 5d
1919   +1│∙ 68
191A   +1│∙ 92
191B   +3│∙ ea 5d 12
191E   +1│∙ 9e
191F   +3│∙ eb 68 1e
1922   +1│∙ 92
1923   +1│∙ bf
1924   +1│∙ 9e
1925   +1│∙ 5d
1926   +1│∙ 68
1927   +1│∙ 92
1928   +3│∙ e9 5d 12
192B   +1│∙ 9e
192C   +3│∙ eb 68 1e
192F   +1│∙ 92
1930   +1│∙ bf
1931   +1│∙ 9e
1932   +1│∙ ed
1933   +2│∙ ed 5d
1935   +1│∙ 92
1936   +3│∙ ea 68 12
1939   +2│∙ ed 5d
193B   +2│∙ ea 68
193D   +1│∙ bf
193E   +1│∙ 9e
193F   +2│∙ ed 1e
1941   +2│∙ ed 5d
1943   +1│∙ 92
1944   +3│∙ ea 68 12
1947   +2│∙ ed 5d
1949   +2│∙ ea 68
194B   +2│∙ ef 6d
194D   +1│∙ ad
194E   +1│∙ bf
194F -15C│◄ b6 00 b1

; b6 00 b1 sequence seems to denote track end

.ORG $1400
TrackPtrPtr:
      dw $1402,

.ORG $1402
TrackPtrList:
      dw $1412,
      dw $157f,
      dw $16e7,
      dw $17e1,
      dw $1952,
      dw $1ac5,
      dw $1b7b,
      dw $1ca8,

.ORG $1412
TrackData:
1412: $80, $c0, $3f, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $4c, $c2,
1420: $10, $c5, $15, $c3, $22, $c1, $01, $b5, $92, $bf, $f4, $62, $10, $ef, $5d, $ec,
1430: $57, $ef, $62, $ed, $5d, $ea, $57, $e7, $62, $a1, $e8, $21, $92, $e3, $68, $12,
1440: $a4, $bf, $92, $bf, $f4, $62, $10, $ef, $5d, $ec, $57, $ef, $62, $ed, $5d, $ea,
1450: $57, $e7, $62, $a1, $e8, $21, $92, $e3, $68, $12, $a4, $bf, $92, $bf, $f2, $62,
1460: $10, $ef, $5d, $ea, $57, $ef, $62, $ec, $5d, $e8, $57, $e6, $62, $e5, $5d, $ea,
1470: $5f, $ed, $62, $f1, $68, $a4, $bf, $92, $e7, $5d, $ea, $5f, $ef, $62, $f3, $68,
1480: $a4, $bf, $92, $e8, $5d, $ec, $5f, $ef, $62, $9e, $f4, $68, $1e, $92, $f3, $62,
1490: $10, $ee, $57, $f1, $68, $00, $10, $ef, $62, $ea, $57, $9e, $ed, $68, $1e, $92,
14a0: $ec, $62, $10, $ea, $57, $e3, $68, $bf, $f4, $62, $ef, $5d, $ec, $57, $ef, $62,
14b0: $ed, $5d, $ea, $57, $e7, $62, $a1, $e8, $21, $92, $e3, $68, $12, $a4, $bf, $92,
14c0: $bf, $f4, $62, $10, $ef, $5d, $ec, $57, $ef, $62, $ed, $5d, $ea, $57, $e7, $62,
14d0: $a1, $e8, $21, $92, $e3, $68, $12, $a4, $bf, $92, $bf, $f2, $62, $10, $ef, $5d,
14e0: $ea, $57, $ef, $62, $ec, $5d, $e8, $57, $e6, $62, $e5, $5d, $ea, $5f, $ed, $62,
14f0: $f1, $68, $a4, $bf, $92, $e7, $5d, $ea, $5f, $ef, $62, $f3, $68, $a4, $bf, $92,
1500: $e8, $5d, $ec, $5f, $ef, $62, $9e, $f4, $68, $1e, $92, $f3, $62, $10, $ee, $57,
1510: $f1, $68, $00, $10, $ef, $5d, $ea, $57, $9e, $ed, $68, $1a, $92, $ec, $57, $12,
1520: $ef, $73, $ed, $68, $b0, $bf, $a7, $bf, $92, $ec, $62, $ef, $68, $ed, $62, $a1,
1530: $ec, $5d, $21, $92, $e4, $62, $12, $bf, $e6, $5d, $e8, $62, $ea, $68, $a1, $eb,
1540: $5d, $1e, $92, $f0, $68, $12, $a4, $bf, $a1, $ea, $21, $9e, $e3, $5d, $1e, $92,
1550: $e4, $62, $12, $e6, $68, $e8, $6d, $9e, $e9, $68, $1e, $92, $df, $5d, $12, $eb,
1560: $68, $ed, $5d, $ee, $68, $ef, $5d, $f0, $68, $f1, $ea, $5d, $e5, $57, $ea, $68,
1570: $a4, $bf, $92, $f0, $ea, $5d, $e7, $57, $e4, $68, $a4, $bf, $b6, $00, $b1,

157f: $80,
1580: $bc, $7f, $b8, $00, $ba, $40, $c2, $10, $c5, $14, $c3, $40, $c1, $01, $b5, $92,
1590: $bf, $fb, $62, $10, $f8, $5d, $f4, $57, $f8, $62, $f6, $5d, $f3, $57, $ed, $62,
15a0: $a1, $f1, $21, $92, $ec, $68, $12, $a4, $bf, $92, $bf, $fd, $62, $10, $f8, $5d,
15b0: $f4, $57, $f9, $62, $f6, $5d, $f3, $57, $f0, $62, $a1, $f1, $21, $92, $ec, $68,
15c0: $12, $a4, $bf, $92, $bf, $fb, $62, $10, $f6, $5d, $f2, $57, $f8, $62, $f4, $5d,
15d0: $f1, $57, $ef, $62, $ed, $5d, $f1, $5f, $f6, $62, $f9, $68, $a4, $bf, $92, $ef,
15e0: $5d, $f3, $5f, $f6, $62, $fb, $68, $a4, $bf, $92, $f1, $5d, $f4, $5f, $f8, $62,
15f0: $9e, $fd, $68, $1e, $92, $fa, $62, $10, $f4, $57, $f9, $68, $00, $10, $f6, $62,
1600: $f3, $57, $9e, $f4, $68, $1e, $92, $62, $10, $f3, $57, $ed, $68, $bf, $fb, $62,
1610: $f8, $5d, $f4, $57, $f8, $62, $f6, $5d, $f3, $57, $ed, $62, $a1, $f1, $21, $92,
1620: $ec, $68, $12, $a4, $bf, $92, $bf, $fd, $62, $10, $f8, $5d, $f4, $57, $f9, $62,
1630: $f6, $5d, $f3, $57, $f0, $62, $a1, $f1, $21, $92, $ec, $68, $12, $a4, $bf, $92,
1640: $bf, $fb, $62, $10, $f6, $5d, $f2, $57, $f8, $62, $f4, $5d, $f1, $57, $ef, $62,
1650: $ed, $5d, $f1, $5f, $f6, $62, $f9, $68, $a4, $bf, $92, $ef, $5d, $f3, $5f, $f6,
1660: $62, $fb, $68, $a4, $bf, $92, $f1, $5d, $f4, $5f, $f8, $62, $9e, $fd, $68, $1e,
1670: $92, $fa, $62, $10, $f4, $57, $f9, $68, $00, $10, $f6, $5d, $f3, $57, $9e, $f5,
1680: $68, $1a, $92, $57, $12, $f8, $73, $f5, $68, $b0, $bf, $a7, $bf, $92, $f4, $62,
1690: $f8, $68, $f6, $62, $a1, $f4, $5d, $21, $92, $ed, $62, $12, $bf, $ef, $5d, $f0,
16a0: $62, $f2, $68, $a1, $f2, $5d, $1e, $92, $f7, $68, $12, $a4, $bf, $a3, $f6, $5d,
16b0: $23, $9e, $ef, $52, $1e, $92, $f0, $57, $12, $f2, $5d, $8c, $f4, $62, $0c, $9e,
16c0: $f2, $68, $1e, $92, $eb, $5d, $12, $ee, $68, $f2, $5d, $fa, $68, $f5, $5d, $fc,
16d0: $68, $f9, $f6, $5d, $f1, $57, $ed, $68, $a4, $bf, $92, $f9, $f6, $5d, $f3, $57,
16e0: $ec, $68, $a4, $bf, $b6, $00, $b1,

16e7: $80, $bc, $7f, $b8, $00, $ba, $4c, $c2, $12,
16f0: $c5, $1c, $c3, $5e, $c1, $00, $b0, $bf, $b5, $a1, $bf, $92, $ef, $62, $12, $ea,
1700: $5f, $e7, $5d, $e3, $5a, $e0, $57, $a4, $bf, $92, $e1, $e4, $5d, $e7, $62, $ea,
1710: $68, $10, $a1, $bf, $92, $f4, $62, $12, $f1, $5f, $ec, $5d, $e8, $5a, $e3, $57,
1720: $a4, $bf, $92, $e8, $ec, $5d, $ef, $62, $f2, $68, $a4, $f1, $24, $ed, $62, $ec,
1730: $5d, $e7, $57, $b0, $bf, $bf, $bf, $a1, $bf, $92, $ef, $62, $12, $ea, $5f, $e7,
1740: $5d, $e3, $5a, $e0, $57, $a4, $bf, $92, $e1, $e4, $5d, $e7, $62, $ea, $68, $10,
1750: $a1, $bf, $92, $f4, $62, $12, $f1, $5f, $ec, $5d, $e8, $5a, $e3, $57, $a4, $bf,
1760: $92, $e8, $ec, $5d, $ef, $62, $f2, $68, $a4, $f1, $24, $ed, $62, $ec, $5d, $e7,
1770: $57, $b0, $bf, $a7, $bf, $92, $ec, $12, $ef, $68, $ed, $62, $a1, $ec, $68, $21,
1780: $92, $e5, $5d, $12, $bf, $e7, $e8, $62, $ea, $68, $a1, $ec, $5d, $1e, $92, $f1,
1790: $68, $12, $a4, $bf, $b0, $bf, $a7, $bf, $92, $ea, $5d, $ed, $68, $eb, $5d, $a1,
17a0: $ea, $68, $21, $9e, $e3, $5d, $1e, $92, $e4, $68, $12, $e6, $5d, $e8, $68, $a1,
17b0: $e9, $21, $92, $eb, $5d, $12, $ed, $68, $ee, $5d, $ef, $68, $f0, $5d, $a1, $f1,
17c0: $68, $21, $9e, $ea, $5d, $1e, $92, $ec, $57, $12, $ed, $5d, $ef, $62, $a1, $f0,
17d0: $68, $21, $ef, $62, $9e, $ed, $5d, $1e, $92, $ec, $6d, $12, $ad, $bf, $b6, $00,
17e0: $b1,

17e1: $80, $bc, $7f, $b8, $00, $ba, $40, $c2, $12, $c5, $18, $c3, $40, $c1, $00,
17f0: $b0, $bf, $b5, $92, $bf, $e5, $52, $10, $e8, $57, $ea, $62, $bf, $e7, $52, $ec,
1800: $57, $ef, $62, $bf, $e5, $52, $e8, $57, $ec, $62, $bf, $e7, $52, $12, $ea, $57,
1810: $ed, $62, $bf, $e5, $52, $e8, $57, $ec, $62, $bf, $e8, $52, $ec, $57, $ef, $62,
1820: $bf, $e6, $52, $ea, $57, $ef, $62, $bf, $e6, $52, $e8, $57, $ec, $62, $bf, $e5,
1830: $52, $ea, $57, $ed, $62, $bf, $ea, $52, $ed, $57, $f1, $62, $bf, $e7, $52, $ec,
1840: $57, $ef, $62, $bf, $ec, $52, $ef, $57, $f3, $62, $bf, $e8, $52, $ec, $57, $f1,
1850: $62, $bf, $ee, $52, $f1, $57, $f6, $62, $bf, $ef, $57, $f3, $62, $9e, $ea, $57,
1860: $1e, $92, $ed, $12, $f1, $62, $ea, $57, $b0, $bf, $92, $bf, $e5, $52, $10, $e8,
1870: $57, $ea, $62, $bf, $e7, $52, $ec, $57, $ef, $62, $bf, $e5, $52, $e8, $57, $ec,
1880: $62, $bf, $e7, $52, $12, $ea, $57, $ed, $62, $bf, $e5, $52, $e8, $57, $ec, $62,
1890: $bf, $e8, $52, $ec, $57, $ef, $62, $bf, $e6, $52, $ea, $57, $ef, $62, $bf, $e6,
18a0: $52, $e8, $57, $ec, $62, $bf, $e5, $52, $ea, $57, $ed, $62, $bf, $ea, $52, $ed,
18b0: $57, $f1, $62, $bf, $e7, $52, $ec, $57, $ef, $62, $bf, $ec, $52, $ef, $57, $f3,
18c0: $62, $bf, $e8, $52, $ec, $57, $f1, $62, $bf, $ee, $52, $f1, $57, $f6, $62, $bf,
18d0: $ef, $52, $f3, $57, $f5, $62, $0c, $bf, $ec, $5d, $12, $ef, $62, $f2, $68, $bf,
18e0: $9e, $ed, $5d, $1e, $68, $92, $ec, $5d, $12, $9e, $ed, $68, $1e, $92, $bf, $9e,
18f0: $5d, $68, $92, $ec, $5d, $12, $9e, $ed, $68, $1e, $92, $bf, $9e, $5d, $68, $92,
1900: $ec, $5d, $12, $9e, $ed, $68, $1e, $92, $bf, $9e, $5d, $68, $92, $ec, $5d, $12,
1910: $9e, $ed, $68, $1e, $92, $bf, $9e, $eb, $5d, $68, $92, $ea, $5d, $12, $9e, $eb,
1920: $68, $1e, $92, $bf, $9e, $5d, $68, $92, $e9, $5d, $12, $9e, $eb, $68, $1e, $92,
1930: $bf, $9e, $ed, $ed, $5d, $92, $ea, $68, $12, $ed, $5d, $ea, $68, $bf, $9e, $ed,
1940: $1e, $ed, $5d, $92, $ea, $68, $12, $ed, $5d, $ea, $68, $ef, $6d, $ad, $bf, $b6,
1950: $00, $b1,

1952: $80, $bc, $7f, $b8, $00, $ba, $40, $c2, $12, $c5, $18, $c3, $40, $c1,
1960: $00, $b0, $bf, $b5, $92, $e1, $57, $10, $e5, $5d, $e8, $62, $e0, $5d, $bf, $e3,
1970: $57, $e8, $62, $e0, $57, $de, $e5, $5d, $e8, $62, $e1, $5d, $bf, $e4, $57, $e7,
1980: $62, $ea, $57, $e8, $e5, $5d, $e8, $62, $ec, $5d, $bf, $e3, $57, $e8, $62, $ec,
1990: $57, $e3, $e6, $5d, $ea, $62, $dc, $5d, $bf, $e0, $57, $e3, $62, $e8, $57, $bf,
19a0: $e1, $e5, $62, $de, $57, $bf, $e1, $e5, $62, $de, $57, $bf, $e3, $e7, $62, $e0,
19b0: $57, $bf, $e3, $e7, $62, $e0, $57, $d9, $e5, $5d, $e8, $62, $e0, $5d, $de, $57,
19c0: $e2, $5d, $e5, $62, $de, $5d, $00, $0a, $de, $57, $10, $e1, $5d, $9e, $e5, $62,
19d0: $1a, $92, $e0, $57, $10, $e1, $5d, $e3, $62, $b0, $bf, $92, $e1, $57, $e5, $5d,
19e0: $e8, $62, $e0, $5d, $bf, $e3, $57, $e8, $62, $e0, $57, $de, $e5, $5d, $e8, $62,
19f0: $e1, $5d, $bf, $e4, $57, $e7, $62, $ea, $57, $e8, $e5, $5d, $e8, $62, $ec, $5d,
1a00: $bf, $e3, $57, $e8, $62, $ec, $57, $e3, $e6, $5d, $ea, $62, $dc, $5d, $bf, $e0,
1a10: $57, $e3, $62, $e8, $57, $bf, $e1, $e5, $62, $de, $57, $bf, $e1, $e5, $62, $de,
1a20: $57, $bf, $e3, $e7, $62, $e0, $57, $bf, $e3, $e7, $62, $e0, $57, $d9, $e5, $5d,
1a30: $e8, $62, $e0, $5d, $de, $57, $e2, $5d, $e5, $62, $de, $5d, $00, $bf, $57, $10,
1a40: $e1, $5d, $9e, $e6, $62, $1a, $92, $e0, $57, $10, $e3, $5d, $e6, $62, $9e, $bf,
1a50: $92, $dc, $12, $9e, $e1, $68, $1e, $e8, $6d, $92, $e1, $62, $12, $9e, $bf, $92,
1a60: $dc, $9e, $e1, $68, $1e, $e8, $6d, $92, $e1, $62, $12, $9e, $bf, $92, $dc, $9e,
1a70: $e1, $68, $1e, $e8, $6d, $92, $e1, $62, $12, $9e, $bf, $92, $da, $9e, $e1, $68,
1a80: $1e, $e6, $6d, $92, $e1, $62, $12, $9e, $bf, $92, $da, $9e, $df, $68, $1e, $e6,
1a90: $6d, $92, $df, $62, $12, $9e, $bf, $92, $da, $9e, $df, $68, $1e, $e6, $6d, $92,
1aa0: $df, $62, $12, $9e, $bf, $92, $d9, $9e, $de, $68, $1e, $e1, $6d, $92, $e5, $62,
1ab0: $12, $9e, $bf, $92, $d8, $9e, $de, $68, $1e, $e1, $6d, $92, $ea, $62, $12, $ec,
1ac0: $ad, $bf, $b6, $00, $b1,

1ac5: $80, $bc, $7f, $b8, $00, $ba, $34, $c2, $19, $c5, $1c,
1ad0: $c3, $40, $c1, $0a, $b0, $bf, $b5, $92, $bf, $9e, $e1, $62, $1e, $bf, $e0, $92,
1ae0: $bf, $bf, $9e, $de, $bf, $e4, $92, $bf, $bf, $9e, $e5, $bf, $e0, $92, $bf, $bf,
1af0: $9e, $d7, $bf, $dc, $92, $bf, $bf, $9e, $de, $bf, $de, $92, $bf, $bf, $9e, $e0,
1b00: $bf, $e0, $92, $bf, $bf, $9e, $d9, $bf, $de, $92, $bf, $bf, $9e, $e3, $bf, $d7,
1b10: $92, $bf, $b0, $bf, $92, $bf, $9e, $e1, $bf, $e0, $92, $bf, $bf, $9e, $de, $bf,
1b20: $e4, $92, $bf, $bf, $9e, $e5, $bf, $e0, $92, $bf, $bf, $9e, $d7, $bf, $dc, $92,
1b30: $bf, $bf, $9e, $de, $bf, $de, $92, $bf, $bf, $9e, $e0, $bf, $e0, $92, $bf, $bf,
1b40: $9e, $d9, $bf, $de, $92, $bf, $bf, $9e, $e3, $bf, $d7, $92, $bf, $9e, $e1, $a4,
1b50: $bf, $9e, $d5, $aa, $bf, $9e, $d5, $e1, $a4, $bf, $9e, $d5, $aa, $bf, $9e, $da,
1b60: $df, $a4, $bf, $9e, $df, $aa, $bf, $9e, $df, $a1, $de, $21, $de, $9e, $bf, $a1,
1b70: $e3, $d7, $9e, $e3, $1e, $dc, $aa, $bf, $b6, $00, $b1,

1b7b: $80, $bc, $7f, $b8, $00,
1b80: $ba, $40, $c2, $12, $c5, $1c, $c3, $40, $b5, $80, $c1, $07, $b0, $bf, $92, $e5,
1b90: $57, $12, $e8, $5d, $ec, $62, $9e, $bf, $92, $e3, $57, $e7, $5d, $ea, $62, $9e,
1ba0: $e8, $1e, $bf, $ed, $bf, $92, $e8, $57, $12, $ec, $5d, $f1, $62, $9e, $bf, $92,
1bb0: $e8, $57, $ec, $5d, $f1, $62, $10, $9e, $e6, $1e, $bf, $ec, $bf, $b0, $bf, $bf,
1bc0: $92, $e8, $57, $12, $ec, $5d, $ef, $62, $f4, $5d, $bf, $ee, $57, $f1, $5d, $f4,
1bd0: $62, $bf, $f1, $5d, $f4, $57, $f9, $62, $bf, $f8, $f6, $57, $ef, $62, $b0, $bf,
1be0: $92, $e5, $57, $e8, $5d, $ec, $62, $9e, $bf, $92, $e3, $57, $e7, $5d, $ea, $62,
1bf0: $9e, $e8, $1e, $bf, $ed, $bf, $92, $e8, $57, $12, $ec, $5d, $f1, $62, $9e, $bf,
1c00: $92, $e8, $57, $ec, $5d, $f1, $62, $9e, $e6, $1e, $bf, $ec, $bf, $b0, $bf, $bf,
1c10: $92, $e8, $57, $12, $ec, $5d, $ef, $62, $f4, $5d, $bf, $ee, $57, $f1, $5d, $f4,
1c20: $62, $bf, $f1, $f4, $f9, $bf, $f8, $fb, $f9, $80, $c1, $02, $92, $ec, $4c, $f1,
1c30: $52, $ec, $4c, $f1, $52, $9e, $bf, $92, $ec, $4c, $f1, $52, $ec, $4c, $f1, $52,
1c40: $ec, $4c, $f1, $52, $9e, $bf, $92, $ec, $4c, $f1, $52, $ec, $4c, $f0, $52, $ec,
1c50: $4c, $f0, $52, $9e, $bf, $92, $ec, $4c, $f0, $52, $eb, $4c, $f0, $52, $eb, $4c,
1c60: $f0, $52, $9e, $bf, $92, $eb, $4c, $f2, $52, $ea, $4c, $ef, $52, $f6, $4c, $ef,
1c70: $52, $9e, $bf, $92, $f6, $4c, $ef, $52, $e9, $4c, $ee, $52, $e9, $4c, $ee, $52,
1c80: $9e, $bf, $92, $e9, $4c, $ee, $52, $ea, $4c, $f1, $52, $ea, $4c, $f1, $52, $9e,
1c90: $bf, $92, $f6, $4c, $fd, $52, $ed, $4c, $f0, $52, $ed, $4c, $f0, $52, $9e, $bf,
1ca0: $92, $ed, $4c, $f6, $52, $b6, $00, $b1, $80, $bc, $7f, $b8, $00, $ba, $40, $c2,
1cb0: $12, $c5, $1c, $c3, $40, $c1, $07, $b5, $b0, $bf, $92, $e1, $57, $12, $e5, $5d,
1cc0: $e8, $62, $9e, $bf, $92, $e0, $57, $e3, $5d, $e7, $62, $9e, $e5, $1e, $bf, $ea,
1cd0: $bf, $92, $e5, $57, $12, $e8, $5d, $ec, $62, $9e, $bf, $92, $e3, $57, $e8, $5d,
1ce0: $ec, $62, $9e, $e3, $1e, $bf, $e8, $bf, $b0, $bf, $bf, $92, $e5, $57, $12, $e8,
1cf0: $5d, $ec, $62, $ef, $5d, $bf, $ea, $57, $ee, $5d, $f1, $62, $bf, $ed, $5d, $f1,
1d00: $57, $f4, $62, $bf, $f4, $f3, $57, $ed, $62, $b0, $bf, $92, $e1, $57, $e5, $5d,
1d10: $e8, $62, $9e, $bf, $92, $e0, $57, $e3, $5d, $e7, $62, $9e, $e5, $1e, $bf, $ea,
1d20: $bf, $92, $e5, $57, $12, $e8, $5d, $ec, $62, $9e, $bf, $92, $e3, $57, $e8, $5d,
1d30: $ec, $62, $9e, $e3, $1e, $bf, $e8, $bf, $b0, $bf, $bf, $92, $e5, $57, $12, $e8,
1d40: $5d, $ec, $62, $ef, $5d, $bf, $ea, $57, $ee, $5d, $f1, $62, $bf, $ed, $f1, $f5,
1d50: $bf, $f5, $f8, $f5, $a4, $f8, $24, $bf, $a7, $bf, $92, $12, $fb, $68, $f9, $62,
1d60: $a1, $f8, $21, $92, $f0, $68, $12, $bf, $f2, $5d, $f4, $62, $f6, $68, $a1, $f7,
1d70: $5d, $1e, $92, $fc, $68, $12, $a4, $bf, $b0, $bf, $bf, $a1, $fd, $21, $92, $f6,
1d80: $5d, $12, $a4, $bf, $a1, $fc, $68, $21, $92, $f6, $5d, $12, $a4, $bf, $b6, $00,
1d90: $b1,

; SFX Data
.ORG $C800
c800: $4e, $c8, $80, $c8, $ad, $c8, $dd, $c8, $0d, $c9, $a1, $c9, $dc, $c9, $10, $ca,
c810: $56, $ca, $89, $ca, $ed, $ca, $20, $cb, $63, $cb, $93, $cb, $c0, $cb, $f0, $cb,
c820: $20, $cc, $ac, $cc, $1b, $cd, $c4, $cd, $45, $ce, $c9, $ce, $42, $cf, $c1, $cf,
c830: $43, $d0, $76, $d0, $a8, $d0, $e7, $d0, $24, $d1, $63, $d1, $e0, $d1, $4e, $c8,
c840: $69, $c8, $6a, $c8, $6b, $c8, $6c, $c8, $6d, $c8, $6e, $c8, $6f, $c8, $80, $c0,
c850: $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $4c, $c2, $25, $c1, $01, $86,
c860: $f4, $73, $06, $f6, $f4, $f6, $f8, $f6, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1,
c870: $80, $c8, $96, $c8, $97, $c8, $98, $c8, $99, $c8, $9a, $c8, $9b, $c8, $9c, $c8,
c880: $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $4c, $c2, $2f, $c1,
c890: $0b, $88, $f4, $73, $08, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $ad, $c8, $c6,
c8a0: $c8, $c7, $c8, $c8, $c8, $c9, $c8, $ca, $c8, $cb, $c8, $cc, $c8, $80, $c0, $78,
c8b0: $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $4c, $c2, $25, $c1, $05, $8e, $e8,
c8c0: $73, $0e, $92, $f4, $12, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $dd, $c8, $f6,
c8d0: $c8, $f7, $c8, $f8, $c8, $f9, $c8, $fa, $c8, $fb, $c8, $fc, $c8, $80, $c0, $78,
c8e0: $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $25, $c1, $02, $b5, $8a,
c8f0: $dc, $68, $0a, $b6, $06, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $0d, $c9, $8a,
c900: $c9, $8b, $c9, $8c, $c9, $8d, $c9, $8e, $c9, $8f, $c9, $90, $c9, $80, $c0, $78,
c910: $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $75, $c1, $0d, $c3, $04,
c920: $88, $f6, $3c, $04, $80, $c3, $09, $0e, $88, $f6, $47, $80, $c3, $13, $18, $88,
c930: $f6, $4c, $80, $c3, $1d, $22, $88, $f6, $52, $80, $c3, $27, $2c, $88, $f6, $57,
c940: $80, $c3, $31, $36, $88, $f6, $5d, $80, $c3, $3b, $40, $88, $f6, $62, $80, $c3,
c950: $45, $4a, $88, $f6, $68, $80, $c3, $4f, $88, $f6, $80, $c3, $54, $8a, $f6, $6d,
c960: $80, $c3, $59, $8e, $f6, $80, $c3, $5e, $63, $8f, $f6, $73, $80, $c3, $68, $6d,
c970: $92, $f6, $80, $c3, $72, $77, $95, $f6, $80, $c3, $7c, $9a, $f6, $80, $c3, $7f,
c980: $9a, $f6, $6d, $80, $c3, $7f, $9a, $f6, $68, $b1, $b1, $b1, $b1, $b1, $b1, $b1,
c990: $b1, $a1, $c9, $c5, $c9, $c6, $c9, $c7, $c9, $c8, $c9, $c9, $c9, $ca, $c9, $cb,
c9a0: $c9, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $42,
c9b0: $c1, $0b, $8a, $e8, $75, $08, $9f, $4c, $8a, $6a, $9f, $41, $8a, $5f, $9f, $36,
c9c0: $8a, $49, $9f, $36, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $dc, $c9, $f9, $c9,
c9d0: $fa, $c9, $fb, $c9, $fc, $c9, $fd, $c9, $fe, $c9, $ff, $c9, $80, $c0, $78, $bb,
c9e0: $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $3a, $c1, $0b, $88, $dc, $57,
c9f0: $08, $80, $c1, $08, $8e, $f3, $75, $0e, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1,
ca00: $10, $ca, $3f, $ca, $40, $ca, $41, $ca, $42, $ca, $43, $ca, $44, $ca, $45, $ca,
ca10: $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $58, $c2, $37, $c1,
ca20: $05, $c7, $40, $88, $e8, $52, $08, $f4, $80, $c1, $05, $8e, $f4, $5d, $0e, $88,
ca30: $47, $08, $8e, $52, $0e, $88, $3c, $08, $8e, $4c, $0e, $88, $36, $08, $b1, $b1,
ca40: $b1, $b1, $b1, $b1, $b1, $b1, $56, $ca, $72, $ca, $73, $ca, $74, $ca, $75, $ca,
ca50: $76, $ca, $77, $ca, $78, $ca, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8,
ca60: $00, $ba, $40, $c2, $3a, $c1, $0b, $88, $d9, $73, $08, $80, $c1, $0c, $95, $ea,
ca70: $15, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $89, $ca, $d6, $ca, $d7, $ca, $d8,
ca80: $ca, $d9, $ca, $da, $ca, $db, $ca, $dc, $ca, $80, $c0, $78, $bb, $46, $04, $32,
ca90: $bc, $7f, $b8, $00, $ba, $4c, $c2, $2f, $c1, $01, $88, $fc, $73, $08, $fb, $fa,
caa0: $f9, $f8, $f7, $f6, $f5, $f4, $f3, $f2, $70, $f1, $6d, $f0, $6a, $ef, $68, $ee,
cab0: $65, $ed, $62, $ec, $5f, $eb, $5d, $ea, $5a, $e9, $57, $e8, $54, $e7, $52, $e6,
cac0: $4f, $e5, $4c, $e4, $49, $e3, $47, $e2, $44, $e1, $41, $e0, $3e, $df, $3c, $de,
cad0: $39, $dd, $36, $dc, $33, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $ed, $ca, $09,
cae0: $cb, $0a, $cb, $0b, $cb, $0c, $cb, $0d, $cb, $0e, $cb, $0f, $cb, $80, $c0, $78,
caf0: $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $44, $c1, $08, $92, $dc,
cb00: $73, $12, $80, $c1, $0c, $86, $ea, $06, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1,
cb10: $20, $cb, $4c, $cb, $4d, $cb, $4e, $cb, $4f, $cb, $50, $cb, $51, $cb, $52, $cb,
cb20: $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $42, $c1,
cb30: $01, $88, $e8, $68, $08, $ea, $ec, $ed, $ef, $f1, $ec, $ed, $ef, $f1, $f3, $f4,
cb40: $ef, $f1, $f3, $f4, $f6, $f3, $f4, $f6, $f8, $f9, $fb, $b1, $b1, $b1, $b1, $b1,
cb50: $b1, $b1, $b1, $63, $cb, $7c, $cb, $7d, $cb, $7e, $cb, $7f, $cb, $80, $cb, $81,
cb60: $cb, $82, $cb, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40,
cb70: $c2, $44, $c1, $0b, $8c, $dc, $75, $0c, $92, $f4, $12, $b1, $b1, $b1, $b1, $b1,
cb80: $b1, $b1, $b1, $93, $cb, $a9, $cb, $aa, $cb, $ab, $cb, $ac, $cb, $ad, $cb, $ae,
cb90: $cb, $af, $cb, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40,
cba0: $c2, $3a, $c1, $0c, $b0, $de, $77, $30, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1,
cbb0: $c0, $cb, $d9, $cb, $da, $cb, $db, $cb, $dc, $cb, $dd, $cb, $de, $cb, $df, $cb,
cbc0: $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $79, $c1,
cbd0: $0d, $9a, $e0, $75, $1a, $9e, $3c, $1e, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1,
cbe0: $f0, $cb, $09, $cc, $0a, $cc, $0b, $cc, $0c, $cc, $0d, $cc, $0e, $cc, $0f, $cc,
cbf0: $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $44, $c1,
cc00: $0e, $95, $e5, $73, $0a, $68, $5d, $47, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1,
cc10: $20, $cc, $52, $cc, $96, $cc, $97, $cc, $98, $cc, $99, $cc, $9a, $cc, $9b, $cc,
cc20: $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $31, $c1,
cc30: $08, $8a, $ec, $6d, $0a, $8e, $e8, $73, $0e, $8a, $ea, $62, $0a, $e8, $5d, $ea,
cc40: $57, $e8, $52, $e6, $47, $e0, $de, $dc, $41, $de, $3c, $e1, $dc, $e3, $36, $e1,
cc50: $dc, $b1, $80, $bc, $7f, $b8, $00, $ba, $40, $c2, $44, $c1, $0d, $84, $e8, $73,
cc60: $04, $86, $ea, $06, $84, $e8, $04, $ef, $ea, $6d, $88, $ec, $68, $08, $84, $62,
cc70: $04, $ea, $6d, $86, $ea, $62, $06, $84, $ef, $73, $04, $ed, $6d, $ec, $68, $8e,
cc80: $e8, $62, $0e, $86, $ed, $5d, $06, $ef, $57, $ea, $52, $ec, $4c, $ea, $47, $41,
cc90: $e8, $3c, $e3, $36, $e8, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $ac, $cc, $04, $cd,
cca0: $05, $cd, $06, $cd, $07, $cd, $08, $cd, $09, $cd, $0a, $cd, $80, $c0, $78, $bb,
ccb0: $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $6b, $c1, $0b, $8a, $dc, $36,
ccc0: $08, $41, $4c, $57, $62, $6d, $73, $77, $dc, $dc, $dc, $dc, $dc, $dc, $dc, $dc,
ccd0: $dc, $dc, $dc, $dc, $80, $c1, $0e, $88, $e0, $e3, $e5, $8c, $e3, $0c, $e1, $de,
cce0: $e0, $e3, $73, $de, $6d, $e5, $68, $e3, $62, $e0, $5d, $de, $dc, $e3, $de, $57,
ccf0: $e0, $e3, $dc, $52, $e5, $e0, $e1, $4c, $dc, $e0, $47, $e5, $e1, $41, $e0, $e5,
cd00: $3c, $dc, $36, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $1b, $cd, $6a, $cd, $ae,
cd10: $cd, $af, $cd, $b0, $cd, $b1, $cd, $b2, $cd, $b3, $cd, $80, $c0, $78, $bb, $46,
cd20: $04, $32, $bc, $7f, $b8, $00, $ba, $40, $c2, $4e, $c1, $08, $8a, $dc, $3c, $0a,
cd30: $e0, $41, $e1, $47, $de, $57, $dc, $5d, $e0, $73, $e1, $75, $e1, $e0, $6d, $dc,
cd40: $68, $e0, $6d, $dc, $e1, $e0, $de, $68, $e0, $73, $e1, $6d, $e0, $73, $dc, $75,
cd50: $de, $6d, $dc, $68, $e0, $62, $e1, $68, $e0, $6d, $de, $68, $e0, $62, $e1, $57,
cd60: $e3, $52, $e0, $4c, $de, $47, $dc, $41, $3c, $b1, $80, $bc, $7f, $b8, $00, $ba,
cd70: $40, $c2, $61, $c1, $0d, $84, $e8, $73, $04, $86, $ea, $06, $84, $e8, $04, $ef,
cd80: $ea, $6d, $88, $ec, $68, $08, $84, $62, $04, $ea, $6d, $86, $ea, $62, $06, $84,
cd90: $ef, $73, $04, $ed, $6d, $ec, $68, $8e, $e8, $62, $0e, $86, $ed, $5d, $06, $ef,
cda0: $57, $ea, $52, $ec, $4c, $ea, $47, $41, $e8, $3c, $e3, $36, $e8, $b1, $b1, $b1,
cdb0: $b1, $b1, $b1, $b1, $c4, $cd, $eb, $cd, $2f, $ce, $30, $ce, $31, $ce, $32, $ce,
cdc0: $33, $ce, $34, $ce, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba,
cdd0: $40, $c2, $3f, $c1, $0c, $86, $f1, $54, $06, $ef, $5f, $f1, $64, $88, $f4, $6a,
cde0: $08, $f1, $6f, $e8, $75, $f1, $77, $8e, $f3, $0e, $b1, $80, $bc, $7f, $b8, $00,
cdf0: $ba, $40, $c2, $3f, $c1, $0d, $84, $e8, $73, $04, $86, $ea, $06, $84, $e8, $04,
ce00: $ef, $ea, $6d, $88, $ec, $68, $08, $84, $62, $04, $ea, $6d, $86, $ea, $62, $06,
ce10: $84, $ef, $73, $04, $ed, $6d, $ec, $68, $8e, $e8, $62, $0e, $86, $ed, $5d, $06,
ce20: $ef, $57, $ea, $52, $ec, $4c, $ea, $47, $41, $e8, $3c, $e3, $36, $e8, $b1, $b1,
ce30: $b1, $b1, $b1, $b1, $b1, $45, $ce, $6f, $ce, $b3, $ce, $b4, $ce, $b5, $ce, $b6,
ce40: $ce, $b7, $ce, $b8, $ce, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00,
ce50: $ba, $40, $c2, $44, $c1, $0e, $8a, $ef, $73, $0a, $ed, $77, $ec, $75, $e7, $6d,
ce60: $e5, $68, $e3, $62, $de, $5d, $dc, $57, $db, $d9, $3c, $db, $d9, $db, $b1, $80,
ce70: $bc, $7f, $b8, $00, $ba, $40, $c2, $44, $c1, $0d, $84, $e8, $73, $04, $86, $ea,
ce80: $06, $84, $e8, $04, $ef, $ea, $6d, $88, $ec, $68, $08, $84, $62, $04, $ea, $6d,
ce90: $86, $ea, $62, $06, $84, $ef, $73, $04, $ed, $6d, $ec, $68, $8e, $e8, $62, $0e,
cea0: $86, $ed, $5d, $06, $ef, $57, $ea, $52, $ec, $4c, $ea, $47, $41, $e8, $3c, $e3,
ceb0: $36, $e8, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $c9, $ce, $e8, $ce, $2c, $cf, $2d,
cec0: $cf, $2e, $cf, $2f, $cf, $30, $cf, $31, $cf, $80, $c0, $78, $bb, $46, $04, $32,
ced0: $bc, $7f, $b8, $00, $ba, $40, $c3, $40, $c2, $3f, $c1, $0e, $8a, $d7, $73, $0a,
cee0: $e5, $db, $e5, $e7, $e8, $ea, $ec, $b1, $80, $bc, $7f, $b8, $00, $ba, $40, $c2,
cef0: $3f, $c1, $0d, $84, $e8, $73, $04, $86, $ea, $06, $84, $e8, $04, $ef, $ea, $6d,
cf00: $88, $ec, $68, $08, $84, $62, $04, $ea, $6d, $86, $ea, $62, $06, $84, $ef, $73,
cf10: $04, $ed, $6d, $ec, $68, $8e, $e8, $62, $0e, $86, $ed, $5d, $06, $ef, $57, $ea,
cf20: $52, $ec, $4c, $ea, $47, $41, $e8, $3c, $e3, $36, $e8, $b1, $b1, $b1, $b1, $b1,
cf30: $b1, $b1, $42, $cf, $67, $cf, $ab, $cf, $ac, $cf, $ad, $cf, $ae, $cf, $af, $cf,
cf40: $b0, $cf, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $58, $c3,
cf50: $40, $c2, $31, $c1, $05, $b5, $86, $e8, $68, $06, $b6, $01, $b5, $86, $ef, $68,
cf60: $06, $ed, $b6, $03, $f4, $f8, $b1, $80, $bc, $7f, $b8, $00, $ba, $40, $c2, $44,
cf70: $c1, $0d, $84, $e8, $73, $04, $86, $ea, $06, $84, $e8, $04, $ef, $ea, $6d, $88,
cf80: $ec, $68, $08, $84, $62, $04, $ea, $6d, $86, $ea, $62, $06, $84, $ef, $73, $04,
cf90: $ed, $6d, $ec, $68, $8e, $e8, $62, $0e, $86, $ed, $5d, $06, $ef, $57, $ea, $52,
cfa0: $ec, $4c, $ea, $47, $41, $e8, $3c, $e3, $36, $e8, $b1, $b1, $b1, $b1, $b1, $b1,
cfb0: $b1, $c1, $cf, $e9, $cf, $2d, $d0, $2e, $d0, $2f, $d0, $30, $d0, $31, $d0, $32,
cfc0: $d0, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $4c, $c3, $40,
cfd0: $c2, $3f, $c1, $0c, $86, $e8, $73, $06, $ec, $ef, $f3, $f4, $f4, $f3, $68, $f1,
cfe0: $5d, $ef, $ed, $52, $ec, $ea, $47, $e8, $b1, $80, $bc, $7f, $b8, $00, $ba, $40,
cff0: $c2, $3f, $c1, $0d, $84, $e8, $73, $04, $86, $ea, $06, $84, $e8, $04, $ef, $ea,
d000: $6d, $88, $ec, $68, $08, $84, $62, $04, $ea, $6d, $86, $ea, $62, $06, $84, $ef,
d010: $73, $04, $ed, $6d, $ec, $68, $8e, $e8, $62, $0e, $86, $ed, $5d, $06, $ef, $57,
d020: $ea, $52, $ec, $4c, $ea, $47, $41, $e8, $3c, $e3, $36, $e8, $b1, $b1, $b1, $b1,
d030: $b1, $b1, $b1, $43, $d0, $5f, $d0, $60, $d0, $61, $d0, $62, $d0, $63, $d0, $64,
d040: $d0, $65, $d0, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $4c,
d050: $c2, $3a, $c1, $0d, $8c, $f1, $73, $0c, $80, $c1, $0e, $8a, $fd, $0a, $b1, $b1,
d060: $b1, $b1, $b1, $b1, $b1, $b1, $76, $d0, $91, $d0, $92, $d0, $93, $d0, $94, $d0,
d070: $95, $d0, $96, $d0, $97, $d0, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8,
d080: $00, $ba, $58, $c2, $31, $c1, $0e, $b5, $9e, $ef, $73, $1e, $ff, $5d, $b6, $00,
d090: $b1, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $a8, $d0, $d0, $d0, $d1, $d0, $d2, $d0,
d0a0: $d3, $d0, $d4, $d0, $d5, $d0, $d6, $d0, $80, $c0, $78, $bb, $46, $04, $32, $bc,
d0b0: $7f, $b8, $00, $ba, $40, $c2, $12, $c1, $01, $88, $e8, $73, $08, $80, $c7, $40,
d0c0: $30, $81, $ef, $00, $c7, $33, $35, $37, $39, $3c, $3e, $40, $88, $ef, $08, $b1,
d0d0: $b1, $b1, $b1, $b1, $b1, $b1, $b1, $e7, $d0, $fe, $d0, $0e, $d1, $0f, $d1, $10,
d0e0: $d1, $11, $d1, $12, $d1, $13, $d1, $80, $c0, $4b, $bb, $64, $04, $32, $bc, $7f,
d0f0: $b8, $00, $ba, $40, $c2, $13, $c1, $07, $88, $f4, $68, $08, $4c, $b1, $80, $bc,
d100: $7f, $b8, $00, $ba, $40, $c2, $2f, $c1, $00, $b0, $e8, $73, $30, $b1, $b1, $b1,
d110: $b1, $b1, $b1, $b1, $24, $d1, $3d, $d1, $4d, $d1, $4e, $d1, $4f, $d1, $50, $d1,
d120: $51, $d1, $52, $d1, $80, $c0, $4b, $bb, $32, $02, $32, $bc, $7f, $b8, $00, $ba,
d130: $4c, $c2, $30, $c1, $01, $b5, $a4, $f4, $73, $24, $b6, $00, $b1, $80, $bc, $7f,
d140: $b8, $00, $ba, $40, $c2, $2f, $c1, $00, $b0, $e8, $73, $30, $b1, $b1, $b1, $b1,
d150: $b1, $b1, $b1, $63, $d1, $86, $d1, $ca, $d1, $cb, $d1, $cc, $d1, $cd, $d1, $ce,
d160: $d1, $cf, $d1, $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $40,
d170: $c2, $31, $c1, $08, $86, $ec, $6d, $06, $ea, $73, $e8, $ec, $62, $ea, $57, $ec,
d180: $4c, $e8, $41, $ea, $36, $b1, $80, $bc, $7f, $b8, $00, $ba, $40, $c2, $44, $c1,
d190: $0d, $84, $e8, $73, $04, $86, $ea, $06, $84, $e8, $04, $ef, $ea, $6d, $88, $ec,
d1a0: $68, $08, $84, $62, $04, $ea, $6d, $86, $ea, $62, $06, $84, $ef, $73, $04, $ed,
d1b0: $6d, $ec, $68, $8e, $e8, $62, $0e, $86, $ed, $5d, $06, $ef, $57, $ea, $52, $ec,
d1c0: $4c, $ea, $47, $41, $e8, $3c, $e3, $36, $e8, $b1, $b1, $b1, $b1, $b1, $b1, $b1,
d1d0: $e0, $d1, $11, $d2, $55, $d2, $56, $d2, $57, $d2, $58, $d2, $59, $d2, $5a, $d2,
d1e0: $80, $c0, $78, $bb, $46, $04, $32, $bc, $7f, $b8, $00, $ba, $4c, $c2, $31, $c1,
d1f0: $0b, $95, $d9, $6d, $15, $80, $c1, $07, $a4, $ff, $24, $84, $b7, $a4, $ff, $52,
d200: $9e, $ff, $47, $1e, $95, $5d, $15, $4c, $41, $92, $ff, $3c, $12, $ff, $ff, $36,
d210: $b1, $80, $bc, $7f, $b8, $00, $ba, $40, $c2, $44, $c1, $0d, $84, $e8, $73, $04,
d220: $86, $ea, $06, $84, $e8, $04, $ef, $ea, $6d, $88, $ec, $68, $08, $84, $62, $04,
d230: $ea, $6d, $86, $ea, $62, $06, $84, $ef, $73, $04, $ed, $6d, $ec, $68, $8e, $e8,
d240: $62, $0e, $86, $ed, $5d, $06, $ef, $57, $ea, $52, $ec, $4c, $ea, $47, $41, $e8,
d250: $3c, $e3, $36, $e8, $b1, $b1, $b1, $b1, $b1, $b1, $b1, $00,
