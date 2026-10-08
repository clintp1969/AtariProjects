; =============================================================================
; UTIL.ASM — Source for util.bin
; Loaded into page 6 ($0600) by matrix.bas / M2.bas via:
;   OPEN #1,4,0,"H1:UTIL.BIN" : BGET #1,$0600,210 : CLOSE #1
;
; PAGE 6 LAYOUT:
;   $0600-$0643   COPY    (68 bytes)   MEMCOPY  = $0600
;   $0644-$0697   FLIP    (84 bytes)   BYTEFLIP = $0644
;   $0698-$06D1   MEMSET  (58 bytes)   MEMSET   = $0698
;   $06D2-$06EF   free    (30 bytes)
;   $06F0-$06F1   count scratch — shared by all routines, runtime-written
;   $06F2-$06FF   free    (14 bytes)
;
; CALLING CONVENTION (Atari BASIC USR, confirmed on 130XE/Altirra):
;   BASIC pushes: ret_H, ret_L, then each arg pair (arg_H, arg_L, last arg
;   deepest), then arg count byte.  JMPs to routine.  Routine PLAs count,
;   PLAs args, does work, RTS.  Return value goes in FR0 ($D4-$D9).
;
;   PLA opcode = $68 = 104 decimal.  Never use 68 ($44 = LSR abs) by mistake.
;
; ZERO PAGE SCRATCH (all routines share, safe — called sequentially):
;   $CB/$CC  source pointer (all routines)
;   $CD/$CE  dest pointer   (COPY dst; FLIP bit-reverse scratch byte)
;   $D4-$D9  FR0 = BASIC USR return register — DO NOT TOUCH
;
; COUNT SCRATCH at $06F0/$06F1:
;   Sits 89 bytes above end of code ($0697, $06D1 for MEMSET).  All routines
;   write their 16-bit count here before looping.  Safe to share because the
;   routines are never called simultaneously.
; =============================================================================

