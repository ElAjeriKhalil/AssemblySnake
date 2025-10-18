;	set game state memory location
.equ    HEAD_X,         0x1000  ; Snake head's position on x
.equ    HEAD_Y,         0x1004  ; Snake head's position on y
.equ    TAIL_X,         0x1008  ; Snake tail's position on x
.equ    TAIL_Y,         0x100C  ; Snake tail's position on Y
.equ    SCORE,          0x1010  ; Score address
.equ    GSA,            0x1014  ; Game state array address

.equ    CP_VALID,       0x1200  ; Whether the checkpoint is valid.
.equ    CP_HEAD_X,      0x1204  ; Snake head's X coordinate. (Checkpoint)
.equ    CP_HEAD_Y,      0x1208  ; Snake head's Y coordinate. (Checkpoint)
.equ    CP_TAIL_X,      0x120C  ; Snake tail's X coordinate. (Checkpoint)
.equ    CP_TAIL_Y,      0x1210  ; Snake tail's Y coordinate. (Checkpoint)
.equ    CP_SCORE,       0x1214  ; Score. (Checkpoint)
.equ    CP_GSA,         0x1218  ; GSA. (Checkpoint)

.equ    LEDS,           0x2000  ; LED address
.equ    SEVEN_SEGS,     0x1198  ; 7-segment display addresses
.equ    RANDOM_NUM,     0x2010  ; Random number generator address
.equ    BUTTONS,        0x2030  ; Buttons addresses

; button state
.equ    BUTTON_NONE,    0
.equ    BUTTON_LEFT,    1
.equ    BUTTON_UP,      2
.equ    BUTTON_DOWN,    3
.equ    BUTTON_RIGHT,   4
.equ    BUTTON_CHECKPOINT,    5

; array state
.equ    DIR_LEFT,       1       ; leftward direction
.equ    DIR_UP,         2       ; upward direction
.equ    DIR_DOWN,       3       ; downward direction
.equ    DIR_RIGHT,      4       ; rightward direction
.equ    FOOD,           5       ; food

; constants
.equ    NB_ROWS,        8       ; number of rows
.equ    NB_COLS,        12      ; number of columns
.equ    NB_CELLS,       96      ; number of cells in GSA
.equ    RET_ATE_FOOD,   1       ; return value for hit_test when food was eaten
.equ    RET_COLLISION,  2       ; return value for hit_test when a collision was detected
.equ    ARG_HUNGRY,     0       ; a0 argument for move_snake when food wasn't eaten
.equ    ARG_FED,        1       ; a0 argument for move_snake when food was eaten

; initialize stack pointer
addi    sp, zero, LEDS

main:
   call init_game                  ; Initialize game settings

main_loop:
    call get_input                  ; Get user input. Expect button state in v0.

    addi t0,zero, BUTTON_CHECKPOINT
    cmpne t1, v0, t0
    beq t1, zero, check_restore_checkpoint  ; Check if checkpoint button is pressed

    call hit_test                   ; Check for collision or if food is eaten. Expect result in v0.
    addi t0,zero, RET_ATE_FOOD
    cmpne t1, v0, t0
    beq t1, zero, handle_ate_food            ; If food is eaten

    addi t0,zero, RET_COLLISION
    cmpne t1, v0, t0
    beq t1, zero, handle_collision           ; If a collision occurred

    addi a0,zero, ARG_HUNGRY              ; Pass argument for move_snake indicating no food eaten
    call move_snake                  ; Move the snake
    call clear_leds                  ; Clear the LEDs
    call draw_array                  ; Draw the snake on the display
    jmpi main_loop                     ; Repeat the game loop

check_restore_checkpoint:
    call restore_checkpoint         ; Attempt to restore the game to a saved state
    jmpi main_loop                    ; Continue the game loop

handle_ate_food:
    call increase_score             ; Increase the score
    call display_score              ; Display the new score
    addi a0,zero, ARG_FED                ; Pass argument for move_snake indicating food has been eaten
    call move_snake                 ; Move the snake
    call create_food                ; Create new food
    call save_checkpoint            ; Save checkpoint if applicable
    jmpi main_loop                    ; Continue the game loop

handle_collision:
    call blink_score                ; Blink the score to indicate game over
    jmpi main_loop                    ; Game over, could potentially restart or halt

increase_score:
    ldw s2, SCORE(zero)             ; Load current score
    addi s2, s2, 1                  ; Increment score
    stw s2, SCORE(zero)             ; Store back the score
    ret                           ; Return from sujmpioutine

