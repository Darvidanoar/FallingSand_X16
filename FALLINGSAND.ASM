.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

   jmp start

; Zero Page
MOUSE_X           = $32
MOUSE_Y           = $34
V_COORD           = $36
ARR_COLOUR_PTR    = $39
ARR_LOADDR_PTR    = $3B
ARR_HIADDR_PTR    = $3D
ARR_BKADDR_PTR    = $3F
TST_LOADDR_PTR    = $41
TST_HIADDR_PTR    = $42
TST_BKADDR_PTR    = $43


; RAM Interrupt Vectors
IRQVec            = $0314

; VERA
VERA_addr_low     = $9F20
VERA_addr_high    = $9F21
VERA_addr_bank    = $9F22
VERA_data0        = $9F23
VERA_ctrl         = $9F25
VERA_ien          = $9F26
VERA_isr          = $9F27
VSYNC_BIT         = $01
VERA_dc_video     = $9F29
VERA_dc_hscale    = $9F2A
VERA_dc_vscale    = $9F2B
DISPLAY_SCALE     = 64 ; 2X zoom
VERA_L0_config    = $9F2D
VERA_L0_tilebase  = $9F2F
VERA_L0_hscroll_h = $9F31
BITMAP_PAL_OFFSET = VERA_L0_hscroll_h

; Kernal
SCREEN_MODE       = $FF5F
SETLFS            = $FFBA
SETNAM            = $FFBD
LOAD              = $FFD5
GETIN             = $FFE4
MOUSE_CONFIG      = $FF68
MOUSE_GET         = $FF6B
CHROUT            = $FFD2

; PETSCII
CHAR_Q            = $51

; VRAM Addresses
VRAM_bitmap       = $00000
VRAM_palette      = $1FA00

; ARRAY DATA
ARRAY             = $0C00
   


; global data
default_irq_vector:  .addr 0


paint_color:         .byte $01

start:
   stz VERA_dc_video ; disable display

   ; scale display to 2x zoom (320x240)
   lda #DISPLAY_SCALE
   sta VERA_dc_hscale
   sta VERA_dc_vscale

   ; configure layer 0
   lda #$07 ; 8bpp bitmap  
   sta VERA_L0_config

   ; enable layer 0, output mode VGA
   lda #$11
   sta VERA_dc_video

   ; initialise
   jsr clear_screen
   jsr clear_array
   jsr draw_palette


   ; enable default mouse cursor
   lda #0
   sec
   jsr SCREEN_MODE
   lda #$01
   ldx #$28
   ldy #$1E
   jsr MOUSE_CONFIG


main_loop:
   jsr get_mouse_xy
   bit #$01 
   beq check_kbd
   lda MOUSE_Y + 1
   bne go_paint_canvas
   lda MOUSE_Y
   and #%11110000
   bne go_paint_canvas
   jsr getPaintColor
   bra main_loop
go_paint_canvas:
   jsr add_pixel
check_kbd:
   jsr array_fall
   jsr GETIN
   cmp #CHAR_Q
   bne main_loop
   ; Q pressed 

   ; reset screen mode
   lda #0
   clc
   jsr SCREEN_MODE
   ; enable layer 1 only
   lda #$21
   sta VERA_dc_video
   rts


clear_screen:
   lda #$10 ; Stride 1, Bank 0
   sta VERA_addr_bank
   stz VERA_addr_low
   stz VERA_addr_high
   ldy #$00
clear_screen_loopY0:   
   ldx #$00
clear_screen_loopX0:
   stz VERA_data0
   dex
   bne clear_screen_loopX0
   dey
   bne clear_screen_loopY0

   ldy #$2C
clear_screen_loopY1:   
   ldx #$00
clear_screen_loopX1:
   stz VERA_data0
   dex
   bne clear_screen_loopX1
   dey
   bne clear_screen_loopY1
   rts


draw_palette:
   lda #$E0 ; Stride 15, Bank 0
   sta VERA_addr_bank
   ldx #$FF
draw_palette_loopX:
   stx VERA_addr_low
   lda #$00
   sta VERA_addr_high
   ldy #$10
