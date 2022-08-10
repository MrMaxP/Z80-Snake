		DEVICE ZXSPECTRUM48
		SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION, OUTPUT

		DEFINE	BACKGROUND_COLOUR	%00111111
		DEFINE	SNAKE_COLOUR		%00000000

		org	8000h

; Memory for our block array
; Max possible size of w * h * 2 (2 = x, y pos)
SnakePosArray	BLOCK	32*24*2
SnakePosArrayEnd
SnakeLen	DW	0
ApplePos	DW	0
SnakeHeadPos	DW	0
SnakeDirection	DW	$0100
FrameDelay	DB	10
FrameDelayCounter	DB	10


; ---------------------------------------------------------------------------
Start
	di

	call	SetInterrupts

	; Clear the screen

	ld	hl, $4000
	ld	bc, $1800
	ld	e, 0
	call	Clear

	; Clear the snake pos array

	ld	hl, SnakePosArray
	ld	bc, SnakePosArrayEnd - SnakePosArray
	ld	e, 0
	call	Clear

	ei
Init
	; Set our snake's initial position and step it while setting the grow flag to make it 3 long

	ld	bc, $FF08
	ld	(SnakeHeadPos), bc

	ld	a, 1
	call	UpdateSnake
	call	UpdateSnake
	call	UpdateSnake

	call	PlaceApple

.loop
     	ld	a,r
     	out	(254),a

	call	DrawApple

	; Decrement the frame delay
	ld	hl, FrameDelayCounter
	dec	(hl)
	jr	nz, .skipMove

	; Reset frame delay
	ld	a, (FrameDelay)
	ld	(FrameDelayCounter), a

	xor	a
	call	UpdateSnake
.skipMove
	halt
	jr	.loop

DrawApple
	ld	bc,(ApplePos)
	ld	a, %00100100
	call	Plot
	ret

UpdateSnake
	push	af
	; move the snake in the current direction
	; if a is non-zero then expand the snake

	or	a
	jr	nz, .skipMove

	ld	hl, SnakePosArray + 2
	ld	de, SnakePosArray
	ld	bc, (SnakeLen)
.lp
	push bc

// move xpos
	ld	a, (hl)
	ld	(de), a
	ld	c, a
	inc	hl
	inc	de

// move ypos
	ld	a, (hl)
	ld	(de), a
	ld	b, a
	inc	hl
	inc	de

	ld	a, BACKGROUND_COLOUR
	call	Plot

	pop	bc

	dec	bc
	ld	a, b
	or	c
	jr	nz, .lp

.skipMove
	; SnakeHeadPos is stored as x and y bytes. Pull them out into H and L in one operation
	ld	hl, (SnakeHeadPos)
	; SnakeDirection is stored as the value to add to x and y.
	; They will either be 1 or -1. -1 is represented at 255, adding 255 to a byte will wrap it to 1 less than its original value.
	ld	bc, (SnakeDirection)

	; Add the x direction to the x position
	ld	a, l
	add	c
	and	31	; And the bottom 5 bits (screen is 32 bytes wide) to keep the x within the screen range
	ld	c, A

	; Add the y direction to the y position
	ld	a, h
	add	b
	jr	nc, .noNeg

	; The y pos went negative, add 24 to bring it back on the bottom
	add	24
.noNeg
	cp	24
	jr	c, .noWrap

	; The y pas was above our screen max y, subtract screen height to bring it back to the top
	sub	24
.noWrap
	ld	b, a
	ld	(SnakeHeadPos), bc

	ld	a, SNAKE_COLOUR
	call Plot

	ld	de, (SnakeLen)
	ld	hl, SnakePosArray
	add	hl, de
	add	hl, de

	ld	(hl), c
	inc	hl
	ld	(hl), b

	pop	af

	or	a
	ret	z

	ld	hl, (SnakeLen)
	inc	hl
	ld	(SnakeLen), hl

	ret

PlaceApple
	call	Rnd
	and	a, 31
	ld	(ApplePos), a
.lp
	call	Rnd
	and	a, 31
	cp	a, 24
	jr	nc, .lp
	ld	(ApplePos+1), a
	ret

Clear
	ld	(hl), e
	inc	hl
	dec	bc
	ld	a, b
	or	c
	jr	nz, Clear
	ret

Plot
	; Plots a colour character at C = X, B = Y, A = colour
	; doesn't corrupt HL, DE
	; corrupts A

	push	hl
	push	de
	push	af

	ld	l, b	; Load the HL register pair with the Y pos
	ld	h, 0
	add	hl, hl	; Multiply it by 32 (raise to the power of 5 by doubling)
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl

	ld	a, c	; Get the X pos and OR it into L
	or	l
	ld	l, a

	ld	de, $5800	; Ass the base address of the attribute map
	add	hl, de

	pop	af

	ld	(hl), a	; write the value

	pop	de
	pop	hl

	ret

Rnd
	; Awesome randome number generator stolen from the internet

	ld 	hl,0xA280   ; yw -> zt
        ld 	de,0xC0DE   ; xz -> yw
        ld 	(Rnd+4),hl  ; x = y, z = w
        ld 	a,l         ; w = w ^ ( w << 3 )
        add	a,a
        add	a,a
        add	a,a
        xor	l
        ld 	l,a
        ld 	a,d         ; t = x ^ (x << 1)
        add	a,a
        xor	d
        ld 	h,a
        rra  	           ; t = t ^ (t >> 1) ^ w
        xor	h
        xor	l
        ld 	h,e         ; y = z
        ld 	l,a         ; w = t
        ld 	(Rnd+1),hl
        ret

SetInterrupts
	ld	hl, VectorTable
	ld	de, IM2Routine
	ld	b, 128

	ld	a, h
	ld	i, a
.InterruptLP
	ld	(hl), e
	inc	hl
	ld	(hl), d
	inc	hl
	djnz	.InterruptLP

	im	2

	ret
IM2Routine
	ei
	reti

; Make sure this is on a 256 byte boundary
	ORG           $F000
VectorTable
        defs          256


	savesna "main.sna",Start
