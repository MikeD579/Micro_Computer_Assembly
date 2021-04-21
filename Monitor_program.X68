*-----------------------------------------------------------
* Title      : Monitor Program for MCD
* Written by : Michael Dominguez
* Date       : 03-09-2021
* Description: For the 68K processor on my Microcomputer. It needs to be able to read and write to 
*               Memory and Registers. and load and run S-Records. it interfaces with a DUART using
*               a 232-chip.
*-----------------------------------------------------------    
        ORG     $0000
        DC.L    STACK_START
        DC.L    START

START:  ORG     $0100

.initDUART    
    *Set DUART base address*
    LEA DUART_START,A0          ; Base address in A0
    LEA STACK_START, SP
    
    *DUART Reset*
    MOVE.B  #$30,CRA(A0)        ; Reset TxA
    MOVE.B  #$20,CRA(A0)        ; Reset RxA
    MOVE.B  #$10,CRA(A0)        ; Reset MRA pointer
    *DUART Initialization*
    MOVE.B  #$80,ACR(A0)        ; selects baud rate set 2
    MOVE.B  #BAUD,CSRA(A0)      ; set 19.2k baud Rx/Tx
    MOVE.B  #$13,MR1A(A0)       ; 8-bits, no parity, 1 stop bit
    MOVE.B  #$07,MR2A(A0)       ; "47" for auto echo, "07" otherwise
    MOVE.B  #$05,CRA(A0)        ; enable Tx and Rx

.clearReg
    CLR.L     D0
    CLR.L     D1
    CLR.L     D2
    CLR.L     D3
    CLR.L     D4
    CLR.L     D5
    CLR.L     D6
    CLR.L     D7
top
    MOVE.L  A1, -(SP)           ; Push A1 onto Stack
    LEA     menu, A1            ; Load the address of menu into A1
    BSR     PRINTSTRING         ; Prints a character till a null
    MOVE.L  (SP)+, A1           ; Push A1 onto Stack

    MOVE.L  D1, -(SP)           ; Push contents of D1 onto stack
    BSR     readNibble          ; readNibble will get an ascii value and turn it into a HEX value in D1

    CMP     #1, D1              ; If input is 1
    BEQ     readMem             ; Branch to the readMem subroutine
    CMP     #2, D1              ; If input is 2
    BEQ     writeMem            ; Branch to the readMem subroutine
    CMP     #3, D1              ; If input is 3
    BEQ     readReg             ; Branch to the readMem subroutine
    CMP     #4, D1              ; If input is 4
    BEQ     writeReg            ; Branch to the readMem subroutine
    CMP     #5, D1              ; If input is 5
    BEQ     loadRec             ; Branch to the readMem subroutine
    CMP     #6, D1              ; If input is 6
    BEQ     runRec              ; Branch to the readMem subroutine
    BRA     ERROR               ; If anything else 
    SIMHALT                     ; Halt simulator

* ----------------------------------------------------
* Subroutines for menu. Once done go back to the menu
* ----------------------------------------------------
readMem
    MOVE.L  (SP)+, D1           ; Pop contents of D1 off the stack and back into D1

    MOVE.L  A1, -(SP)           ; SAVE A1
    LEA     one, A1             ; Load text into A1
    BSR     PRINTSTRING         ; Display text

    MOVE.L  D1, -(SP)           ; SAVE D1
    BSR     readAddress         ; Reads the address (001000), puts it into D1
    MOVE    D1, A1              ; Put address into into A1
    MOVE.L  (A1),D1             ; Move the contents of A1 into D1
    BSR     CONVERTTOASCII      ; Convert D1 (i.e. BEEFFACE) to ascii stored at location STRING
    MOVE.L  (SP)+, D1           ; RESTORE D1

    LEA     STRING, A1          ; Load string into A1
    BSR     PRINTSTRING         ; Print string
    MOVE.L  (SP)+, A1           ; RESTORE A1
    BRA     top                 ; back to menu

writeMem
    MOVE.L  (SP)+, D1           ; Pop contents of D1 off the stack and back into D1
    MOVE.L  A1, -(SP)           ; SAVE A1
    MOVE.L  D1, -(SP)           ; SAVE D1
    
    LEA     two, A1             ; Load text into A1
    BSR     PRINTSTRING         ; Display text

    BSR     readAddress         ; Reads the memory address, puts it into D1
    MOVE    D1, A1              ; Put the address into into A1
    BSR     ENDL                ; print new line
    BSR     readLong            ; Reads longword and return in D1
    MOVE.L  D1, (A1)            ; Move the contents of A1 into D1

    MOVE.L  (SP)+, D1           ; Restore D1
    MOVE.L  (SP)+, A1           ; RESTORE A1
    BRA     top                 ; back to menu

