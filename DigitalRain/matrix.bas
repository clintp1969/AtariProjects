10 GOSUB 210
20 REM --- Main loop ---
30 POKE ATRACT,0                : REM Turn off screen saver
40 IF PEEK(KEYCH)<>255 THEN 140 : REM Bail on keypress
45 FOR P=0 TO 3
50 YP=PEEK(VA+244+P):CR=INT((YP-16)/8)
60 IF YP<24 OR CR=LROW(P) OR CR<1 OR CR>24 THEN 90
70 LROW(P)=CR:DC=INT((PEEK(VA+240+P)-48)/8):OFF=(CR-1)*20+DC
80 POKE SCRN+OFF,INT(RND(1)*63)+1+192:POKE FADETAB+OFF,255
90 T(P)=T(P)-1:IF T(P)>0 THEN 120
100 T(P)=5:CH=INT(RND(1)*63)+1
110 X=USR(MEMCOPY,FONTADR+CH*8,VA+160+P*8,8)
120 NEXT P
130 X=USR(FDA,FSTEP,FADETAB,SCRN)
135 GOTO 30                    : REM Start all over again
140 REM --- Clean exit on keypress ---
150 POKE VVBLKD,OLDVBLO:POKE VVBLKD+1,OLDVBHI : REM Restore original deferred VBI vector
160 POKE GRACTL,0               : REM GRACTL off - disable player/missile DMA
170 POKE CHBAS,ORIGFONT         : REM Restore original font pointer
180 POKE RAMTOP,ORIGTOP         : REM Restore RAMTOP - must precede GRAPHICS call
190 GRAPHICS 0 : POKE KEYCH,255 : REM Back to normal text mode, clear key flag
200 END
205 REM
210 REM --- Init ---
215 REM
216 REM OS / hardware cell constants used throughout (see Memory_map.txt)
217 ATRACT=77:SAVMSC=88:RAMTOP=106:VVBLKD=548:DMACTL=559
218 GPRIOR=623:PCOLR0=704:CHBAS=756:KEYCH=764
219 HPOSP0=53248:SIZEP0=53256:GRACTL=53277:PMBASE=54279
220 REM Save original state (RAMTOP, font pointer) for clean exit later
230 ORIGTOP=PEEK(RAMTOP):ORIGFONT=PEEK(CHBAS)
240 REM Reserve PM buffer (8-page aligned) then font below it.
250 REM Both POKEs must come before any GRAPHICS call or the
260 REM screen buffer will land inside the protected area.
270 PMBPG=(INT(PEEK(RAMTOP)/8)-1)*8:POKE RAMTOP,PMBPG:PMGBASE=PMBPG*256
280 RAMFONT=PEEK(RAMTOP)-8:POKE RAMTOP,RAMFONT:FONTADR=RAMFONT*256
290 FADEPG=PEEK(RAMTOP)-2:POKE RAMTOP,FADEPG:FADETAB=FADEPG*256
300 FADEMLPG=PEEK(RAMTOP)-1:POKE RAMTOP,FADEMLPG:FDA=FADEMLPG*256
310 ROMFONT=$E000
320 REM ML entry points in page 6: COPY, FLIP, MEMSET
330 MEMCOPY=$0600:BYTEFLIP=$0644:MEMSET=$0698
340 REM Load utility ML routines into page 6 ($0600)
350 OPEN #1,4,0,"H1:UTIL.BIN"
360 BGET #1,$0600,210
370 CLOSE #1
380 X=USR(MEMSET,FADETAB,480,0) : REM Clear fade table
390 REM 
400 REM Gr 17 characters are the same width as the PMG and have 4 colors
410 REM 
420 GRAPHICS 17
430 POKE DMACTL,62        : REM DMACTL: normal playfield + single-line PM DMA
440 REM 4 shades of green, black backround
450 SETCOLOR 0,12,2:SETCOLOR 1,12,6:SETCOLOR 2,12,10:SETCOLOR 3,12,14
460 SETCOLOR 4,0,0
465 REM        
470 REM Build RAM font -- some are regular, some katakana, all of them reversed
475 REM
480 X=USR(MEMCOPY,ROMFONT,FONTADR,1024)
490 OPEN #1,4,0,"H1:KATAFONT.BIN"
500 KATADR=FONTADR+8
510 BGET #1,KATADR,216    : REM Katakana glyphs into char slots 1-27
520 CLOSE #1
530 X=USR(BYTEFLIP,FONTADR,512) : REM Bit-flip first 64 chars (GR.1 requires it)
540 POKE CHBAS,RAMFONT     : REM Switch ANTIC to RAM font
550 REM Record screen base for main loop character drops
560 SCRN=PEEK(SAVMSC)+PEEK(SAVMSC+1)*256
565 REM
570 REM PMG (bright dropping characters)
575 REM
580 X=USR(MEMSET,PMGBASE+1024,1024,0)
590 POKE PMBASE,PMBPG     : REM PMBASE register
600 POKE GRACTL,3          : REM GRACTL: players and missiles on
610 POKE GPRIOR,1          : REM PRIOR: sprites float over playfield
620 POKE SIZEP0,0:POKE SIZEP0+1,0:POKE SIZEP0+2,0:POKE SIZEP0+3,0 : REM Normal widths
630 POKE PCOLR0,14:POKE PCOLR0+1,14:POKE PCOLR0+2,14:POKE PCOLR0+3,14 : REM Bright white
640 REM Page 7 ($0700): VBI lives here. Tables at end of page.
645 VA=$0700
650 REM VA+232 = ZONE_BASE[4]: leftmost HPOSP of each sprite zone
660 REM VA+240 = XPOS[4]:      current horizontal position (VBI updates)
670 REM VA+244 = YPOS[4]:      current scanline (VBI updates)
690 POKE VA+232,48:POKE VA+233,88:POKE VA+234,128:POKE VA+235,168
700 POKE VA+240,48:POKE VA+241,88:POKE VA+242,128:POKE VA+243,168
710 POKE VA+244,16:POKE VA+245,64:POKE VA+246,112:POKE VA+247,160
720 POKE HPOSP0,48:POKE HPOSP0+1,88:POKE HPOSP0+2,128:POKE HPOSP0+3,168
730 REM Draw initial 8-pixel sprite bars at starting positions
740 FOR P=0 TO 3
750 PB=PMGBASE+1024+P*256
760 YP=PEEK(VA+244+P)
770 FOR Y=0 TO 7:POKE PB+YP+Y,255:NEXT Y
780 NEXT P
790 REM Load VBI into page 7 and patch player page base byte
795 REM Pretty simple, just makes the PMGs fall and restart
800 OPEN #1,4,0,"H1:RAIN.BIN"
810 BGET #1,$0700,108
820 CLOSE #1
830 POKE VA+5,PMBPG+4      : REM Patch ADC #$84 at $0705 with actual PM page
835 REM FADE decrements all of the cells in the fade table
840 OPEN #1,4,0,"H1:FADE.BIN"
850 BGET #1,FDA,99
860 CLOSE #1
870 REM FADE.BIN takes FADETAB/SCRN as USR args now, so no patching needed
995 REM Fade step per call - must be a power of 2 (1/2/4/8/16/32/64)
997 REM Bigger numbers cause faster fading
1000 FSTEP=4
1010 REM Init shape buffers (VA+160 = $07A0) before VBI starts reading them
1020 DIM T(3)
1030 DIM LROW(3)
1040 FOR P=0 TO 3
1050 CH=INT(RND(1)*63)+1
1060 X=USR(MEMCOPY,FONTADR+CH*8,VA+160+P*8,8)
1070 T(P)=P*4+4             : REM Stagger timers so shapes change out of phase
1080 NEXT P
1090 OLDVBLO=PEEK(VVBLKD):OLDVBHI=PEEK(VVBLKD+1) : REM Save original VBI vector for clean exit
1100 POKE VVBLKD,0:POKE VVBLKD+1,7               : REM Install deferred VBI at VVBLKD ($0224/$0225)
1110 FOR P=0 TO 3:LROW(P)=-1:NEXT P
1120 RETURN
