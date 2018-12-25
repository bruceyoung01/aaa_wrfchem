      SUBROUTINE MSGUPD(LUNIT,LUN)

C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    MSGUPD
C   PRGMMR: WOOLLEN          ORG: NP20       DATE: 1994-01-06
C
C ABSTRACT: THIS SUBROUTINE PACKS UP THE CURRENT SUBSET WITHIN MEMORY
C  (ARRAY IBAY IN COMMON BLOCK /BITBUF/) AND THEN TRIES TO ADD IT TO
C  THE BUFR MESSAGE THAT IS CURRENTLY OPEN WITHIN MEMORY FOR LUNIT
C  (ARRAY MBAY IN COMMON BLOCK /BITBUF/).  IF THE SUBSET WILL NOT FIT
C  INTO THE CURRENTLY OPEN MESSAGE, THEN THAT MESSAGE IS FLUSHED TO
C  LUNIT AND A NEW ONE IS CREATED IN ORDER TO HOLD THE CURRENT SUBSET.
C  IF THE SUBSET IS LARGER THAN AN EMPTY MESSAGE, THE SUBSET IS
C  DISCARDED AND A DIAGNOSTIC IS PRINTED.
C
C PROGRAM HISTORY LOG:
C 1994-01-06  J. WOOLLEN -- ORIGINAL AUTHOR
C 1998-07-08  J. WOOLLEN -- REPLACED CALL TO CRAY LIBRARY ROUTINE
C                           "ABORT" WITH CALL TO NEW INTERNAL BUFRLIB
C                           ROUTINE "BORT"
C 1998-12-14  J. WOOLLEN -- NO LONGER CALLS BORT IF A SUBSET IS LARGER
C                           THAN A MESSAGE, JUST DISCARDS THE SUBSET
C 1999-11-18  J. WOOLLEN -- THE NUMBER OF BUFR FILES WHICH CAN BE
C                           OPENED AT ONE TIME INCREASED FROM 10 TO 32
C                           (NECESSARY IN ORDER TO PROCESS MULTIPLE
C                           BUFR FILES UNDER THE MPI)
C 2000-09-19  J. WOOLLEN -- MAXIMUM MESSAGE LENGTH INCREASED FROM
C                           10,000 TO 20,000 BYTES
C 2003-11-04  J. ATOR    -- ADDED DOCUMENTATION
C 2003-11-04  S. BENDER  -- ADDED REMARKS/BUFRLIB ROUTINE
C                           INTERDEPENDENCIES
C 2003-11-04  D. KEYSER  -- UNIFIED/PORTABLE FOR WRF; ADDED HISTORY
C                           DOCUMENTATION
C 2004-08-09  J. ATOR    -- MAXIMUM MESSAGE LENGTH INCREASED FROM
C                           20,000 TO 50,000 BYTES
C 2009-03-23  J. ATOR    -- USE MSGFULL AND ERRWRT
C
C USAGE:    CALL MSGUPD (LUNIT, LUN)
C   INPUT ARGUMENT LIST:
C     LUNIT    - INTEGER: FORTRAN LOGICAL UNIT NUMBER FOR BUFR FILE
C     LUN      - INTEGER: I/O STREAM INDEX INTO INTERNAL MEMORY ARRAYS
C                (ASSOCIATED WITH FILE CONNECTED TO LOGICAL UNIT LUNIT)
C
C REMARKS:
C    THIS ROUTINE CALLS:        ERRWRT   IUPB     MSGFULL  MSGINI
C                               MSGWRT   MVB      PAD      PKB
C                               USRTPL
C    THIS ROUTINE IS CALLED BY: WRITSA   WRITSB
C                               Normally not called by any application
C                               programs.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C   MACHINE:  PORTABLE TO ALL PLATFORMS
C
C$$$

      INCLUDE 'bufrlib.prm'

      COMMON /MSGPTR/ NBY0,NBY1,NBY2,NBY3,NBY4,NBY5
      COMMON /MSGCWD/ NMSG(NFILES),NSUB(NFILES),MSUB(NFILES),
     .                INODE(NFILES),IDATE(NFILES)
      COMMON /BITBUF/ MAXBYT,IBIT,IBAY(MXMSGLD4),MBYT(NFILES),
     .                MBAY(MXMSGLD4,NFILES)
      COMMON /QUIET / IPRT

      LOGICAL MSGFULL

      CHARACTER*128 ERRSTR

C-----------------------------------------------------------------------
C-----------------------------------------------------------------------

C  PAD THE SUBSET BUFFER
C  ---------------------

      CALL PAD(IBAY,IBIT,IBYT,8)

C  SEE IF THE NEW SUBSET FITS
C  --------------------------

      IF(MSGFULL(MBYT(LUN),IBYT,MAXBYT)) THEN
c  .... NO it does not fit
         CALL MSGWRT(LUNIT,MBAY(1,LUN),MBYT(LUN))
         CALL MSGINI(LUN)
      ENDIF

      IF(MSGFULL(MBYT(LUN),IBYT,MAXBYT)) GOTO 900

C  SET A BYTE COUNT AND TRANSFER THE SUBSET BUFFER INTO THE MESSAGE
C  ----------------------------------------------------------------

      LBIT = 0
      CALL PKB(IBYT,16,IBAY,LBIT)

C     Note that we want to append the data for this subset to the end
C     of Section 4, but the value in MBYT(LUN) already includes the
C     length of Section 5 (i.e. 4 bytes).  Therefore, we need to begin
C     writing at the point 3 bytes prior to the byte currently pointed
C     to by MBYT(LUN).

      CALL MVB(IBAY,1,MBAY(1,LUN),MBYT(LUN)-3,IBYT)

C  UPDATE THE SUBSET AND BYTE COUNTERS
C  --------------------------------------

      MBYT(LUN)   = MBYT(LUN)   + IBYT
      NSUB(LUN)   = NSUB(LUN)   + 1

      LBIT = (NBY0+NBY1+NBY2+4)*8
      CALL PKB(NSUB(LUN),16,MBAY(1,LUN),LBIT)

      LBYT = NBY0+NBY1+NBY2+NBY3
      NBYT = IUPB(MBAY(1,LUN),LBYT+1,24)
      LBIT = LBYT*8
      CALL PKB(NBYT+IBYT,24,MBAY(1,LUN),LBIT)

C  RESET THE USER ARRAYS AND EXIT NORMALLY
C  ---------------------------------------

      CALL USRTPL(LUN,1,1)
      GOTO 100

C  ON ENCOUTERING OVERLARGE SUBSETS, EXIT GRACEFULLY (SUBSET DISCARDED)
C  --------------------------------------------------------------------

900   IF(IPRT.GE.0) THEN
      CALL ERRWRT('+++++++++++++++++++++WARNING+++++++++++++++++++++++')
      WRITE ( UNIT=ERRSTR, FMT='(A,A,I7,A)')
     . 'BUFRLIB: MSGUPD - SUBSET LONGER THAN ANY POSSIBLE MESSAGE ',
     . '{MAXIMUM MESSAGE LENGTH = ', MAXBYT, '}'
      CALL ERRWRT(ERRSTR)
      CALL ERRWRT('>>>>>>>OVERLARGE SUBSET DISCARDED FROM FILE<<<<<<<<')
      CALL ERRWRT('+++++++++++++++++++++WARNING+++++++++++++++++++++++')
      CALL ERRWRT(' ')
      ENDIF

C  EXIT
C  ----

100   RETURN
      END
