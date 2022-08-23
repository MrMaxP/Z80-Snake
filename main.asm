		DEVICE ZXSPECTRUM48
		SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION, OUTPUT

		DEFINE	BACKGROUND_COLOUR	%00111111
		DEFINE	SNAKE_COLOUR		%00000000
		DEFINE	APPLE_COLOUR		%00100100

		org	8000h

; Memory for our block array
; Max possible size of w * h * 2 (2 = x, y pos)
SnakePosArray	BLOCK	32*24*2
SnakePosArrayEnd
SnakeLen	DW	0
ApplePos	DW	0
SnakeHeadPos	DW	0
SnakeDirection	DW	0
FrameDelay	DB	10
FrameDelayCounter	DB	10
SnakeHeadAttribute	DB	0
AppleEaten		DB	0


; ---------------------------------------------------------------------------
Start
	di
	call	SetInterrupts
	ei

Restart
	; Clear the bitmap screen

	ld	hl, $4000
	ld	bc, $1800
	ld	e, 0
	call	Clear

	; Clear the screen attributes

	ld	hl, $5800
	ld	bc, $0300
	ld	e, BACKGROUND_COLOUR
	call	Clear


	; Clear the snake pos array

	ld	hl, SnakePosArray
	ld	bc, SnakePosArrayEnd - SnakePosArray
	ld	e, 0
	call	Clear

	; Set the border to blue
	ld	a, %001
	out	($fe), a
Init
	; Set our snake's initial position and step it while setting the grow flag to make it 3 long

	ld	hl, $0008
	ld	(SnakeHeadPos), hl
	ld	hl, $0100
	ld	(SnakeDirection), hl
	ld	hl, 0
	ld	(SnakeLen), hl

	ld	a, 1
	call	UpdateSnake
	call	UpdateSnake
	call	UpdateSnake

	call	PlaceApple

.loop
	call	DrawApple

	call	PlayerInput

	; Decrement the frame delay
	ld	hl, FrameDelayCounter
	dec	(hl)
	jr	nz, .skipMove

	; Reset frame delay
	ld	a, (FrameDelay)
	ld	(FrameDelayCounter), a

	ld	a, (AppleEaten)
	call	UpdateSnake
	xor	a
	ld	(AppleEaten), a

	call	TestSnakeHead
.skipMove
	ld	a, %001
	out	($fe), a
	halt
	ld	a, %100
	out	($fe), a

	jr	.loop

TestSnakeHead
	ld	a, (SnakeHeadAttribute)
	cp	BACKGROUND_COLOUR
	ret	z

	cp	SNAKE_COLOUR
	jr	nz, .stillAlive

	ld	c, 0
.GameOver
	djnz	$
	ld	a, %010
	out	($fe), a
	djnz	$
	ld	a, %001
	out	($fe), a

	dec	c
	jr	nz, .GameOver

	jp	Restart

.stillAlive
	cp	APPLE_COLOUR
	jr	nz, .notEatenApple

	ld	a, 1
	ld	(AppleEaten), a

	call	PlaceApple

	ld	a, (FrameDelay)
	dec	a
	jr	z, .skip
	ld	(FrameDelay), a
.skip

.notEatenApple
	ret

PlayerInput
	; Read the keyboard. We're using Q, A, O, P for cursor movement


	; Get the x dir and if it's not zero we're already moving in x so skip any X dir change
	ld	a, (SnakeDirection)
	or	a
	jr	nz, .noXChange

	; Test the keyboard bit associated with the O (left) key
	ld	a, $df
	in	a,($fe)
	bit	1, a
	jr	nz, .noLeft

	; set the snakes X dir to FF i.e. -1 so when we add it to X we go left
	ld	hl, $00FF
	ld	(SnakeDirection), hl
	ret
.noLeft
	ld	a, $df
	in	a,($fe)
	bit	0, a
	jr	nz, .noRight
	ld	hl, $0001
	ld	(SnakeDirection), hl
	ret
.noRight
.noXChange

	; Get the y dir and if it's not zero we're already moving in y so skip any y dir change
	ld	a, (SnakeDirection+1)
	or	a
	jr	nz, .noYChange


	ld	a, $fb
	in	a,($fe)
	bit	0, a
	jr	nz, .noUp
	ld	hl, $FF00
	ld	(SnakeDirection), hl
	ret
.noUp
	ld	a, $fd
	in	a,($fe)
	bit	0, a
	jr	nz, .noDown
	ld	hl, $0100
	ld	(SnakeDirection), hl
	ret
.noDown
.noYChange
	ret


DrawApple
	ld	bc,(ApplePos)
	ld	a, APPLE_COLOUR
	call	Plot
	ret

UpdateSnake
	push	af
	; move the snake in the current direction
	; if a is non-zero then expand the snake

	or	a
	jr	nz, .skipArrayShift

	ld	hl, SnakePosArray
	ld	de, SnakePosArray

	; Clear snake tail and increment HL to point to the new tail
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	inc	hl
	ld	a, BACKGROUND_COLOUR
	call	Plot

	ld	bc, (SnakeLen)
.lp
// move xpos
	ld	a, (hl)
	ld	(de), a
	inc	hl
	inc	de

// move ypos
	ld	a, (hl)
	ld	(de), a
	inc	hl
	inc	de

	dec	bc
	ld	a, b
	or	c
	jr	nz, .lp

.skipArrayShift
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
	jp	p, .noNeg

	; The y pos went negative, add 24 to bring it back on the bottom
	add	24
.noNeg
	cp	24
	jr	c, .noWrap

	; The y pos was above our screen max y, subtract screen height to bring it back to the top
	sub	24
.noWrap
	ld	b, a
	ld	(SnakeHeadPos), bc

	ld	a, SNAKE_COLOUR
	call	Plot

	ld	(SnakeHeadAttribute), a

	pop	af

	or	a
	jr	z, .skipIncLen

	ld	hl, (SnakeLen)
	inc	hl
	ld	(SnakeLen), hl

.skipIncLen
	ld	de, (SnakeLen)
	ld	hl, SnakePosArray
	add	hl, de
	add	hl, de

	ld	(hl), c
	inc	hl
	ld	(hl), b

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
	; doesn't corrupt BC, DE, HL
	; returns a as the attribute of the plot pos before it was written over

	push	bc
	push	de
	push	hl
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

	ld	c, (hl)

	pop	af

	ld	(hl), a	; write the value
	ld	a, c

	pop	hl
	pop	de
	pop	bc

	ret

Rnd
	; Awesome random number generator stolen from the internet
	; (note the self modifying code)

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
	ld	a, h
	ld	i, a

	ld	b, 0
.InterruptLP
	ld	(hl), $fe
	inc	hl
	djnz	.InterruptLP
	ld	(hl), $fe

	im	2

	ret

	ORG		$FEFE
IM2Routine
	ei
	reti

; Make sure this is on a 256 byte boundary
	ORG           $FD00
VectorTable
        defs          256


	savesna "main.sna",Start
