`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* Aritmetikai-logikai egység (ALU). Támogatott mûveletek:                    *
//* 1) Adatmozgatás (nincs mûveletvégzés)                                      *
//* 2) Összeadés és kivonás átvitel nélkül, illetve átvitellel                 *
//* 3) Bitenkénti ÉS, VAGY és XOR                                              *
//* 4) Shiftelés és forgatás                                                   *
//******************************************************************************
module alu(
   //Órajel.
   input  wire       clk,
   
   //Vezérlõ bemenetek.
   input  wire [1:0] op_type,       //Az ALU mûvelet típusát kiválasztó jel
   input  wire [1:0] arith_sel,     //Az aritmetikai mûveletet kiválasztó jel
   input  wire [1:0] logic_sel,     //A logikai mûveletet kiválasztó jel
   input  wire [3:0] shift_sel,     //A shiftelési mûveletet kiválasztó jel
   
   //Az operandusok és az eredmény.
   input  wire [7:0] operand1,      //Elsõ operandus
   input  wire [7:0] operand2,      //Második operandus
   output wire [7:0] result,        //Az ALU mûvelet eredménye
   
   //ALU feltétel jelek.
   input  wire [3:0] flag_din,      //A flag-ekbe írandó érték
   input  wire       flag_wr,       //A flag-ek írás engedélyezõ jele
   output reg        flag_z,        //Zero flag
   output reg        flag_c,        //Carry flag
   output reg        flag_n,        //Negative flag
   output reg        flag_v         //Overflow flag
);

`include "control_defs.vh"
`include "opcode_defs.vh"

//******************************************************************************
//* Az aritmetikai mûveletek végrehajtása (összeadás és kivonás).              *
//*                                                                            *
//* Kivonás esetén a 2. operandus kettes komplemensét (/op2 + 1) adjuk hozzá   *
//* az 1. operandushoz. Összeadó/kivonó logikát nem tudunk itt használni, mert *
//* szükséges az átvitel bemenet és kimenet is.                                *
//******************************************************************************

//Az arith_sel[1] bit határozza meg az elvégzendõ mûveletet:
//0: összeadás
//1: kivonás (kettes komplemens hozzáadása)
wire [7:0] adder_op2 = operand2 ^ {8{arith_sel[1]}};

//Az arith_sel[0] bit választja ki a C flag használatát:
//0: mûveletvégzés átvitel nélkül
//1: mûveletvégzés átvitellel (kivonás esetén negáljuk)
wire carry_in  = (arith_sel[0]) ? (flag_c ^ arith_sel[1]) : arith_sel[1];

//Az összeadás elvégzése. Az eredmény MSb-je a kimeneti átvitel bit.
wire [8:0] sum = operand1 + adder_op2 + carry_in;

//Kivonás esetén a kimenõ átvitel bitet negáljuk.
wire [8:0] arith_result = {sum[8] ^ arith_sel[1], sum[7:0]};

//A kettes komplemens túlcsordulás észlelése. Túlcsordulás akkor történik,
//ha azonos elõjelû számokat adunk össze és az összeg elõjele ettõl eltér.
wire overflow = (~operand1[7] & ~adder_op2[7] &  arith_result[7]) |
                ( operand1[7] &  adder_op2[7] & ~arith_result[7]);


//******************************************************************************
//* A logikai mûveletek végrehajtása (bitenkénti ÉS, VAGY, XOR). Itt hajtjuk   *
//* végre az alsó és a felsõ 4 bit felcserélését is.                           *
//******************************************************************************
reg [7:0] logic_result;

always @(*)
begin
   case (logic_sel)
      //Bitenkénti ÉS
      LOGIC_AND: logic_result <= operand1 & operand2;
      //Bitenkénti VAGY
      LOGIC_OR : logic_result <= operand1 | operand2;
      //Bitenkénti XOR
      LOGIC_XOR: logic_result <= operand1 ^ operand2;
      //Az alsó és a felsõ 4 bit felcserélése
      default  : logic_result <= {operand1[3:0], operand1[7:4]};
   endcase
end


//******************************************************************************
//* A shiftelési és a forgatási mûveletek elvégzése.                           *
//******************************************************************************
reg [8:0] shift_result;

//Forgatás esetén a shift_sel[2] választja ki a beléptetendõ bitet:
//0: sima forgatás, a kilépõ bit kerül beléptetésre a másik oldalon
//1: forgatás a carry flag-en keresztül
wire rot_in_l = (shift_sel[2]) ? flag_c : operand1[7];
wire rot_in_r = (shift_sel[2]) ? flag_c : operand1[0];

//A shift_sel[3] választja ki a shiftelés típusát:
//0: normál shiftelés
//1: aritmetikai shiftelés, az MSb (elõjel bit) helyben marad
wire shr_msb  = (shift_sel[3]) ? operand1[7] : shift_sel[2];

//A shiftelés/forgatás elvégzése. Az eredmény MSb-je a kimeneti átvitel bit.
always @(*)
begin
   case (shift_sel[1:0])
      //Shiftelés balra
      SHIFT_SHL: shift_result <= {operand1[7], operand1[6:0], shift_sel[2]};
      //Shiftelés jobbra
      SHIFT_SHR: shift_result <= {operand1[0], shr_msb, operand1[7:1]};
      //Forgatás balra
      SHIFT_ROL: shift_result <= {operand1[7], operand1[6:0], rot_in_l};
      //Forgatás jobbra
      SHIFT_ROR: shift_result <= {operand1[0], rot_in_r, operand1[7:1]};
   endcase
end


//******************************************************************************
//* Az ALU eredményt kiválasztó multiplexer.                                   *
//******************************************************************************
reg [8:0] alu_result;

always @(*)
begin
   case (op_type)
      ALU_MOVE : alu_result <= {1'b0, operand2};         //Adatmozgatás
      ALU_ARITH: alu_result <= arith_result;             //Aritmetikai mûvelet
      ALU_LOGIC: alu_result <= {1'b0, logic_result};     //Logikai mûvelet
      ALU_SHIFT: alu_result <= shift_result;             //Shiftelés/forgatás
   endcase
end

//A multiplexer kimenetének alsó 8 bitje az ALU eredmény, az MSb
//a carry flag új értékét tartalmazza.
assign result = alu_result[7:0];


//******************************************************************************
//* Zero flag (Z).                                                             *
//*                                                                            *
//* Jelzi, ha az ALU mûvelet eredménye 0. Értékét frissíteni kell aritmetikai, *
//* logikai vagy shiftelési/forgatási mûveletek végrehajtása esetén. Írhatónak *
//* kell lennie, mert megszakításból való visszatérésnél vissza kell állítani  *
//* a korábbi értékét.                                                         *
//******************************************************************************
always @(posedge clk)
begin
   if (flag_wr)
      flag_z <= flag_din[Z_FLAG];
   else
      if (op_type != ALU_MOVE)
         flag_z <= (result == 8'd0);
end


//******************************************************************************
//* Carry flag (C).                                                            *
//*                                                                            *
//* Jelzi, ha az aritmetikai mûveletek során átvitel történt, illetve felveszi *
//* a kishiftelt bit értékét shiftelés/forgatás végrehajtása esetén. Írhatónak *
//* kell lennie, mert megszakításból való visszatérésnél vissza kell állítani  *
//* a korábbi értékét.                                                         *
//******************************************************************************
always @(posedge clk)
begin
   if (flag_wr)
      flag_c <= flag_din[C_FLAG];
   else
      if ((op_type == ALU_ARITH) || (op_type == ALU_SHIFT))
         flag_c <= alu_result[8];
end


//******************************************************************************
//* Negative flag (N).                                                         *
//*                                                                            *
//* Jelzi, ha az ALU mûvelet eredménye negatív (az elõjel bit 1). Írhatónak    *
//* kell lennie, mert megszakításból való visszatérésnél vissza kell állítani  *
//* a korábbi értékét.                                                         *
//******************************************************************************
always @(posedge clk)
begin
   if (flag_wr)
      flag_n <= flag_din[N_FLAG];
   else
      if (op_type != ALU_MOVE)
         flag_n <= alu_result[7];
end


//******************************************************************************
//* Overflow flag (V).                                                         *
//*                                                                            *
//* Jelzi, ha kettes komplemens túlcsordulás történt az aritmetikai mûveletek  *
//* végrehajtása esetén. Írhatónak kell lennie, mert megszakításból való       *
//* visszatérésnél vissza kell állítani a korábbi értékét.                     *
//******************************************************************************
always @(posedge clk)
begin
   if (flag_wr)
      flag_v <= flag_din[V_FLAG];
   else
      if (op_type == ALU_ARITH)
         flag_v <= overflow;
end


endmodule
