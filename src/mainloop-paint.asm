; Kalle Paint - main loop - paint mode

paint_mode:
    ; ignore select, B and start if any of them was pressed on previous frame
    lda prev_joypad_status
    and #(button_select | button_b | button_start)
    bne paint_arrowlogic

    ; if select pressed, enter attribute editor (and ignore other buttons)
    lda joypad_status
    and #button_select
    beq +
    jmp enter_attribute_editor  ; ends with rts

    ; if B pressed, cycle between 4 colors (0 -> 1 -> 2 -> 3 -> 0)
+   lda joypad_status
    and #button_b
    beq +
    ldx paint_color
    inx
    txa
    and #%00000011
    sta paint_color

    ; if start pressed, toggle between small and big cursor; if big, make coordinates even
+   lda joypad_status
    and #button_start
    beq +
    lda paint_cursor_type
    eor #%00000001
    sta paint_cursor_type
    beq +
    lsr cursor_x
    asl cursor_x
    lsr cursor_y
    asl cursor_y
+

paint_arrowlogic:
    ; if no arrow pressed, clear cursor movement delay
    lda joypad_status
    and #(button_up | button_down | button_left | button_right)
    bne +
    sta delay_left
    beq jump_to_part2  ; unconditional
    ;
    ; else if delay > 0, decrement it
+   lda delay_left
    beq +
    dec delay_left
    bpl jump_to_part2  ; unconditional
    ;
    ; else react to arrows and reinitialize delay
+   jsr paint_check_arrows
    lda #delay
    sta delay_left

jump_to_part2:
    jmp paint_mode_part2  ; ends with rts

; --------------------------------------------------------------------------------------------------

enter_attribute_editor:
    ; Switch to attribute edit mode.

    ; hide paint cursor sprite (X=first*4, Y=count)
    ldx #(0 * 4)
    ldy #1
    jsr hide_sprites

    ; make cursor coordinates a multiple of four
    lda cursor_x
    and #%00111100
    sta cursor_x
    lda cursor_y
    and #%00111100
    sta cursor_y

    ; switch mode
    inc mode

    rts

; --------------------------------------------------------------------------------------------------

paint_check_arrows:
    ; React to arrows (including diagonal directions).
    ; Changes: cursor_x, cursor_y

    lda joypad_status
    lsr
    bcs paint_right
    lsr
    bcs paint_left
    bcc check_vertical  ; unconditional

paint_right:
    lda cursor_x
    sec
    adc paint_cursor_type
    bcc store_horizontal  ; unconditional
paint_left:
    lda cursor_x
    clc
    sbc paint_cursor_type
store_horizontal:
    and #%00111111
    sta cursor_x

check_vertical:
    lda joypad_status
    lsr
    lsr
    lsr
    bcs paint_cursor_down
    lsr
    bcs paint_cursor_up
    rts

paint_cursor_down:
    lda cursor_y
    sec
    adc paint_cursor_type
    cmp #56
    bne store_vertical
    lda #0
    beq store_vertical  ; unconditional
paint_cursor_up:
    lda cursor_y
    clc
    sbc paint_cursor_type
    bpl store_vertical
    lda #56
    clc
    sbc paint_cursor_type
store_vertical:
    sta cursor_y
    rts

; --------------------------------------------------------------------------------------------------

paint_mode_part2:
    ; if A pressed, tell NMI routine to paint
    lda joypad_status
    and #button_a
    beq +
    jsr prepare_paint
+

    ; update cursor sprite
    ;
    ; X
    lda cursor_x
    asl
    asl
    sta sprite_data + 0 + 3
    ;
    ; Y
    lda cursor_y
    asl
    asl
    adc #(8 - 1)  ; carry is always clear
    sta sprite_data + 0 + 0
    ;
    ; tile
    lda #tile_smallcur
    ldx paint_cursor_type
    beq +
    lda #tile_largecur
+   sta sprite_data + 0 + 1

    jsr get_cursor_color  ; to A
    pha

    ; tell NMI to update paint color to cursor
    ;
    ldy vram_buffer_pos
    ;
    lda #$3f
    a_to_vram_buffer
    lda #$13
    a_to_vram_buffer
    pla
    a_to_vram_buffer
    ;
    sty vram_buffer_pos

    rts

; --------------------------------------------------------------------------------------------------

prepare_paint:
    ; Prepare a paint operation to be done by NMI routine.
    ; Note: we've scrolled screen vertically so that VRAM $2000 is at top left of visible area.

    jsr get_nt_at_offset_for_nt
    jsr get_nt_at_buffer_addr

    ; get byte to write

    lda paint_cursor_type
    beq +

    ; cursor is big; just fetch correct solid color tile
    ldx paint_color
    lda solid_color_tiles, x
    jmp ++

    ; cursor is small; read old byte and replace a bit pair
+   ldy #0
    lda (nt_at_buffer_addr), y
    jsr replace_bit_pair

    ; overwrite byte
++  ldy #0
    sta (nt_at_buffer_addr), y
    jsr nt_at_update_to_vram_buffer  ; tell NMI to copy A to VRAM
    rts

solid_color_tiles:
    ; tiles of solid color 0/1/2/3 (2 bits = 1 pixel)
    db %00000000, %01010101, %10101010, %11111111