* Gets D0 - D7 and A0 - A6 and displays the contents for which ever is selected by user
readReg
    MOVE.L  (SP)+, D1           ; Pop contents of D1 off the stack and back into D1

    * THE STACK LOOKS LIKE THIS  AFTER PUSHING ALL TO STACK *
                *****************************
                *      index    stack       *
                *    |   0   |   D0   |     *
                *    |   1   |   D1   |     *
                *    |   2   |   D2   |     *
                *    |   :   |   :    |     *
                *    |   :   |   :    |     *
                *    |   13  |   A5   |     *
                *    |   14  |   A6   |     *
                *****************************
    MOVEM.L D0-D7/A0-A6, -(SP)  ; Push all registers to the stack
    LEA     three, A1           ; Load text into A1
    BSR     PRINTSTRING         ; Display text
    BSR     readByte            ; Reads a Byte this is the Register they want to read. Puts it into D1
    
    CMP     #$FF, D1
    BEQ     .readAll
    
    CMP     #$A6, D1            ; Determine Which register read
    BGT     .dontAdd            ; If it is a D0-D7 register, there is no need to add 8 to the offset
    AND     #$000F, D1          ; Clear the 3 highest nibbles (i.e. $00A6 --> $0006)
    ADD     #8, D1              ; Add 8 if its in an address range
.dontAdd
    AND     #$000F, D1          ; Clear the 3 highest nibbles (i.e. $00A6 --> $0006)
    MOVE    #4, D0              ; D0 is the multiplier, because you must move through stack 4 bytes at a time
    MULS    D0, D1              ; (4 * index) Stores in D1
    MOVE.L  D1, A1              ; A1 is now the offset for the SP (i.e if D0 was chosen A1=0; if A0 was chosen A1=8)
    MOVE.L  0(A1,A7.L),D1       ; Whatever the SP is add the index A1 then store contents into D1 (i.e. (SP+A1) --> D1)
    BSR     CONVERTTOASCII      ; converts D1 to an ASCII string loaded into the label STRINGS
    LEA     STRING, A1          ; This is were I chose to store stings
    BSR     PRINTSTRING   
    MOVEM.L (SP)+, D0-D7/A0-A6  ; RESTORE registers
    BRA     top                 ; back to menu
.readAll
    

writeReg
    MOVE.L  (SP)+, D1           ; Pop contents of D1 off the stack and back into D1

    MOVEM.L D0-D7/A0-A6, -(SP)  ; Push all registers to the stack, to read the one
    LEA     four, A1            ; Load text into A1
    BSR     PRINTSTRING         ; Display text
    BSR     readByte            ; Reads a Byte this is the Register they want to write to. Puts it into D1
    
    CMP     #$A6, D1            ; Determining which register to write to
    BGT     .dontAdd            ; If it is a D0-D7 register, there is no need to add 8 to the offset
    AND     #$000F, D1          ; Clear the 3 highest nibbles (i.e. $00A6 --> $0006)
    ADD     #8, D1              ; Add 8 to get to the right index for the A0-A6
.dontAdd
    AND     #$000F, D1          ; Clear the 3 highest nibbles (i.e. $00A6 --> $0006)
    MOVE    #4, D0              ; D0 is the multiplier, because you must move through stack 4 bytes at a time
    MULS    D0, D1              ; (4 * index) Stores in D1
    MOVE.L  D1, A1              ; A1 has the offsetted location for readding the register (i.e if D0 was chosen A1=0; if A0 was chosen A1=8)
    ADD     A7, A1              ; A1 now has the register to write to
    
    BSR     ENDL                ; Print new line
    BSR     readLong            ; Reads a longword of data and return in D1
    MOVE.L  D1, (A1)            ; Move the longword into location of register on stack
    
    MOVEM.L (SP)+, D0-D7/A0-A6  ; RESTORE registers with the updated register
    BRA     top                 ; back to menu

