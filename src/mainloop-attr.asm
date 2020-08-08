; Kalle Paint - main loop - attribute edit mode

attribute_edit_mode:
    ; ignore buttons if anything was pressed on previous frame
    lda prev_joypad_status
    bne attr_buttons_done

    ; if select pressed, enter palette editor
    lda joypad_status
    and #button_select
    beq +
    jmp enter_palette_editor  ; ends with rts

    ; otherwise if A pressed, tell NMI to update attribute byte
+   lda joypad_status
    and #button_a
    beq +
    jsr prepare_attr_change
    jmp attr_buttons_done

    ; otherwise, check arrows
+   jsr attr_check_arrows

attr_buttons_done:
    ; update cursor sprite
    ;
    ; X
    lda cursor_x
    asl
    asl
    sta sprite_data + 4 + 3
    sta sprite_data + 3 * 4 + 3
    adc #8                       ; carry is always clear
    sta sprite_data + 2 * 4 + 3
    sta sprite_data + 4 * 4 + 3
    ;
    ; Y
    lda cursor_y
    asl
    asl
    adc #(8 - 1)                 ; carry is always clear
    sta sprite_data + 4 + 0
    sta sprite_data + 2 * 4 + 0
    adc #8                       ; carry is always clear
    sta sprite_data + 3 * 4 + 0
    sta sprite_data + 4 * 4 + 0

    rts

; --------------------------------------------------------------------------------------------------

enter_palette_editor:
    ; Switch to palette edit mode.

    ; reset palette cursor position and selected subpalette
    lda #0
    sta palette_cursor
    sta palette_subpal

    ; hide attribute editor sprites
    ldx #(1 * 4)
    ldy #4
    jsr hide_sprites  ; X=first*4, Y=count

    ; show palette editor sprites
    ldx #(5 * 4)
    ldy #25
    jsr show_sprites  ; X=first*4, Y=count

    ; update tiles of cursor coordinates
    ;
    lda cursor_x
    jsr get_decimal_tens
    sta sprite_data + 7 * 4 + 1
    ;
    lda cursor_x
    jsr get_decimal_ones
    sta sprite_data + 8 * 4 + 1
    ;
    lda cursor_y
    jsr get_decimal_tens
    sta sprite_data + 10 * 4 + 1
    ;
    lda cursor_y
    jsr get_decimal_ones
    sta sprite_data + 11 * 4 + 1

    ; switch mode
    inc mode

    rts

; --------------------------------------------------------------------------------------------------

prepare_attr_change:
    ; Prepare to cycle attribute value (0 -> 1 -> 2 -> 3 -> 0) of selected 2*2-tile block.
    ; Note: we've scrolled screen vertically so that VRAM $2000 is at top left of visible area.

    jsr get_nt_at_offset_for_at
    jsr get_nt_at_buffer_addr
    jsr get_pos_in_attr_byte  ; 0/2/4/6 to X

    ; increment a bit pair in byte
    ldy #0
    lda (nt_at_buffer_addr), y
    jsr increment_bit_pair      ; modify A according to X
    ldy #0
    sta (nt_at_buffer_addr), y

    jsr nt_at_update_to_vram_buffer  ; tell NMI to copy A to VRAM
    rts

; --------------------------------------------------------------------------------------------------

attr_check_arrows:
    ; React to arrows (excluding diagonal directions).
    ; Reads: joypad_status, cursor_x, cursor_y
    ; Changes: cursor_x, cursor_y

    lda joypad_status
    lsr
    bcs attr_right
    lsr
    bcs attr_left
    lsr
    bcs attr_down
    lsr
    bcs attr_up
    rts

attr_right:
    lda cursor_x
    clc
    adc #4
    bcc attr_store_horz  ; unconditional
attr_left:
    lda cursor_x
    sec
    sbc #4
attr_store_horz:
    and #%00111111
    sta cursor_x
    rts

attr_down:
    lda cursor_y
    clc
    adc #4
    cmp #56
    bne attr_store_vert
    lda #0
    beq attr_store_vert  ; unconditional
attr_up:
    lda cursor_y
    src
    sbc #4
    bpl attr_store_vert
    lda #(56 - 4)
attr_store_vert:
    sta cursor_y
    rts

