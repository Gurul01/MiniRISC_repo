//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* Utas�t�s t�pusok:                                                          *
//*            |15....12|11..........8|7......4|3...........0|                 *
//* -A t�pus�: | opk�d  | rX/vez�rl�s |   8 bites konstans   |                 *
//* -B t�pus�: |  1111  | rX/vez�rl�s | opk�d  | rY/vez�rl�s |                 *
//*                                                                            *
//* A 4'b1111 prefix jelzi, hogy a m�sodik operandus nem konstans, hanem       *
//* regiszter, teh�t B t�pus� utas�t�sr�l van sz�.                             *
//******************************************************************************
localparam REG_OP_PREFIX = 4'b1111;


//******************************************************************************
//* MOV rX, addr                                                      A t�pus� *
//* Adatmem�ria olvas�s SP relativ c�mz�ssel: rX <- DMEM[offset + SP] - - - -  *
//*                                                                            *
//*  |15..12|11.....8|7................0|                                      *
//*  | 1101 |   rX   |      offset      |                                      *
//*                                                                            *
//* MOV rX, (rY)                                                      B t�pus� *
//* Adatmem�ria olvas�s indirekt c�mz�ssel: rX <- DMEM[rY]            - - - -  *
//*                                                                            *
//*  |15..12|11.....8|7......4|3.......0|                                      *
//*  | 1111 |   rX   |  1101  |    rY   |                                      *
//******************************************************************************
localparam OPCODE_LD = 4'b1101;


//******************************************************************************
//* MOV addr, rX                                                      A t�pus� *
//* Adatmem�ria �r�s SP relativ c�mz�ssel: DMEM[offset + SP] <- rX    - - - -  *
//*                                                                            *
//*  |15..12|11.....8|7................0|                                      *
//*  | 1001 |   rX   |     offset       |                                      *
//*                                                                            *
//* MOV (rY), rX                                                      B t�pus� *
//* Adatmem�ria �r�s indirekt c�mz�ssel: DMEM[rY] <- rX               - - - -  *
//*                                                                            *
//*  |15..12|11.....8|7......4|3.......0|                                      *
//*  | 1111 |   rX   |  1001  |    rY   |                                      *
//******************************************************************************
localparam OPCODE_ST = 4'b1001;


//******************************************************************************
//* MOV rX, #imm                                                      A t�pus� *
//* Konstans bet�lt�se regiszterbe: rX <- imm                         - - - -  *
//*                                                                            *
//*  |15..12|11.....8|7................0|                                      *
//*  | 1100 |   rX   | 8 bites konstans |                                      *
//*                                                                            *
//* MOV rX, rY                                                        B t�pus� *
//* Adatmozgat�s regiszterb�l regiszterbe: rX <- rY                   - - - -  *
//*                                                                            *
//*  |15..12|11.....8|7......4|3.......0|                                      *
//*  | 1111 |   rX   |  1100  |    rY   |                                      *
//******************************************************************************
localparam OPCODE_MOV = 4'b1100;


//******************************************************************************
//* ADD rX, #imm                                                      A t�pus� *
//* Konstans hozz�ad�sa regiszterhez �tvitel n�lk�l: rX <- rX + imm   Z C N V  *
//*                                                                            *
//* ADC rX, #imm                                                      A t�pus� *
//* Konstans hozz�ad�sa regiszterhez �tvitellel: rX <- rX + imm + C   Z C N V  *
//*                                                                            *
//* SUB rX, #imm                                                      A t�pus� *
//* Konstans kivon�sa regiszterb�l �tvitel n�lk�l: rX <- rX - imm     Z C N V  *
//*                                                                            *
//* SBC rX, #imm                                                      A t�pus� *
//* Konstans kivon�sa regiszterb�l �tvitellel: rX <- rX - imm + C     Z C N V  *
//*                                                                            *
//*  |15..12|11.....8|7................0|                                      *
//*  | 00SC |   rX   | 8 bites konstans |                                      *
//*                                                                            *
//* ADD rX, rY                                                        B t�pus� *
//* Regiszter hozz�ad�sa regiszterhez �tvitel n�lk�l: rX <- rX + rY   Z C N V  *
//*                                                                            *
//* ADC rX, rY                                                        B t�pus� *
//* Regiszter hozz�ad�sa regiszterhez �tvitellel: rX <- rX + rY + C   Z C N V  *
//*                                                                            *
//* SUB rX, rY                                                        B t�pus� *
//* Regiszter kivon�sa regiszterb�l �tvitel n�lk�l: rX <- rX - rY     Z C N V  *
//*                                                                            *
//* SBC rX, rY                                                        B t�pus� *
//* Regiszter kivon�sa regiszterb�l �tvitellel: rX <- rX - rY + C     Z C N V  *
//*                                                                            *
//*  |15..12|11.....8|7......4|3.......0|                                      *
//*  | 1111 |   rX   |  00SC  |    rY   |                                      *
//*                                                                            *
//*  S: m�velet kiv�laszt�sa (0: �sszead�s, 1: kivon�s)                        *
//*  C: �tvitel kiv�laszt�sa (0: �tvitel n�lk�l, 1: �tvitellel)                *
//******************************************************************************
localparam OPCODE_ADD = 4'b0000;
localparam OPCODE_ADC = 4'b0001;
localparam OPCODE_SUB = 4'b0010;
localparam OPCODE_SBC = 4'b0011;