loadRec
    MOVE.L  (SP)+, D1           ; Pop contents of D1 off the stack and back into D1
    
    MOVE.L  A1, -(SP)           ; SAVE A1
    LEA     five, A1            ; Load the address of five into A1
    BSR     PRINTSTRING         ; Display text
    MOVE.L  (SP)+, A1           ; RESTORE A1

    BSR     STORE_SREC          ; will store into SREC_START

    MOVE.L  A1, -(SP)           ; Push contents of D0 onto stack
    LEA     done, A1            ; Load the address of done into A1
    BSR     PRINTSTRING         ; Display text
    MOVE.L  (SP)+, A1           ; Pop A1 off Stack and back into A1
    BRA     top                 ; back to menu
    
runRec
    MOVE.L  (SP)+, D1           ; Pop contents of D1 off the stack and back into D1

    MOVE.L  A1, -(SP)           ; Push contents of D0 onto stack
    LEA     six, A1             ; Load the address of six into A1
    BSR     PRINTSTRING         ; Display text
    MOVE.L  (SP)+, A1           ; Pop A1 off Stack and back into A1

    BSR SREC_START              ; The S-REC is stored here and will run if loaded and return to here
    
    MOVE.L  A1, -(A7)           ; Push contents of D0 onto stack
    LEA     done, A1            ; Load the address of done into A1
    BSR     PRINTSTRING         ; Display text
    MOVE.L  (SP)+, A1           ; Pop A1 off Stack and back into A1
    BRA     top                 ; back to menu

* ------------------------------------------------
*                Read in and store S-REC
*               D0 : S-REC Byte count
*               D1 : any read subroutine will store into D1
*               D2 : address manipulation
*               D3 : Checksum of incoming data
*               A0 : The actuall start of the S-REC
*               A1 : The offset for the incoming S-REC
* ------------------------------------------------
STORE_SREC
    MOVEM.L D0-D3/A0-A1, -(SP)  ; SAVE regs D0,D1,D2,D3,A0,A1 to stack
    CLR.L     D0
    CLR.L     D1
    CLR.L     D2
    CLR.L     D3
.newSREC
    BSR     READCHAR
    CMP     #$0D, D1            ; If CR
    BEQ     .newSREC
    CMP     #$0A, D1            ; If LF
    BEQ     .newSREC
    CMP     #$53, D1            ; check if equal to 'S'
    BNE     ERROR               ; If not 'S' then ERROR
    CLR     D3                  ; Clear the low word of checksum
    
    BSR     readNibble
    CMP     #0, D1              ; If S0
    BEQ     .readS0S1           ; Read in a 2 byte address
    CMP     #1, D1              ; If S1
    BEQ     .readS0S1           ; Read in a 2 byte address
    CMP     #8, D1              ; If S8
    BEQ     .readS8             ; Read in a 3 byte address

.done
    MOVEM.L (SP)+, D0-D3/A0-A1  ; RESTORE regs D0,D1,D2,D3,A0,A1 from stack
    RTS

.readS0S1
    LEA     SREC_START, A0      ; Put starting location of SREC into A0
    MOVE.L  #$00000000, A1      ; Clear A1 for use
    BSR     readByte            ; Get count (counting bytes in the SREC), returns in D1
    MOVE.B  D1, D0              ; Count is now D0
    ADD     D0, D3              ; Add the first byte to the checksum
    
    SUB     #2, D0              ; Subtract 2 bytes from count get the address
    BSR     readByte            ; Get first byte of the address, returns in D1
    ADD     D1, D3              ; Add address to checksum
    MOVE.L  D1, D2              ; Store partial address in D2
    LSL     #8, D2              ; Shift left 2 bytes
    BSR     readByte            ; Get the rest of the address, returns in D1
    ADD     D1, D3              ; Add address to checksum
    MOVE.B  D1, D2              ; Move the lower byte of the address into D2
    MOVE.L  D2, A1              ; Move entire address into A1
    
    BSR     .getData            ; Get the data from the SREC
    BRA     .newSREC
