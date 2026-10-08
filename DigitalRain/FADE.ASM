; =============================================================================
; FADE.ASM — Fade table decrement + screen color-step routine for MATRIX.BAS
;
; CALLING CONVENTION: Atari BASIC USR with THREE arguments.
;   X=USR(FDA,FSTEP,FADETAB,SCRN)
;   Stack on entry: count(=3), FSTEP_H, FSTEP_L, FADETAB_H, FADETAB_L,
;                   SCRN_H, SCRN_L, ret_LOW, ret_HIGH.
;   Args come off the stack in call order after the count byte (see
;   atari-usr-convention in project memory). FSTEP is assumed < 256 — true
;   for every sane value: 1/2/4/8/16/32/64. FSTEP MUST BE A POWER OF 2 —
;   see "WHY POWER-OF-2 STEP WORKS" below.
;
; EFFECT: Scans all 480 bytes of FADETAB (20 cols x 24 rows, full-screen
; GRAPHICS 17 — no text window), starting at the FADETAB/SCRN addresses
; passed in. For each NONZERO byte:
;   1. Subtract FSTEP (clamped at 0 — see UNDERFLOW below).
;   2. If the new value is 0: erase the corresponding screen cell
;      (write 0 to SCRN+i — matches the already-blank look of untouched
;      cells, since GRAPHICS 17 clears the playfield to 0).
;   3. Else if the new value's low 6 bits are all set (i.e. new value is
;      191, 127, or 63 — the step just below a color-register boundary):
;      subtract 64 from the screen byte, stepping its color register
;      down by one (3->2->1->0) while preserving the character code.
;
; =============================================================================

FTPTR  = $CB            ; /CC
SCPTR  = $CD            ; /CE
FSTEPZ = $CF
CNT    = $D0            ; /D1
FR0    = $D4

    ORG $0000             ; position-independent; loaded wherever FDA points

FADE:
    PLA                 ; 0:  discard arg count (= 3)
    PLA                 ; 1:  discard FSTEP high byte (assumed 0)
    PLA                 ; 2:  A = FSTEP low byte
    STA FSTEPZ          ; 3-4
    PLA                 ; 5:  FADETAB high byte
    STA FTPTR+1         ; 6-7
    PLA                 ; 8:  FADETAB low byte
    STA FTPTR           ; 9-10
    PLA                 ; 11: SCRN high byte
    STA SCPTR+1         ; 12-13
    PLA                 ; 14: SCRN low byte
    STA SCPTR           ; 15-16

    LDA #<480           ; 17-18  CNT = 480 (fixed: 20 cols x 24 rows)
    STA CNT             ; 19-20
    LDA #>480           ; 21-22
    STA CNT+1           ; 23-24

    LDY #0              ; 25-26  Y stays 0 all routine; pointers do the walking

LOOP:                   ; $001B (27)
    LDA CNT             ; 27-28
    ORA CNT+1           ; 29-30
    BEQ DONE            ; 31-32  all 480 cells done

    LDA (FTPTR),Y       ; 33-34  current fade value
    BEQ SKIP            ; 35-36  already 0, nothing to do
    SEC                 ; 37
    SBC FSTEPZ          ; 38-39
    BCS OK              ; 40-41  no underflow -> keep subtracted result
    LDA #0              ; 42-43  underflow -> clamp to 0
OK:
    STA (FTPTR),Y       ; 44-45  store new value (A = new value)
    BNE NZ              ; 46-47  nonzero -> check color threshold
    STA (SCPTR),Y       ; 48-49  A=0 here -> erase char
    BEQ SKIP            ; 50-51  unconditional (Z still set)
NZ:
    AND #$3F            ; 52-53  isolate low 6 bits of the NEW value
    CMP #$3F            ; 54-55  all set only at 191/127/63
    BNE SKIP            ; 56-57  no boundary crossed -> skip
    LDA (SCPTR),Y       ; 58-59
    SEC                 ; 60
    SBC #64             ; 61-62  step color register down by one
    STA (SCPTR),Y       ; 63-64
SKIP:
    INC FTPTR           ; 65-66  advance FADETAB pointer (16-bit, carry into hi)
    BNE NC1             ; 67-68
    INC FTPTR+1         ; 69-70
NC1:
    INC SCPTR           ; 71-72  advance SCRN pointer (16-bit, carry into hi)
    BNE NC2             ; 73-74
    INC SCPTR+1         ; 75-76
NC2:
    SEC                 ; 77     16-bit CNT -= 1
    LDA CNT             ; 78-79
    SBC #1              ; 80-81
    STA CNT             ; 82-83
    LDA CNT+1           ; 84-85
    SBC #0              ; 86-87
    STA CNT+1           ; 88-89

    BEQ LOOP            ; 90-91  unconditional pair (see note above) --
    BNE LOOP            ; 92-93  exactly one of these two always fires

DONE:                   ; $005E (94)
    LDA #0              ; 94-95
    STA FR0             ; 96-97
    RTS                 ; 98

; end of code: 99 bytes
; =============================================================================