//******************************************************************************
//* CMP rX, #imm                                                      A t�pus� *
//* Regiszter �sszehasonl�t�sa konstanssal atvitel nelkul: rX - imm   Z C N V  *
//*                                                                            *
//*  |15..12|11.....8|7................0|                                      *
//*  | 1010 |   rX   | 8 bites konstans |                                      *
//*                                                                            *
//* CMP rX, rY                                                        B t�pus� *
//* Regiszter �sszehasonl�t�sa regiszterrel atvitel nelkul: rX - rY   Z C N V  *
//*                                                                            *
//*  |15..12|11.....8|7......4|3.......0|                                      *
//*  | 1111 |   rX   |  1010  |    rY   |                                      *
//******************************************************************************
localparam OPCODE_CMP = 4'b1010;


//******************************************************************************
//* CMC rX, #imm                                                      A t�pus� *
//* Regiszter �sszehasonl�t�sa konstanssal atvitellel: rX - imm + C   Z C N V  *
//*                                                                            *
//*  |15..12|11.....8|7................0|                                      *
//*  | 1011 |   rX   | 8 bites konstans |                                      *
//*                                                                            *
//* CMC rX, rY                                                        B t�pus� *
//* Regiszter �sszehasonl�t�sa regiszterrel atvitellel: rX - rY + C   Z C N V  *
//*                                                                            *
//*  |15..12|11.....8|7......4|3.......0|                                      *
//*  | 1111 |   rX   |  1011  |    rY   |                                      *
//******************************************************************************
localparam OPCODE_CMC = 4'b1011;


//******************************************************************************
//* AND rX, #imm                                                      A t�pus� *
//* Bitenk�nti �S konstanssal: rX <- rX & imm                         Z - N -  *
//*                                                                            *
//* OR  rX, #imm                                                      A t�pus� *
//* Bitenk�nti VAGY konstanssal: rX <- rX | imm                       Z - N -  *
//*                                                                            *
//* XOR rX, #imm                                                      A t�pus� *
//* Bitenk�nti XOR konstanssal: rX <- rX ^ imm                        Z - N -  *
//*                                                                            *
//* SWP rX                                                            A t�pus� *
//* Als�/fels� 4 bit felcser�l�se: rX <- {rX[3:0], rX[7:4]}           Z - N -  *
//*                                                                            *
//*  |15..12|11.....8|7................0|                                      *
//*  | 01AB |   rX   | 8 bites konstans |                                      *
//*                                                                            *
//* AND rX, rY                                                        B t�pus� *
//* Bitenk�nti �S regiszterrel: rX <- rX & rY                         Z - N -  *
//*                                                                            *
//* OR  rX, rY                                                        B t�pus� *
//* Bitenk�nti VAGY regiszterrel: rX <- rX | rY                       Z - N -  *
//*                                                                            *
//* XOR rX, rY                                                        B t�pus� *
//* Bitenk�nti XOR regiszterrel: rX <- rX ^ rY                        Z - N -  *
//*                                                                            *
//*  |15..12|11.....8|7......4|3.......0|                                      *
//*  | 1111 |   rX   |  01AB  |    rY   |                                      *
//*                                                                            *
//*  AB: m�velet kiv�laszt�sa (00: �S, 01: VAGY, 10: XOR, 11: csere)           *
//*                                                                            *
//*  Megjegyz�s: a csere m�velet csak A t�pus� utas�t�sn�l �rtelmezett,        *
//*  B t�pus� utas�t�sn�l ez a m�veleti k�d shiftel�st/forgat�st hajt v�gre.   *
//******************************************************************************
localparam OPCODE_AND = 4'b0100;
localparam OPCODE_OR  = 4'b0101;
localparam OPCODE_XOR = 4'b0110;