.readS8
    BSR     readByte            ; Get count (counting bytes in the SREC), returns in D1
    MOVE.B  D1, D0              ; Count is now D0
    ADD     D0, D3              ; Add count to checksum
    
    SUB     #3, D0              ; Subtract 2 from count get the address
    BSR     readByte            ; Get first byte of the address, returns in D1
    ADD     D1, D3              ; Add address to checksum
    MOVE.L  D1, D2              ; Store partial address
    SWAP    D2                  ; Swap to high word
    BSR     readByte            ; Get second byte of the address, returns in D1
    ADD     D1, D3              ; Add address to checksum
    MOVE.L  D1, D2              ; Store partial address
    LSL     #8, D2              ; Shift left 2 bytes
    BSR     readByte            ; Get the rest of the address, returns in D1
    ADD     D1, D3              ; Add address to checksum
    MOVE.B  D1, D2              ; Move the lower byte of the address into D2
    CMP     #0, D2              ; If Address dose not start at $000000
    BNE     ORGERROR            ; Origin Error
    
    
    BSR     .getData            ; Get the data from the SREC

    MOVE.B  #$4E, D1            ; This will append and RTS to every program
    MOVE.B  D1, (A0,A1.L)       ; Moves data into A0, offseted by A1
    ADD     #1, A0              ; Incrementing A0 by 1 byte
    MOVE.B  #$75, D1            ; This will append and RTS to every program
    MOVE.B  D1, (A0,A1.L)       ; Moves data into A0, offseted by A1
    ADD     #1, A0              ; Incrementing A0 by 1 byte
    
    BRA     .done

.getData
    CMP     #1, D0              ; If count is at last byte
    BEQ     .checksum           ; then branch to .checksum (.checksum is the only exit out of .getData)
    BSR     .getNext            ; Otherwise, get the next byte from the S-REC
    BSR     .checkLEA           ; Check if the program is try loading an address (if it is, it will need to be offset)
    BRA     .getData            ; loop

.checksum
    
    NOT.W   D3                  ; Get one's compliment of the checksum
    AND     #$00FF, D3          ; Clear the high byte
    BSR     readByte            ; Get the real checksum, returns in D1
    CMP     D3, D1              ; Compare if they are equal
    BNE     CHECKSUMERROR       ; If they are not equal, error
    RTS                         ; (goes back to readS0S1 or readS8)

.getNext
    BSR     readByte            ; Get the next byte of data
    ADD     D1, D3              ; Add data to checksum
    MOVE.B  D1, (A0,A1.L)       ; Moves data into A0, offseted by A1
    ADD     #1, A0              ; Go to the next byte in memory getting ready to store the next byte
    SUB     #1, D0              ; Decerment count by 1
    RTS
    
.checkLEA
    CMP     #$43, D1            ; If D1 is equal to #$43 means it is possibly an LEA command
    BNE     .notLEA
    BSR     .getNext
    CMP     #$F9, D1            ; If D1 is equal to #$F9, this completes the Op-code for LEA
    BNE     .notLEA
    BSR     .getNext            ; Get the location they are loading $[00]000000
    BSR     .getNext            ; Get the location they are loading $00[00]0000
    BSR     .getNext            ; Get the location they are loading $0000[00]00
    ADD.B   #$40, D1            ; Add offset to D1 (look at SREC_START it should be $4000)
    SUB     #1, A0              ; Go back to location where D1 was stored (from subroutine .getnext)
    MOVE.B  D1, (A0,A1.L)       ; Moves new data into A0, offseted by A1
    ADD     #1, A0              ; Incrementing A0 by 1 byte
    BSR     .getNext            ; Get the location they are loading $000000[00]
.notLEA
    RTS

* ------------------------------------------------
*                Reading Character
*             Reads character into D1
* ------------------------------------------------
readLong
    MOVE.L  D2, -(SP)           ; SAVE D2
    BSR     readWord            ;
    MOVE.W  D1, D2              ; Moves D1 into D2 to clear it
    CLR     D1                  ; Clear D1
    SWAP    D2                  ;
    BSR     readWord            ;
    MOVE.W  D1, D2
    MOVE.L  D2, D1              ;
    MOVE.L  (SP)+, D2           ; RESTORE D2
    RTS


readAddress
    MOVE.L  D2, -(SP)           ; SAVE D2
    MOVE.W  D1, D2              ; Moves D1 into D2 to clear it
    CLR     D1                  ; Clear D1
    BSR     readByte            ;
    MOVE.B  D1, D2              ; Moves D1 into D2 to clear it
    SWAP    D2                  ;
    BSR     readWord            ;
    MOVE.W  D1, D2              ; Moves the lower word into D2
    MOVE.L  D2, D1              ; Moves the entire longword into D1
    MOVE.L  (SP)+, D2           ; RESTORE D2   
    RTS