; END: main

; BEGIN: clear_leds
clear_leds:

stw zero, LEDS(zero)
addi t0, zero, 4
stw zero, LEDS(t0)
addi t0, zero, 8
stw zero, LEDS(t0)
ret

; END: clear_leds


; BEGIN: set_pixel
set_pixel:

ldw t0, LEDS(zero)
addi t3, zero, 4 
ldw t1, LEDS(t3)
addi t3, t3,4
ldw t2, LEDS(t3)

andi t3, a0, 3 ;mod 4
slli t3, t3, 3 
add t3, t3, a1
addi t4, zero, 1
sll t3, t4, t3

cmpgei t5, a0, 4   ; x>= 4
cmplti t6, a0, 8   ; x <8
and t6, t5, t6
addi t5, zero, 1
cmpgei t7, a0, 8   ; x>= 8

beq t7, t5, Led2
beq t6, t5, Led1

or t0, t3, t0        
stw t0, LEDS(zero)
ret 

Led1:
	or t1, t3, t1
    addi t4, zero, 4
	stw t1, LEDS(t4)
	ret
	
Led2:
	or t2, t3, t2
    addi t4, zero,8
	stw t2, LEDS(t4)
	ret
 

; END: set_pixel


; BEGIN: display_score
display_score:

stw zero, SEVEN_SEGS(zero)
addi t0, zero, 4
stw zero, SEVEN_SEGS(t0)


ldw t0, SCORE(zero)
andi t1, t0, 9
sub t2, t0, t1

add t5, zero, zero
addi t3, zero, 10
bge t0, t3, loop_for_10s

here:

slli t1, t1, 2
ldw t6, digit_map(t1)
addi t7, zero, 12
stw t6, SEVEN_SEGS(t7)

slli t5, t5, 2
ldw t6, digit_map(t5)
addi t7, zero, 8
stw t6, SEVEN_SEGS(t7)

ret


loop_for_10s:
addi t4, t0, -10
addi t5, t5, 1
bge t4, zero, loop_for_10s
jmpi here


; END: display_score



; BEGIN: create_food
create_food:

loop:

ldw t0, RANDOM_NUM(zero)
andi t0,t0, 0xFF
ldw t1, GSA(t0)


andi t2, t0, 7   ; y
sub t3, t0, t2
srli t3, t3 , 3   ; x

cmplti t4, t3, 12
cmpgei t5, t3, 0
cmplti t6, t2, 8
cmpgei t7, t2,0

and t4, t4, t5
and t5, t6, t7
and t4, t4, t5 

beq t4, zero, loop
bne t1, zero, loop

addi t2, zero, FOOD

slli t0, t0, 2
stw t2, GSA(t0)


ret
; END: create_food


; BEGIN: hit_test
hit_test:

ldw t0 , HEAD_X(zero) ; x
ldw t1, HEAD_Y(zero) ; y

slli t2, t0, 3 ; x*8
add t3, t1, t0 ; x*8 + y
slli t3, t3, 2
ldw t4, GSA(t3) ; value direction at cell  8x+y

addi t0, zero, DIR_LEFT
beq t4, t0, go_left
addi t0, zero, DIR_UP
beq t4, t0, go_up
addi t0, zero, DIR_DOWN
beq t4, t0, go_down
addi t0, zero, DIR_RIGHT
beq t4, t0, go_right

go_left:
addi t5, t0, -1
add t6, zero, t1
jmpi next
go_up:
addi t6, t1, 1
add t5, zero, t0
jmpi next
go_down:
addi t6, t1, 1
add t5, zero, t0
jmpi next
go_right:
addi t5, t0, 1
add t6, zero, t1
jmpi next

next: 
add v0, zero, zero
cmplti t2, t5, 12
cmpgei t3, t5, 0
cmplti t4, t6, 8
cmpgei t7, t6,0

and t2, t2, t3
and t4, t4, t7
and t4, t4, t2 
beq t4, zero, end

slli t0, t5, 3 
add t1, t0, t6
slli t1, t1, 2
ldw t0, GSA(t1)

addi t1, zero, FOOD
beq t1, t0, get_food
bne t0, zero, mort_snake

ret
get_food: 
addi v0, v0, 1
ret
mort_snake:
addi v0, v0, 2
ret

end:
ret

; END: hit_test


; BEGIN: get_input
get_input:

addi v0, zero, 0
ldw t3 , HEAD_X(zero) ; x
ldw t4, HEAD_Y(zero) ; y