localparam LOGIC_AND = 2'b00;
localparam LOGIC_OR  = 2'b01;
localparam LOGIC_XOR = 2'b10;


//******************************************************************************
//* TST rX, #imm                                                      A t�pus� *
//* Bittesztel�s konstanssal: rX & imm                                Z - N -  *
//*                                                                            *
//*  |15..12|11.....8|7................0|                                      *
//*  | 1000 |   rX   | 8 bites konstans |                                      *
//*                                                                            *
//* TST rX, rY                                                        B t�pus� *
//* Bittesztel�s regiszterrel: rX & rY                                Z - N -  *
//*                                                                            *
//*  |15..12|11.....8|7......4|3.......0|                                      *
//*  | 1111 |   rX   |  1000  |    rY   |                                      *
//******************************************************************************
localparam OPCODE_TST = 4'b1000;


//******************************************************************************
//* SL0 rX                                                            B t�pus� *
//* Shiftel�s balra (0): rX <- {rX[6:0], 0}, C <- rX[7]               Z C N -  *
//*                                                                            *
//* SL1 rX                                                            B t�pus� *
//* Shiftel�s balra (1): rX <- {rX[6:0], 1}, C <- rX[7]               Z C N -  *
//*                                                                            *
//* SR0 rX                                                            B t�pus� *
//* Shiftel�s jobbra (0): rX <- {0, rX[7:1]}, C <- rX[0]              Z C N -  *
//*                                                                            *
//* SR1 rX                                                            B t�pus� *
//* Shiftel�s jobbra (1): rX <- {1, rX[7:1]}, C <- rX[0]              Z C N -  *
//*                                                                            *
//* ASR rX                                                            B t�pus� *
//* Aritmetikai shift jobbra: rX <- {rX[7], rX[7:1]}, C <- rX[0]      Z C N -  *
//*                                                                            *
//* ROL rX                                                            B t�pus� *
//* Forgat�s balra: rX <- {rX[6:0], rX[7]}, C <- rX[7]                Z C N -  *
//*                                                                            *
//* ROR rX                                                            B t�pus� *
//* Forgat�s jobbra: rX <- {rX[0], rX[7:1]}, C <- rX[0]               Z C N -  *
//*                                                                            *
//* RLC rX                                                            B t�pus� *
//* Forgat�s balra carry-vel: rX <- {rX[6:0], C}, C <- rX[7]          Z C N -  *
//*                                                                            *
//* RRC rX                                                            B t�pus� *
//* Forgat�s jobbra carry-vel: rX <- {C, rX[7:1]}, C <- rX[0]         Z C N -  *
//*                                                                            *
//*  |15..12|11.....8|7......4|3.......0|                                      *
//*  | 1111 |   rX   |  0111  |  AIRD   |                                      *
//*                                                                            *
//*  D: ir�ny kiv�laszt�sa (0: balra, 1: jobbra)                               *
//*  R: m�velet kiv�laszt�sa (0: shiftel�s, 1: forgat�s)                       *
//*  I: a beshiftelt bit �rt�ke/kiv�laszt�sa (0: 0/kishiftelt bit, 1: 1/carry) *
//*  A: a shiftel�s t�pusa (0: norm�l, 1: aritmetikai)                         *
//******************************************************************************
localparam OPCODE_SHIFT = 4'b0111;

localparam SHIFT_SHL  = 2'b00;
localparam SHIFT_SHR  = 2'b01;
localparam SHIFT_ROL  = 2'b10;
localparam SHIFT_ROR  = 2'b11;