readWord
    * No reason to clear D1
    MOVE.L  D2, -(SP)           ; SAVE D2
    BSR     readByte            ;
    MOVE.B  D1, D2              ; Move the byte into D2
    LSL     #8, D2              ; Shift the byte left one byte
    BSR     readByte            ;
    MOVE.B  D1, D2              ;
    MOVE.W  D2, D1
    MOVE.L  (SP)+, D2           ; RESTORE D2 
    RTS

readByte
    MOVE.L  D2, -(SP)           ; SAVE D2
    CLR     D1                  ; Clear D1
    MOVE.W  #$0000, D2          ; Clear Register for use
    BSR     readNibble
    MOVE.B  D1, D2              ; Move the nibble into D2
    LSL     #4, D2              ; Shift the D2 left by one Nibble
    BSR     readNibble          ;
    OR      D2,   D1            ; Moves final byte into D1
    MOVE.L  (SP)+, D2           ; RESTORE D2
    RTS

readNibble
    CLR     D1
    BSR     READCHAR            ; Reads in a single ASCII byte then Convert to a single Nibble
    CMPI    #$39, D1            ; Compare to hex 39, which is 9 in decimal
    BLE     .numToBinary        ; Branch to numToBinary if less than or equal
    CMPI    #$41, D1            ; Compare to hex 41, which is 'A'
    BLT     ERROR               ; Branch to ERROR if less than
    CMPI    #$46, D1            ; Compare to hex 46, which is 'F'
    BLE     .convertLetter      ; Branch to convertLetter if less than or equal
    CMPI    #$61, D1            ; Compare to hex 61, which is 'a'
    BLT     ERROR               ; Branch to ERROR if less than
    CMPI    #$66, D1            ; Compare to hex 66, which is 'f'
    BGT     ERROR               ; Branch to ERROR if greater than, Otherwise convert
.convertLetter
    AND     #$0F, D1            ; Clear the 4 MSB
    ADD     #$09, D1            ; Adds D1 to 9 which will make give you a letter in hex
    RTS                         ; Return
.numToBinary
    CMPI    #$30, D1            ; Compare to hex 30, which is 0 in decimal
    BLT     ERROR               ; Branch to ERROR if less than
    AND     #$0F, D1            ; Otherwise, convert to hex
    RTS                         ; Return
* ------------------------------------------------------
* READCHAR gets an input character and stores is in D1
* ------------------------------------------------------
READCHAR
    *************
    *   DUART   *
    *************
*     MOVE.L  A0, -(SP)           ; SAVE A0
*     CLR     D1
*     LEA     DUART_START, A0     ; Load the DUART address lines
* .Rxready
*     BTST    #RxRDY, SRA(A0)     ; Check if the DUART is ready to recieve
*     BEQ     .Rxready            ; RxRDY=0 So, if the Status Register (SRA) is equal to 0 then its not ready 
*     MOVE.B  RBA(A0), D1         ; If it is ready to recieve move the char into D1
*     * Txready is echoing the character *
* .Txready
*     BTST    #TxRDY, SRA(A0)     ; Check if the DUART is ready to transmit
*     BEQ     .Txready            ; TxRDY=2 So, if the Status Registar (SRA) is equal to 2 then its not ready 
*     MOVE.B  D1, TBA(A0)         ; If it is ready to transmit, move the onto the Transfer Hold Register

*     MOVE.L  (SP)+, A0           ; RESTORE A0
*     RTS

    *************
    *    SIM    *
    *************
    MOVE.L  D0, -(SP)            ; Push onto the stack
    MOVE.B  #5, D0               ; Tell TRAP #15 to read a single char into D1.B
    TRAP    #15                  ; Syscall basicly
    MOVE.L  (SP)+, D0            ; Pop off stack
    RTS

* ----------------------------------------------------------------------
*                            Convert to ASCII
* Converts the longword in D1 to ASCII and stores it at location STRING
* ----------------------------------------------------------------------
CONVERTTOASCII
    MOVE.L  A1, -(SP)           ; SAVE A1
    MOVE.L  D2, -(SP)           ; SAVE D2
    MOVE.L  D3, -(SP)           ; SAVE D3
    MOVE.L  D4, -(SP)           ; SAVE D4
    CLR     D2
    CLR     D3
    CLR     D4

    LEA     STRING,A1           ; Storing the string at location STRING
    MOVE.B  #$0D,(A1)+          ; Add a Character Return to the beginning of the line
    MOVE.B  #$0A,(A1)+          ; Add a Line Feed (new line) too

    MOVE.L  #1, D4              ; Binary flag for looping twice