slli t3, t3, 3 ; x*8
add t3, t3, t4 ; x*8 + y
slli t3, t3, 2; t3 *4 pour l'addresse
ldw t4, GSA(t3) ; value of cell at index 8x+y

addi t0 , zero, 4 ; t0 = 4 
ldw t1, BUTTONS(t0) ;  BUTTON +4 for edgecapture 
andi t6, t1, 0xFFE0 ;full 1 sauf les 5 derniers bits
stw t6, BUTTONS(t0)

addi t0, zero, 16; 6th bit only set to 1 for checkpoint in edgecapture
and t2, t0, t1
bne t2, zero, checkpoint_pressed
srli t0,t0, 1
and t2, t1,t0
bne t2, zero, right_pressed
srli t0,t0, 1
and t2, t1,t0
bne t2, zero, down_pressed
srli t0,t0, 1
and t2, t1,t0
bne t2, zero, up_pressed
srli t0,t0, 1
and t2, t1,t0
bne t2, zero, left_pressed

checkpoint_pressed:
addi v0, zero, BUTTON_CHECKPOINT

left_pressed:

addi v0, zero, BUTTON_LEFT
addi t0, zero, BUTTON_RIGHT
addi t5, zero, DIR_LEFT
bne t4, t0, move
ret

up_pressed:
addi v0, zero, BUTTON_UP
addi t0, zero, BUTTON_DOWN
addi t5, zero, DIR_UP
bne t4, t0, move
ret

down_pressed:
addi v0, zero, BUTTON_DOWN
addi t0, zero, BUTTON_UP
addi t5, zero, DIR_DOWN
bne t4, t0, move
ret

right_pressed:
addi v0, zero, BUTTON_RIGHT
addi t0, zero, BUTTON_LEFT
addi t5, zero, DIR_RIGHT
bne t4, t0, move
ret

move:
stw t5, GSA(t3)
ret

; END: get_input


; BEGIN: draw_array
draw_array:

    addi t0, zero, 0  ;  index
    ;wait
loop_gsa:
    slli t1, t1, 2  ;x4 pr ladresse
    ldw t1, GSA(t0)
    beq t1, zero, skip

    andi t2, t0, 7   ; y
    sub t5, t0, t2
    srli t5, t5 , 3   ; x

    add a0, zero, t5
    add a1, zero, t2

    addi sp, sp , -4
    stw t0, 0(sp)
    addi sp, sp , -4
    stw t1, 0(sp)
    addi sp, sp , -4
    stw ra, 0(sp)

    call wait 
    call set_pixel
    
    ldw ra , 0(sp) 
    addi sp, sp, 4
    ldw t1, 0(sp)
    addi sp, sp , 4
    ldw t0, 0(sp)
    addi sp, sp , 4


skip:

    addi t0, t0, 1
    cmplti t4, t0, 96
    bne t4, zero, loop_gsa

    ret
; END: draw_array


; BEGIN: move_snake
move_snake:

bne a0, zero, head_mana

ldw t6, TAIL_X(zero)
ldw t7, TAIL_Y(zero)
slli t2, t6, 3 ; x*8
add t2, t7, t2 ; x*8 + y
slli t2, t2, 2 ;x4 pr adresse
ldw t3, GSA(t2) ; value of cell at index 8x+y // TAIL

addi t4, zero, DIR_LEFT
beq t3, t4, tail_left
addi t2, zero, DIR_UP
beq t3, t4, tail_up
addi t4, zero, DIR_DOWN
beq t3, t4, tail_down
addi t4, zero, DIR_RIGHT
beq t3, t4, tail_right

tail_left:
addi t4, t6, -1
stw t4, TAIL_X(zero)
addi t2, t2, -32
stw t3, GSA(t2)
jmpi head_mana

tail_up:
addi t4, t6, -1
stw t4, TAIL_Y(zero)
addi t2, t2, -4
stw t3, GSA(t2)
jmpi head_mana

tail_down:
addi t4, t6, 1
stw t4, TAIL_Y(zero)
addi t2, t2, 4
stw t3, GSA(t2)
jmpi head_mana


tail_right:
addi t4, t6, 1
stw t4, TAIL_X(zero)
addi t2, t2, 32
stw t3, GSA(t2)


head_mana:
ldw t4 , HEAD_X(zero) ; x
ldw t5, HEAD_Y(zero) ; y

slli t0, t4, 3 ; x*8
add t0, t5, t0 ; x*8 + y
slli t0, t0, 2
ldw t1, GSA(t0) ; value of cell at index 8x+y // HEAD