; =============================================================================
; ROUTINE 1 — MEMORY COPY
; $0600-$0643  68 bytes
;
; X = USR(MEMCOPY, SRC, DST, COUNT)   ; MEMCOPY = $0600 (1536)
;
;   Stack on entry:
;     SP+1  count = 3
;     SP+2  SRC_H    SP+3  SRC_L
;     SP+4  DST_H    SP+5  DST_L
;     SP+6  CNT_H    SP+7  CNT_L
;     SP+8  ret_L    SP+9  ret_H
;
; Copies COUNT bytes from SRC to DST.  COUNT is 16-bit (up to 65535).
; Pointer advance: Y held at 0; pointer low/high bytes INC'd directly.
; 16-bit decrement: SEC / SBC #1 (low) / SBC #0 (high, borrow only).
; =============================================================================

    opt h-              ; suppress MADS's default Atari DOS binary header --
                         ; this file is loaded via BGET as raw bytes, not the
                         ; DOS L/BLOAD loader, so no $FFFF+start+end header
                         ; belongs here (it would shift every byte offset
                         ; this project's documentation depends on)
    ORG $0600

COPY_START:             ; $0600
    PLA                 ; discard arg count (= 3)
    PLA                 ; SRC high byte
    STA $CC             ;   -> source pointer high
    PLA                 ; SRC low byte
    STA $CB             ;   -> source pointer low  ($CB/$CC = 16-bit src)
    PLA                 ; DST high byte
    STA $CE             ;   -> dest pointer high
    PLA                 ; DST low byte
    STA $CD             ;   -> dest pointer low    ($CD/$CE = 16-bit dst)
    PLA                 ; COUNT high byte
    STA $06F1           ;   -> count high (page 6 scratch)
    PLA                 ; COUNT low byte
    STA $06F0           ;   -> count low  (page 6 scratch)

    LDY #0              ; Y = 0 always; pointers advanced via INC

COPY_LOOP:              ; $0617
    LDA $06F0           ; count low
    ORA $06F1           ; OR high: if both zero, we're done
    BEQ COPY_DONE       ; $061D -> $0643  (offset +36)

    LDA ($CB),Y         ; load from source
    STA ($CD),Y         ; store to dest

    INC $CB             ; advance source (16-bit)
    BNE COPY_NOSRCHI
    INC $CC
COPY_NOSRCHI:
    INC $CD             ; advance dest (16-bit)
    BNE COPY_NODSTHI
    INC $CE
COPY_NODSTHI:

    SEC                 ; 16-bit decrement
    LDA $06F0
    SBC #1
    STA $06F0
    LDA $06F1
    SBC #0              ; carries borrow only
    STA $06F1

    JMP COPY_LOOP       ; $0640 -> $0617

COPY_DONE:              ; $0643
    RTS

; =============================================================================
; ROUTINE 2 — BIT REVERSAL (in-place)
; $0644-$0697  84 bytes
;
; X = USR(BYTEFLIP, SRC, COUNT)   ; BYTEFLIP = $0644 (1604)
;
;   Stack on entry:
;     SP+1  count = 2
;     SP+2  SRC_H    SP+3  SRC_L
;     SP+4  CNT_H    SP+5  CNT_L
;     SP+6  ret_L    SP+7  ret_H
;
; Reverses the bit order of each byte at SRC..SRC+COUNT-1, in place:
;   %10000000 (128) -> %00000001 (1)
;   %00100101  (37) -> %10100100 (164)
;   %11111111 (255) -> %11111111 (255)
;
; ALGORITHM — unrolled 8x per byte:
;   LSR $CD   shift lowest remaining input bit into carry
;   ROL       rotate carry into MSB of accumulator (bare ROL = accumulator
;             mode; MADS wants no operand at all here, not "ROL A" —
;             omitting it is what selects accumulator mode on this
;             assembler, unlike some others that require an explicit A)
; After 8 pairs: A holds the mirror image of the original byte.
;
; Uses same Y=0 + INC pointer pattern as COPY for 16-bit COUNT support.
; $CD used as single-byte scratch (shadows COPY's dst-ptr low — safe,
; because FLIP is always called after COPY, never simultaneously).
; =============================================================================

    ORG $0644

FLIP_START:             ; $0644
    PLA                 ; discard arg count (= 2)
    PLA                 ; SRC high byte
    STA $CC             ;   -> pointer high ($CB/$CC = 16-bit src/dst ptr)
    PLA                 ; SRC low byte
    STA $CB
    PLA                 ; COUNT high byte
    STA $06F1           ;   -> count high (shared page 6 scratch)
    PLA                 ; COUNT low byte
    STA $06F0           ;   -> count low

    LDY #0              ; Y = 0 always

FLIP_LOOP:              ; $0655
    LDA $06F0
    ORA $06F1
    BEQ FLIP_DONE       ; $065B -> $0697  (offset +58)

    LDA ($CB),Y         ; load byte to reverse
    STA $CD             ; park in ZP scratch
    LDA #0              ; clear result accumulator

    LSR $CD             ; bit 7 of input -> bit 0 of result (and up)
    ROL
    LSR $CD
    ROL
    LSR $CD
    ROL
    LSR $CD
    ROL
    LSR $CD
    ROL
    LSR $CD
    ROL
    LSR $CD
    ROL
    LSR $CD             ; bit 0 of input -> bit 7 of result
    ROL

    STA ($CB),Y         ; write reversed byte back in place

    INC $CB             ; advance pointer (16-bit)
    BNE FLIP_NOSRCHI    ; $067F -> $0683  (offset +2)
    INC $CC
FLIP_NOSRCHI:           ; $0683

    SEC                 ; 16-bit count decrement
    LDA $06F0
    SBC #1
    STA $06F0
    LDA $06F1
    SBC #0
    STA $06F1

    JMP FLIP_LOOP       ; -> $0655

FLIP_DONE:              ; $0697
    RTS

; =============================================================================
; ROUTINE 3 — MEMORY SET (fill block with constant byte)
; $0698-$06D1  58 bytes
;
; X = USR(MEMSET, SRC, COUNT, VAL)   ; MEMSET = $0698 (1688)
;
;   Stack on entry:
;     SP+1  count = 3
;     SP+2  SRC_H    SP+3  SRC_L
;     SP+4  CNT_H    SP+5  CNT_L
;     SP+6  VAL_H    SP+7  VAL_L   (VAL 0-255; VAL_H always 0, discarded)
;     SP+8  ret_L    SP+9  ret_H
;
; Fills COUNT bytes starting at SRC with the byte value VAL.
; COUNT is 16-bit (up to 65535).
;
; VAL stored in X register — no extra page-6 scratch needed.
; Same Y=0 + INC pointer pattern as COPY/FLIP for 16-bit COUNT.
; Shares $06F0/$06F1 count scratch (safe: sequential calls only).
; =============================================================================

    ORG $0698

MEMSET_START:           ; $0698
    PLA                 ; discard arg count (= 3)
    PLA                 ; SRC high byte
    STA $CC             ;   -> pointer high
    PLA                 ; SRC low byte
    STA $CB             ;   -> pointer low  ($CB/$CC = 16-bit ptr)
    PLA                 ; COUNT high byte
    STA $06F1           ;   -> count high (page 6 scratch)
    PLA                 ; COUNT low byte
    STA $06F0           ;   -> count low
    PLA                 ; VAL high byte — always 0 for values 0-255, discard
    PLA                 ; VAL low byte = fill value
    TAX                 ; stash fill value in X (freed from COPY/FLIP use here)

    LDY #0              ; Y = 0 always

MEMSET_LOOP:            ; $06AC
    LDA $06F0
    ORA $06F1
    BEQ MEMSET_DONE     ; $06B2 -> $06D1  (offset +29)

    TXA                 ; reload fill value from X
    STA ($CB),Y         ; store to current address

    INC $CB             ; advance pointer (16-bit)
    BNE MEMSET_NOSRCHI  ; $06B9 -> $06BD  (offset +2)
    INC $CC
MEMSET_NOSRCHI:         ; $06BD

    SEC                 ; 16-bit count decrement
    LDA $06F0
    SBC #1
    STA $06F0
    LDA $06F1
    SBC #0
    STA $06F1

    JMP MEMSET_LOOP     ; -> $06AC

MEMSET_DONE:            ; $06D1
    RTS

; =============================================================================
; BASIC entry points:
;   MEMCOPY  = $0600 (1536)  USR(MEMCOPY,  SRC, DST, COUNT)
;   BYTEFLIP = $0644 (1604)  USR(BYTEFLIP, SRC, COUNT)
;   MEMSET   = $0698 (1688)  USR(MEMSET,   SRC, COUNT, VAL)
; =============================================================================