//******************************************************************************
//* JMP addr - Felt�tel n�lk�li ugr�s (PC <- addr)                    A t�pus� *
//* JZ  addr - Ugr�s, ha a Z flag 1   (PC <- addr, ha Z=1)            - - - -  *
//* JNZ addr - Ugr�s, ha a Z flag 0   (PC <- addr, ha Z=0)                     *
//* JC  addr - Ugr�s, ha a C flag 1   (PC <- addr, ha C=1)                     *
//* JNC addr - Ugr�s, ha a C flag 0   (PC <- addr, ha C=0)                     *
//* JN  addr - Ugr�s, ha az N flag 1  (PC <- addr, ha N=1)                     *
//* JNN addr - Ugr�s, ha az N flag 0  (PC <- addr, ha N=0)                     *
//* JV  addr - Ugr�s, ha a V flag 1   (PC <- addr, ha V=1)                     *
//* JNV addr - Ugr�s, ha a V flag 0   (PC <- addr, ha V=0)                     *
//* JSR addr - Szubrutinh�v�s         (stack <- PC <- addr)                    *
//*                                                                            *
//*  |15..12|11.....8|7................0|                                      *
//*  | 1110 | m�velet|programmem�ria c�m|                                      *
//*                                                                            *
//* JMP (rY) - Felt�tel n�lk�li ugr�s (PC <- rY)                      B t�pus� *
//* JZ  (rY) - Ugr�s, ha a Z flag 1   (PC <- rY, ha Z=1)              - - - -  *
//* JNZ (rY) - Ugr�s, ha a Z flag 0   (PC <- rY, ha Z=0)                       *
//* JC  (rY) - Ugr�s, ha a C flag 1   (PC <- rY, ha C=1)                       *
//* JNC (rY) - Ugr�s, ha a C flag 0   (PC <- rY, ha C=0)                       *
//* JN  (rY) - Ugr�s, ha az N flag 1  (PC <- rY, ha N=1)                       *
//* JNN (rY) - Ugr�s, ha az N flag 0  (PC <- rY, ha N=0)                       *
//* JV  (rY) - Ugr�s, ha a V flag 1   (PC <- rY, ha V=1)                       *
//* JNV (rY) - Ugr�s, ha a V flag 0   (PC <- rY, ha V=0)                       *
//* JSR (rY) - Szubrutinh�v�s         (stack <- PC <- rY)                      *
//*                                                                            *
//*  |15..12|11.....8|7......4|3.......0|                                      *
//*  | 1111 | m�velet|  1110  |    rY   |                                      *
//******************************************************************************
localparam OPCODE_CTRL = 4'b1110;

localparam CTRL_JMP = 4'b0000;
localparam CTRL_JZ  = 4'b0001;
localparam CTRL_JNZ = 4'b0010;
localparam CTRL_JC  = 4'b0011;
localparam CTRL_JNC = 4'b0100;
localparam CTRL_JN  = 4'b0101;
localparam CTRL_JNN = 4'b0110;
localparam CTRL_JV  = 4'b0111;
localparam CTRL_JNV = 4'b1000;
localparam CTRL_JSR = 4'b1001;
//Signed
localparam CTRL_JL  = 4'b1010; // Less Than            (<):  SF ≠ OF
localparam CTRL_JLE = 4'b1011; // Less Than or Equal   (<=): ZF = 1 OR SF ≠ OF
localparam CTRL_JH  = 4'b1100; // Higher Than          (>):  ZF = 0 AND SF = OF
localparam CTRL_JHE = 4'b1101; // Higher Than or Equal (>=): SF = OF
//Unsigned
localparam CTRL_JSE = 4'b1110; // Less Than or Equal (<=): ZF = 1 OR CF = 1
localparam CTRL_JG  = 4'b1111; // Greater Than       (>):  CF = 0 AND ZF = 0


//******************************************************************************
//* RTS - Visszat�r�s szubrutinb�l    (PC <- stack)                   B t�pus� *
//* RTI - Visszat�r�s megszak�t�sb�l  (PC,Z,C,N,V,IE <- stack)        - - - -  *
//* CLI - Megszak�t�sok tilt�sa       (IE <- 0)                                *
//* STI - Megszak�t�sok enged�lyez�se (IE <- 1)                                *
//*                                                                            *
//*  |15..12|11.....8|7......4|3......0|                                       *
//*  | 1111 | m�velet|  1111  |  0000  |                                       *
//******************************************************************************
localparam OPCODE_CTRL_NO_DATA = 4'b1111;

//Az OPCODE_CTRL alatt ertelmezett CTRL_JMP-nak megfelelo kod PROHIBITED statuszu az OPCODE_CTRL_NO_DATA alatt.
localparam PROHIBITED = 4'b0000;
localparam CTRL_RTS   = 4'b1010;
localparam CTRL_RTI   = 4'b1011;
localparam CTRL_CLI   = 4'b1100;
localparam CTRL_STI   = 4'b1101;

