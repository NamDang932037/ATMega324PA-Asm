.EQU	LED7SEGPORT = PORTD       
.EQU	LED7SEGDIR =  DDRD
.EQU	LED7SEGLATCHPORT = PORTB
.EQU	LED7SEGLATCHDIR =  DDRB
.EQU	NLE0PIN			=	4
.EQU	NLE1PIN			=	5
.DSEG
.ORG	SRAM_START				  ;STARTING ADDRESS IS 0X100
		LED7SEGVALUE:	.BYTE	4 ;STORE THE BCD VALUE TO DISPLAY
		LED7SEGINDEX:	.BYTE	1
.CSEG
.ALIGN	2
;		J34 CONNECT TO PORTD
;		NLE0 CONNECT TO PB4
;		NLE1 CONNECT TO PB5
;		OUTPUT: NONE

;---------------------------------------------

.ORG 0X0000 ; INTERRUPT VECTOR TABLE
RJMP RESET_HANDLER
.ORG 0X001A
RJMP TIMER1_COMP_ISR

RESET_HANDLER:
    ; INITIALIZE STACK POINTER
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
	
	CLI
    LDI R16, (1<<PCIE0)
    STS PCICR, R16
    CALL INITTIMER1CTC
    CALL LED7SEG_PORTINIT
    CALL LED7SEG_BUFFER_INIT

    ; ENABLE GLOBAL INTERRUPTS
    SEI
LOOP:
	JMP		LOOP

;INIT THE LED7SEG BUFFER
LED7SEG_BUFFER_INIT:
    PUSH    R20
	LDI		R20,4   ;LED INDEX START AT 4
	LDI		R31,HIGH(LED7SEGINDEX)
	LDI		R30,LOW(LED7SEGINDEX)
	ST		Z,R20
	LDI		R20,4
	LDI		R31,HIGH(LED7SEGVALUE)
	LDI		R30,LOW(LED7SEGVALUE)
	ST		Z+,R20					;DISPLAY VALUE IS 1-2-3-4
	DEC		R20
	ST		Z+,R20
	DEC		R20
	ST		Z+,R20
	DEC		R20
	ST		Z+,R20  
    POP           R20
    RET                  

LED7SEG_PORTINIT:
	PUSH	R20
	LDI R20, 0B11111111 ; SET LED7SEG PORT AS OUTPUT
	OUT LED7SEGDIR, R20
	IN R20, LED7SEGLATCHDIR	; READ THE LATCH PORT DIRECTION REGISTER
    ORI R20, (1<<NLE0PIN) | (1 << NLE1PIN)
	OUT LED7SEGLATCHDIR,R20 
	POP	R20
	RET; 

;DISPLAY A VALUE ON A 7-SEGMENT LED USING A LOOKUP TABLE
; INPUT: R27 CONTAINS THE VALUE TO DISPLAY
;		R26 CONTAIN THE LED INDEX (3..0)
;		J34 CONNECT TO PORTD
;		NLE0 CONNECT TO PB4
;		NLE1 CONNECT TO PB5
; OUTPUT: NONE
DISPLAY_7SEG:
    PUSH R16 ; SAVE THE TEMPORARY REGISTER

    ; LOOK UP THE 7-SEGMENT CODE FOR THE VALUE IN R18
    ; NOTE THAT THIS ASSUMES A COMMON ANODE DISPLAY, WHERE A HIGH OUTPUT TURNS OFF THE SEGMENT
    ; IF USING A COMMON CATHODE DISPLAY, INVERT THE VALUES IN THE TABLE ABOVE
	LDI		ZH,HIGH(TABLE_7SEG_DATA<<1)	; 
	LDI		ZL,LOW(TABLE_7SEG_DATA<<1)	;
	CLR		R16
    ADD		R30, R27
	ADC		R31,R16

    LPM		R16, Z
	OUT		LED7SEGPORT,R16
	SBI		LED7SEGLATCHPORT,NLE0PIN
	NOP
	CBI		LED7SEGLATCHPORT,NLE0PIN
	LDI		ZH,HIGH(TABLE_7SEG_CONTROL<<1)	; 
	LDI		ZL,LOW(TABLE_7SEG_CONTROL<<1)	;
	CLR		R16
    ADD		R30, R26
	ADC		R31,R16
	LPM		R16, Z
	OUT		LED7SEGPORT,R16
	SBI		LED7SEGLATCHPORT,NLE1PIN
	NOP
	CBI		LED7SEGLATCHPORT,NLE1PIN
    POP		R16 ; RESTORE THE TEMPORARY REGISTER
    RET ; RETURN FROM THE FUNCTION

INITTIMER1CTC:
	  PUSH	R16
	  LDI R16, HIGH(5000)  ; LOAD THE HIGH  YTE INTO THE TEMPORARY REGISTER
	  STS OCR1AH, R16       ; SET THE HIGH BYTE OF THE TIMER 1 COMPARE VALUE 
	  LDI R16, LOW(5000)   ; LOAD THE LOW BYTE INTO THE TEMPORARY REGISTER
	  STS OCR1AL, R16       ; SET THE LOW BYTE OF THE TIMER 1 COMPARE VALUE 
	  LDI R16,  (1 << CS11)| (1<< WGM12) ;MODE CTC4; CLK/8
	  STS TCCR1B, R16       ; T SCANLED = 125*10^-9*8*X
	  LDI R16, (1 << OCIE1A); LOAD THE VALUE 0B00000010 INTO THE TEMPORARY REGISTER
	  STS TIMSK1, R16       ; ENABLE THE TIMER 1 COMPARE A INTERRUPT
	  POP	R16
	  RET

TIMER1_COMP_ISR:
	PUSH	R16
	PUSH	R26
	PUSH	R27
	LDI		R31,HIGH(LED7SEGINDEX)
	LDI		R30,LOW(LED7SEGINDEX)
	LD		R16,Z
	MOV		R26,R16
	LDI		R31,HIGH(LED7SEGVALUE)
	LDI		R30,LOW(LED7SEGVALUE)
	ADD		R30,R16
	CLR		R16
	ADC		R31,R16
	LD		R27,Z
	CALL	DISPLAY_7SEG
	
	CPI		R26,0
	BRNE	TIMER1_COMP_ISR_CONT
	LDI		R26,4	;IF R16 = 0, RESET TO 3
TIMER1_COMP_ISR_CONT:
	DEC		R26			;ELSE, DECREASE
	LDI		R31,HIGH(LED7SEGINDEX)
	LDI		R30,LOW(LED7SEGINDEX)
	ST		Z,R26

	POP		R27
	POP		R26
	POP		R16
	RETI

; LOOKUP TABLE FOR 7-SEGMENT CODES
TABLE_7SEG_DATA:	
    .DB		0XC0,0XF9,0XA4,0XB0,0X99,0X92,0X82,0XF8,0X80,0X90,0X88,0X83	
    .DB		0XC6,0XA1,0X86,0X8E
; LOOKUP TABLE FOR LED CONTROL
TABLE_7SEG_CONTROL:		
    .DB		0B00001110,0B00001101, 0B00001011, 0B00000111