.swap
    MOVE    #12, D3             ; D3 iteratates through each character in the word (decrements by 4)
    SWAP    D1                  ; Swap to print high end first
.start
    MOVE.W  D1, D2              ; Move data from D1 into D2 for munipulation    
    LSR     D3, D2              ; Shift the bits to the right D3 times (if D3 is 12 then $XXXX --> $000X)
    AND     #$000F, D2          ; Make sure we are working with one nibble
    
    CMPI    #$9, D2             ; Comparing to see if it is a number or letter (0-9 or A-F)
    BGT     .letter             ; If hex value is a letter, branch to letter   
    
    ADD     #$30, D2            ; Otherwise, its a number. So add hex 30, which is an ASCII number (30 to 39)
    BRA     .storeChar          ; Once obtaining the ASCII number branch to .storeChar   
    
.letter     SUBI #$9, D2        ; Subtracting 9 from hex A-F resulting in 1-6
    ADD     #$40, D2            ; Adding hex 40 is the ASCII letter (41-46 or A-F)

.storeChar
    MOVE.B  D2, (A1)+           ; Append the ASCII char to STRING
    CMP     #0, D3              ; Has D3 reached zero (is there any more to conver?)
    BEQ     .checkLoop          ; if D3 equals zero, branch to checkLoop
    SUBI    #4, D3              ; Subtract 4 from 12 (D3 is essentually counting 3 down to 0)
    BRA     .start              ; If the ASCII is not finished, Branch to beginning
.checkLoop
    CMP     #1, D4              ; Check if it has looped already
    BNE     .done               ; If it has looped, then entire longword has been converted, Branch to done
    MOVE    #0, D4              ; If not set D4 to 0
    BRA     .swap               ; Branch to the swap to the lower word
.done
    MOVE.B  #$00, (A1)+         ; Append a null to the STRING to tell PRINTSTRING that it is done.
    MOVE.L  (SP)+, D4           ; RESTORE D4
    MOVE.L  (SP)+, D3           ; RESTORE D3
    MOVE.L  (SP)+, D2           ; RESTORE D2
    MOVE.L  (SP)+, A1           ; RESTORE A1
    RTS

* ----------------------------------------------------
*PRINTSTRING prints the null terminated string at A1
* ----------------------------------------------------
PRINTSTRING
    *************
    *   DUART   *
    *************
*     MOVE.L  A0, -(SP)           ; SAVE A0
*     MOVE.L  D1, -(SP)           ; SAVE D1
*     CLR     D1                  ; Make sure it is zero for CMP
*     LEA     DUART_START, A0     ; Load the DUART address lines
* .print
*     MOVE.B  (A1)+, D1           ; Move the next char into D1
*     CMP     #0, D1              ; If the char is null,
*     BEQ     .end                ; goto .end
* .isready
*     BTST    #TxRDY, SRA(A0)     ; Check if the DUART is ready to transmit
*     BEQ     .isready            ; TxRDY=2 So, if the Status Registar (SRA) is equal to 2 then its not ready
*     MOVE.B  D1, TBA(A0)         ; If it is ready to transmit, move the onto the Transfer Hold Register
*     BRA     .print              ; loop
* .end
*     MOVE.L  (SP)+, D1           ; RESTORE D1
*     MOVE.L  (SP)+, A0           ; RESTORE A0
*     RTS
    
    *************
    *    SIM    *
    *************
    MOVE.L  D1, -(SP)           ; SAVE D1
    MOVE.L  D0, -(SP)           ; SAVE D0
    MOVE.L  #0, D1              ; clear D1
.loop
    MOVE.B  (A1)+,  D1
    MOVE    #6,     D0          ; Prints a single charicture that is stored in D1.B
    TRAP    #15                 ; syscall for simulation only
    CMP     #0,     D1          ; Check if the byte is equal to zero
    BNE     .loop
    MOVE.L  (SP)+, D0           ; RESTORE D0
    MOVE.L  (SP)+, D1           ; RESTORE D1
    RTS

* Print Line
ENDL
    MOVE.L  A1, -(SP)
    LEA     newline, A1         ; Loads the text
    BSR     PRINTSTRING         ; Display error text
    MOVE.L  (SP)+, A1
    RTS