addi t2, zero, DIR_LEFT
beq t1, t2, head_left
addi t2, zero, DIR_UP
beq t1, t2, head_up
addi t2, zero, DIR_DOWN
beq t1, t2, head_down
addi t2, zero, DIR_RIGHT
beq t1, t2, head_right


head_left:
addi t3, t4, -1
stw t3, HEAD_X(zero)
addi t0, t0, -32
stw t1, GSA(t0)
ret

head_up:
addi t3, t5, -1
stw t3, HEAD_Y(zero)
addi t0, t0, -4
stw t1,GSA(t0)
ret

head_down:
addi t3, t5, 1
stw t3, HEAD_Y(zero)
addi t0, t0, 4
stw t1,GSA(t0)
ret

head_right:
addi t3, t4, 1
stw t3, HEAD_X(zero)
addi t0, t0, 32
stw t1,GSA(t0)
ret


; END: move_snake


; BEGIN: save_checkpoint
save_checkpoint:
ldw t0, SCORE(zero)
andi t0, t0, 9
beq t0, zero, asav
addi v0, zero, 0
ret

asav:
addi t1, zero, 1
stw t1, CP_VALID(zero)

addi a0, zero, 0x1000
addi a1, zero, 0x1204
addi sp, sp, 4
stw ra, 0(sp)
call cop_mem
ldw ra, 0(sp)
addi sp, sp, -4
addi v0, zero, 1

ret



; END: save_checkpoint


; BEGIN: restore_checkpoint
restore_checkpoint:

ldw t0, CP_VALID(zero)
bne t0, zero, cbon
addi v0, zero, 0
ret
cbon:
addi a0, zero, 0x1204
addi a1, zero, 0x1000
addi sp, sp, 4
stw ra, 0(sp)
call cop_mem
ldw ra, 0(sp)
addi sp, sp, -4
addi v0, zero, 1
ret
; END: restore_checkpoint


; BEGIN: blink_score
blink_score:
addi t1, zero, 3

blink_loop: 
addi t0, zero, 4
stw zero, SEVEN_SEGS(zero)
stw zero, SEVEN_SEGS(t0)
addi t0, t0, 4
stw zero, SEVEN_SEGS(t0)
addi t0, t0, 4
stw zero, SEVEN_SEGS(t0)

addi sp, sp, -4
stw t1, 0(sp)
addi sp, sp, -4
stw ra , 0(sp)

call wait 
call display_score

ldw ra , 0(sp) 
addi sp, sp, 4
ldw t1, 0(sp)
addi sp, sp, 4

addi t1, t1, -1
bne t1, zero, blink_loop

ret

; END: blink_score

;--------------------------------------

; BEGIN: init_game
init_game:

stw zero, HEAD_X(zero)
stw zero, HEAD_Y(zero)
stw zero, TAIL_X(zero)
stw zero, TAIL_Y(zero)
stw zero, SCORE(zero)

stw zero, CP_HEAD_X(zero)
stw zero, CP_HEAD_Y(zero)
stw zero, CP_TAIL_X(zero)
stw zero, CP_TAIL_Y(zero)
stw zero, CP_SCORE(zero)

addi sp, sp, -4
stw ra , 0(sp)
call create_food
ldw ra , 0(sp) 
addi sp, sp, 4

addi t0, zero, 4

stw t0, CP_GSA(zero)
stw t0, GSA(zero)

; END: init_game

; BEGIN: wait
wait:

    addi t0, zero, 30000

wait_loop:

    addi t0, t0, -1
    bne t0, zero , wait_loop

    ret
; END: wait

; BEGIN: cop_mem
cop_mem:
    ; Arguments: 
    ; a0: Source address
    ; a1: Destination address
    ; a2: Number of bytes to copy
    addi a2, zero, 0x1204

loop_for_mem:

    ldw   t0, 0(a0)        ; Load byte from source+
    stw   t0, 0(a1)        ; Store byte to destination
    addi a0, a0, 4        ; Increment source address
    addi a1, a1, 4        ; Increment destination address
    addi a2, a2, 4       ; Decrement counter
    addi t0, zero, 0x1603
    blt a2, t0, loop_for_mem         ; If counter not zero, loop again

    ret
; END: cop_mem

digit_map:
.word 0xFC ; 0
.word 0x60 ; 1
.word 0xDA ; 2
.word 0xF2 ; 3
.word 0x66 ; 4
.word 0xB6 ; 5
.word 0xBE ; 6
.word 0xE0 ; 7
.word 0xFE ; 8
.word 0xF6 ; 9
