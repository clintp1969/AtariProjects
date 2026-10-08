; =============================================================================
; RAIN.ASM — Deferred VBI handler for MATRIX.BAS
; Loaded at $0700 (page 7, decimal 1792).
;
; CALLING CONVENTION: installed as deferred VBI via POKE 548/549 (VVBLKD).
; Exit via JMP $E462 (XITVBV).
;
; ZERO PAGE: NONE USED. Self-modifying absolute addressing throughout —
; a deferred VBI using ($zp),Y while BASIC runs would corrupt BASIC's
; workspace ($80-$FF).  DON'T USE BASIC's ZERO PAGE.  It's not safe in a VBI.
;
; COLUMN ALIGNMENT:
;   GRAPHICS 1: 20 columns, each 8 pixels wide.
;   HPOSP = 48 + column*8  (48 = left edge of normal-width playfield).
;
; NO-CONFLICT ZONE STRATEGY:
;   4 zones of 5 columns each (20 cols / 4 sprites), one zone per sprite:
;     Sprite 0: cols  0-4  HPOSP  48-80
;     Sprite 1: cols  5-9  HPOSP  88-120
;     Sprite 2: cols 10-14 HPOSP 128-160
;     Sprite 3: cols 15-19 HPOSP 168-200
;   On reset: HPOSP = ZONE_BASE[X] + COLTAB[RANDOM AND 7]*8
;
;
; SHAPE BUFFERS:
;   Each sprite draws its 8-byte shape from SHAPE[X] rather than a constant.
;   BASIC maintains 4 shape buffers at $07A0-$07BF (8 bytes per sprite).
;   BASIC also runs a timer per sprite and copies a new random font glyph
;   into the shape buffer when the timer expires (~every half second).
;
; PM BUFFER LAYOUT (single-line, 2KB, PMBASE on 2KB/8-page boundary):
;   Player N at PMBASE + $400 + N*$100.
;   BOTTOM=232 keeps 8-pixel sprite fully on screen; TOP=16 clears border.
;
; PAGE 7 MEMORY MAP (current build, 108-byte routine + 8-byte table):
;   $0700-$076B  VBI code (108 bytes)
;   $0764-$076B  COLTAB (8 bytes, tail end of the code region above)
;   $076C-$079F  free (52 bytes)
;   $07A0-$07BF  SHAPE[0..3]   8 bytes per sprite (written by BASIC)
;   $07C0-$07E7  free (40 bytes)
;   $07E8-$07EB  ZONE_BASE[0..3]  (BASIC init: 48,88,128,168)
;   $07F0-$07F3  XPOS[0..3]       (BASIC init; VBI updates)
;   $07F4-$07F7  YPOS[0..3]       (BASIC init; VBI updates)
;   $07F8-$07FF  free (8 bytes)
;
; PATCHING (done by BASIC after BGET, before VBI install):
;   POKE VA+5, PMBPG+4   — patches ADC #$84 with correct PM player page base
;   (unchanged from the original build — this instruction sits before the
;   fencepost fix, so its address didn't move)
;
; ALGORITHM (per player, X = 0..3):
;   1. Patch CLR_INST address: hi = PMBPG+4+X, lo = YPOS[X]  (old position)
;   2. Clear 8 bytes at old position
;   3. Increment YPOS. If >= BOTTOM: pick a random column 0-4 via COLTAB,
;      zone-relative X, reset YPOS=TOP.
;   4. Patch DRW_INST: lo = new YPOS (hi already set from step 1)
;   5. Patch SHP_INST: lo = $A0 + X*8  (base of this sprite's shape buffer)
;   6. Draw loop: LDA SHAPE[X][Y], STA PM_BUFFER[Y]  for Y=7..0
;   7. Write XPOS[X] to HPOSP0-3 ($D000+X)
; =============================================================================

ZONE_BASE = $07E8
XBASE     = $07F0
YBASE     = $07F4
SHAPE     = $07A0       ; 4*8 bytes, one 8-byte block per player
HPOSP0    = $D000
RANDOM    = $D20A
BOTTOM    = 232
TOP       = 16

    opt h-              ; suppress MADS's default Atari DOS binary header --
                         ; loaded via BGET as raw bytes, not the DOS loader
    ORG $0700

VBI_START:              ; $0700
    LDX #0

PLAYER_LOOP:            ; $0702
    ; --- PM page for this player: PMBPG+4+X (patched by BASIC at VA+5) ---
    TXA
    CLC
    ADC #$84            ; placeholder; BASIC patches byte at $0705 to PMBPG+4
    STA CLR_INST+2       ; patch CLR high byte
    STA DRW_INST+2       ; patch DRW high byte

    ; --- Patch CLR_INST low byte = current YPOS ---
    LDA YBASE,X
    STA CLR_INST+1

    ; --- Clear 8 bytes at old position ---
    LDA #0
    LDY #7
CLR_INST:               ; $0716
    STA $0000,Y          ; STA abs,Y  (opcode $99; addr patched above)
    DEY
    BPL CLR_INST

    ; --- Compute new YPOS ---
    LDA YBASE,X
    CLC
    ADC #1
    CMP #BOTTOM
    BCC STORE_POS

    ; --- Reset: table-driven 5-column random pick, back to top ---
    LDA RANDOM
    AND #7               ; 0-7
    TAY
    LDA COLTAB,Y          ; 0-4 (full zone width — see fencepost note above)
    ASL
    ASL
    ASL                   ; col*8 pixel offset
    CLC
    ADC ZONE_BASE,X
    STA XBASE,X
    LDA #TOP

STORE_POS:              ; $073B
    STA YBASE,X
    STA DRW_INST+1        ; patch DRW low byte = new YPOS

    ; --- Patch SHP_INST low byte: SHAPE[X] base = $A0 + X*8 ---
    TXA
    ASL
    ASL
    ASL
    CLC
    ADC #$A0
    STA SHP_INST+1

    ; --- Draw 8 bytes from SHAPE[X] into PM buffer ---
    LDY #7
SHP_INST:               ; $074D
    LDA $07A0,Y          ; LDA abs,Y  (opcode $B9; low byte patched above)
DRW_INST:               ; $0750
    STA $0000,Y          ; STA abs,Y  (opcode $99; addr patched above)
    DEY
    BPL SHP_INST

    ; --- Update hardware H-position register ---
    LDA XBASE,X
    STA HPOSP0,X

    ; --- Next player ---
    INX
    CPX #4
    BNE PLAYER_LOOP

    JMP $E462            ; XITVBV

COLTAB:                 ; $0764, 8 bytes
    .BYTE 0,1,2,3,4,0,1,2

; end of code+table: $076C  (108 bytes total)