* If there is an error
ERROR
    BSR     ENDL                ; print new line
    MOVE.L  A1, -(SP)
    LEA     textError, A1       ; Loads the text
    BSR     PRINTSTRING         ; Display error text
    MOVE.L  (SP)+, A1
    BRA     top
    
* If there is a checksum error
CHECKSUMERROR
    BSR     ENDL                ; print new line
    MOVE.L  A1, -(SP)
    LEA     sumError, A1        ; Loads the text
    BSR     PRINTSTRING         ; Display error text
    MOVE.L  (SP)+, A1
    BRA     top
    
* If there is an origin error
ORGERROR
    BSR     ENDL                ; print new line
    MOVE.L  A1, -(SP)
    LEA     originError, A1     ; Loads the text
    BSR     PRINTSTRING         ; Display error text
    MOVE.L  (SP)+, A1
    BRA     top
    
* ------------------------------------
* Put variables and constants here
* ------------------------------------

* Chip starts                     [XX] This is how to tell the CPLD which chip you are selecting  
ROM_START   EQU     $000000     ; 0000 0000  [00]00 0000 0000 0000 => (00[0]000 - 003FFF)
RAM_START   EQU     $004000     ; 0000 0000  [01]00 0000 0000 0000 => (00[4]000 - 007FFF)
DUART_START EQU     $008000     ; 0000 0000  [10]00 0000 0000 0000 => (00[8]000 - 00800F)

SREC_START  EQU     $004000     ; Starting at the beginning of RAM
STACK_START EQU     $008000     ; Starting at the end of RAM

* DUART CONST
MR1A        EQU     1	        ; Mode Register1
MR2A        EQU     1	        ; points here after MR1A is set
SRA         EQU     3           ; Status Register (read)
CSRA        EQU     3           ; Clock Select Register
CRA         EQU     5	        ; Command Register
TBA         EQU     7           ; Transfer Holding Register
RBA         EQU     7	        ; Receive Holding Register
ACR         EQU     9	        ; Auxiliary control register
RxRDY       EQU     0	        ; Receive ready bit position
TxRDY       EQU     2	        ; Transmit ready bit position
BAUD        EQU     $CC         ; baud rate value = 19,200 baud



STRING      EQU     $7000       ; Storing strings here
CR          EQU     $0D
LF          EQU     $0A

newline     DC.B    CR,LF,0

originError     DC.B 'ERROR! S-RECORDS MUST HAVE AN ORIGIN OF $0000',0
textError       DC.B 'ERROR! NOT AN OPTION!',0
sumError        DC.B 'ERROR! CHECKSUM IS WORNG!',0

menu
    DC.B    CR,LF
    DC.B    'Please select one of the Following:',CR,LF
    DC.B    '1) Read from memory location',CR,LF
    DC.B    '2) Write to memory location',CR,LF
    DC.B    '3) Read from register',CR,LF
    DC.B    '4) Write to register',CR,LF
    DC.B    '5) Load S-Record',CR,LF
    DC.B    '6) Run S-Record',CR,LF,CR,LF,0

* ------------------------------------
* Intructions for all the subroutines
* ------------------------------------
one
    DC.B    CR,LF
    DC.B    '     ---Read from memory location---',CR,LF
    DC.B    'Please enter the address location to read from ROM or RAM (000000 - 007FFF) ',CR,LF
    DC.B    'Please use multiples of 2 or you will break the program.',CR,LF,0
    
two
    DC.B    CR,LF
    DC.B    '       ---Write to memory location---',CR,LF
    DC.B    'Please enter the memory location to write to RAM (004000 - 007FFF)',CR,LF,0
    DC.B    'Please use multiples of 2 or you will break the program.',CR,LF,0
    
three
    DC.B    CR,LF
    DC.B    '          ---Read from register---',CR,LF
    DC.B    'Please enter a register to read (D0-D7 or A0-A6)',CR,LF,0

four
    DC.B    CR,LF
    DC.B    '            ---Write to register---',CR,LF
    DC.B    'Please enter a register to write to (D0-D7 or A0-A6)',CR,LF,0
    
five
    DC.B    CR,LF
    DC.B    '   ---Load S-Record---',CR,LF
    DC.B    'Please enter the S-Record',CR,LF,0
    
six 
    DC.B    CR,LF
    DC.B    '---Runing S-Record---',CR,LF,0

done
    DC.B    CR,LF,'DONE!',CR,LF,0

    END    START                ; Last line of source





























