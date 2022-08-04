		DEVICE ZXSPECTRUM48
		SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION, OUTPUT

		org	8000h

; Memory for our block array
; Max possible size of w * h * 2 (2 = x, y pos)
SnakePosArray	BLOCK	32*24*2
SnakePosArrayEnd
SnakeLen	DW	0
ApplePos	DW	0
SnakeHeadPos	DW	0
SnakeDirection	DW	$0100


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
	call	StepSnake
	call	StepSnake
	call	StepSnake

	call	PlaceApple

.loop
     	ld	a,r
     	out	(254),a

	call	DrawApple
	call	DrawSnake

	xor	a
	call	StepSnake

	halt
	jr	.loop

DrawApple
	ld	bc,(ApplePos)
	ld	a, %00100100
	call	Plot
	ret

DrawSnake
	ld	de, (SnakeLen)
	ld	hl, SnakePosArray
.lp
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	inc	hl

	ld	a, 0
	call	Plot

	dec	de
	ld	a, d
	or	e
	jr	nz, .lp

	ret

StepSnake
	push	af
	; move the snake in the current direction
	; if a is non-zero then expand the snake

	; Do it the bad way (i.e. NOT using a circular buffer)

	or	a
	jr	nz, .skipMove

	ld	hl, SnakePosArray + 1
	ld	de, SnakePosArray
	ld	bc, (SnakeLen)
.lp
	ld	a, (hl)
	ld	(de), a
	inc	hl
	inc	de
	dec	bc
	ld	a, b
	or	c
	jr	nz, .lp

.skipMove
	ld	hl, (SnakeHeadPos)
	ld	bc, (SnakeDirection)

	; Add the direction to the position (do each byte separately so a carry on the X doesn't affect the Y etc.)
	ld	a, l
	add	c
	ld	c, A

	ld	a, h
	add	b
	ld	b, a
	ld	(SnakeHeadPos), bc

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
	; doesn't corrupt BC, DE
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