draw_palette_loopY:  
   txa
   lsr
   lsr
   lsr
   lsr
   sta VERA_data0
   dey
   bne draw_palette_loopY
   dex
   bne draw_palette_loopX
   rts



get_mouse_xy: ; Output: A = button ID; X/Y = text map coordinates
   ldx #MOUSE_X
   jsr MOUSE_GET
   rts



getPaintColor:
   ; gets the paint colour being clicked on with the mouse in the palette
   stz V_COORD + 1
   stz V_COORD
   ldy MOUSE_Y
   beq getPaint_paint_addX
getPaint_mul320_Loop:
   lda V_COORD
   clc
   adc #$40
   sta V_COORD
   lda V_COORD + 1
   adc #$01
   sta V_COORD + 1
   dey
   bne getPaint_mul320_Loop
getPaint_paint_addX:
   clc
   lda V_COORD
   adc MOUSE_X
   sta V_COORD
   lda V_COORD + 1
   adc MOUSE_X + 1
   sta V_COORD + 1
   
   clc
   lda V_COORD + 1
   adc #$00
   sta V_COORD + 1 
   stz VERA_addr_bank
   lda V_COORD + 1
   sta VERA_addr_high ; Y
   lda V_COORD
   sta VERA_addr_low  ; X
   lda VERA_data0
   sta paint_color
   rts

clear_array:
   lda #<ARRAY
   sta ARR_COLOUR_PTR
   lda #>ARRAY
   sta ARR_COLOUR_PTR + 1
   ldx #$FF
@loop:
   lda #$00
   sta (ARR_COLOUR_PTR)
   clc
   lda ARR_COLOUR_PTR
   adc #$04
   sta ARR_COLOUR_PTR
   lda ARR_COLOUR_PTR + 1
   adc #$00
   sta ARR_COLOUR_PTR + 1
   dex
   bne @loop
   rts


set_array_pointers:
   ; set the address pointers based on the colour pointer
   lda ARR_COLOUR_PTR
   sta ARR_LOADDR_PTR
   sta ARR_HIADDR_PTR
   sta ARR_BKADDR_PTR
   lda ARR_COLOUR_PTR + 1
   sta ARR_LOADDR_PTR + 1
   sta ARR_HIADDR_PTR + 1
   sta ARR_BKADDR_PTR + 1
   clc
   lda #$01
   adc ARR_LOADDR_PTR
   sta ARR_LOADDR_PTR
   lda #$00
   adc ARR_LOADDR_PTR + 1
   sta ARR_LOADDR_PTR + 1
   clc
   lda #$02
   adc ARR_HIADDR_PTR
   sta ARR_HIADDR_PTR
   lda #$00
   adc ARR_HIADDR_PTR + 1
   sta ARR_HIADDR_PTR + 1
   clc
   lda #$03
   adc ARR_BKADDR_PTR
   sta ARR_BKADDR_PTR
   lda #$00
   adc ARR_BKADDR_PTR + 1
   sta ARR_BKADDR_PTR + 1
   rts


add_pixel:
   ;find next free array slot and add the pixel to it
   lda #<ARRAY
   sta ARR_COLOUR_PTR
   lda #>ARRAY
   sta ARR_COLOUR_PTR + 1
   ldx #$FF
@loop:
   lda (ARR_COLOUR_PTR)
   beq free_slot_found
   clc
   lda ARR_COLOUR_PTR
   adc #$04
   sta ARR_COLOUR_PTR
   lda ARR_COLOUR_PTR + 1
   adc #$00
   sta ARR_COLOUR_PTR + 1
   dex
   bne @loop   
free_slot_found:
   lda paint_color
   sta (ARR_COLOUR_PTR)
   jsr set_array_pointers
   lda #$00
   sta (ARR_BKADDR_PTR)
   sta (ARR_LOADDR_PTR)
   lda #$00
   sta (ARR_HIADDR_PTR)
   ldy MOUSE_Y
   beq add_pixel_addX
mul320_Loop:
   clc
   lda (ARR_LOADDR_PTR)
   adc #$40
   sta (ARR_LOADDR_PTR)
   lda (ARR_HIADDR_PTR)
   adc #$01
   sta (ARR_HIADDR_PTR)
   lda (ARR_BKADDR_PTR)
   adc #$00
   sta (ARR_BKADDR_PTR)
   dey
   bne mul320_Loop
add_pixel_addX:
   clc
   lda (ARR_LOADDR_PTR)
   adc MOUSE_X
   sta (ARR_LOADDR_PTR)
   lda (ARR_HIADDR_PTR)
   adc MOUSE_X + 1
   sta (ARR_HIADDR_PTR)
   lda (ARR_BKADDR_PTR)
   adc #$00
   sta (ARR_BKADDR_PTR)
   rts


array_fall:
   lda #<ARRAY
   sta ARR_COLOUR_PTR
   lda #>ARRAY
   sta ARR_COLOUR_PTR + 1
   ldx #$FF
array_fall_loop:
   jsr set_array_pointers
   lda (ARR_COLOUR_PTR)
   beq array_fall_next_item
   jsr do_fall
array_fall_next_item:
   clc
   lda ARR_COLOUR_PTR
   adc #$04
   sta ARR_COLOUR_PTR
   lda ARR_COLOUR_PTR + 1
   adc #$00
   sta ARR_COLOUR_PTR + 1
   dex
   bne array_fall_loop   
   rts


do_fall:
   ;check below, left and right of the current pixel being tested
   lda #$00
   jsr paint_pixel ; black
   stz VERA_ctrl
check_below:
   clc
   lda (ARR_LOADDR_PTR)
   adc #$40
   sta TST_LOADDR_PTR
   sta VERA_addr_low
   lda (ARR_HIADDR_PTR)
   adc #$01
   sta TST_HIADDR_PTR
   sta VERA_addr_high
   lda (ARR_BKADDR_PTR)
   adc #$00
   sta TST_BKADDR_PTR
   sta VERA_addr_bank
   lda VERA_data0
   bne check_right
   jsr move_pixel
   jmp do_fall_end
check_right:
   clc
   lda TST_LOADDR_PTR
   adc #$01
   sta TST_LOADDR_PTR
   sta VERA_addr_low
   lda TST_HIADDR_PTR
   adc #$00
   sta TST_HIADDR_PTR
   sta VERA_addr_high
   lda TST_BKADDR_PTR
   adc #$00
   sta TST_BKADDR_PTR
   sta VERA_addr_bank
   lda VERA_data0
   bne check_left
   jsr move_pixel
   jmp do_fall_end
check_left:
   sec
   lda TST_LOADDR_PTR
   sbc #$02
   sta TST_LOADDR_PTR
   sta VERA_addr_low
   lda TST_HIADDR_PTR
   sbc #$00
   sta TST_HIADDR_PTR
   sta VERA_addr_high
   lda TST_BKADDR_PTR
   sbc #$00
   sta TST_BKADDR_PTR
   sta VERA_addr_bank
   lda VERA_data0
   bne stop_fall
   jsr move_pixel
   jmp do_fall_end
stop_fall:
   lda (ARR_COLOUR_PTR)
   jsr paint_pixel
   lda #$00
   sta (ARR_COLOUR_PTR)
do_fall_end:
   rts

move_pixel:
   ; move pixel into new location
   lda (ARR_COLOUR_PTR)
   sta VERA_data0
   lda TST_LOADDR_PTR
   sta (ARR_LOADDR_PTR)
   lda TST_HIADDR_PTR
   sta (ARR_HIADDR_PTR)
   lda TST_BKADDR_PTR
   sta (ARR_BKADDR_PTR)
   rts


paint_pixel:
   ; pixel colour in Accumulator
   pha
   lda (ARR_LOADDR_PTR)
   sta VERA_addr_low
   lda (ARR_HIADDR_PTR)
   sta VERA_addr_high
   lda (ARR_BKADDR_PTR)
   sta VERA_addr_bank
   pla
   sta VERA_data0
   rts


