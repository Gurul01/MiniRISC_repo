`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* Aritmetikai-logikai egys�g (ALU). T�mogatott m�veletek:                    *
//* 1) Adatmozgat�s (nincs m�veletv�gz�s)                                      *
//* 2) �sszead�s �s kivon�s �tvitel n�lk�l, illetve �tvitellel                 *
//* 3) Bitenk�nti �S, VAGY �s XOR                                              *
//* 4) Shiftel�s �s forgat�s                                                   *
//******************************************************************************
module alu(
   //�rajel.
   input  wire       clk,
   
   //Vez�rl� bemenetek.
   input  wire [1:0] op_type,       //Az ALU m�velet t�pus�t kiv�laszt� jel
   input  wire [1:0] arith_sel,     //Az aritmetikai m�veletet kiv�laszt� jel
   input  wire [1:0] logic_sel,     //A logikai m�veletet kiv�laszt� jel
   input  wire [3:0] shift_sel,     //A shiftel�si m�veletet kiv�laszt� jel
   
   //Az operandusok �s az eredm�ny.
   input  wire [7:0] operand1,      //Els� operandus
   input  wire [7:0] operand2,      //M�sodik operandus
   output wire [7:0] result,        //Az ALU m�velet eredm�nye
   
   //ALU felt�tel jelek.
   input  wire [3:0] flag_din,      //A flag-ekbe �rand� �rt�k
   input  wire       flag_wr,       //A flag-ek �r�s enged�lyez� jele
   output reg        flag_z,        //Zero flag
   output reg        flag_c,        //Carry flag
   output reg        flag_n,        //Negative flag
   output reg        flag_v         //Overflow flag
);

`include "src\MiniRISC_CPU\control_defs.vh"
`include "src\MiniRISC_CPU\opcode_defs.vh"

//******************************************************************************
//* Az aritmetikai m�veletek v�grehajt�sa (�sszead�s �s kivon�s).              *
//*                                                                            *
//* Kivon�s eset�n a 2. operandus kettes komplemens�t (/op2 + 1) adjuk hozz�   *
//* az 1. operandushoz. �sszead�/kivon� logik�t nem tudunk itt haszn�lni, mert *
//* sz�ks�ges az �tvitel bemenet �s kimenet is.                                *
//******************************************************************************

//Az arith_sel[1] bit hat�rozza meg az elv�gzend� m�veletet:
//0: �sszead�s
//1: kivon�s (kettes komplemens hozz�ad�sa)
wire [7:0] adder_op2 = operand2 ^ {8{arith_sel[1]}};

//Az arith_sel[0] bit v�lasztja ki a C flag haszn�lat�t:
//0: m�veletv�gz�s �tvitel n�lk�l
//1: m�veletv�gz�s �tvitellel (kivon�s eset�n neg�ljuk)
wire carry_in  = (arith_sel[0]) ? (flag_c ^ arith_sel[1]) : arith_sel[1];

//Az �sszead�s elv�gz�se. Az eredm�ny MSb-je a kimeneti �tvitel bit.
wire [8:0] sum = operand1 + adder_op2 + carry_in;

//Kivon�s eset�n a kimen� �tvitel bitet neg�ljuk.
wire [8:0] arith_result = {sum[8] ^ arith_sel[1], sum[7:0]};

//A kettes komplemens t�lcsordul�s �szlel�se. T�lcsordul�s akkor t�rt�nik,
//ha azonos el�jel� sz�mokat adunk �ssze �s az �sszeg el�jele ett�l elt�r.
wire overflow = (~operand1[7] & ~adder_op2[7] &  arith_result[7]) |
                ( operand1[7] &  adder_op2[7] & ~arith_result[7]);


//******************************************************************************
//* A logikai m�veletek v�grehajt�sa (bitenk�nti �S, VAGY, XOR). Itt hajtjuk   *
//* v�gre az als� �s a fels� 4 bit felcser�l�s�t is.                           *
//******************************************************************************
reg [7:0] logic_result;

always @(*)
begin
   case (logic_sel)
      //Bitenk�nti �S
      LOGIC_AND: logic_result <= operand1 & operand2;
      //Bitenk�nti VAGY
      LOGIC_OR : logic_result <= operand1 | operand2;
      //Bitenk�nti XOR
      LOGIC_XOR: logic_result <= operand1 ^ operand2;
      //Az als� �s a fels� 4 bit felcser�l�se
      default  : logic_result <= {operand1[3:0], operand1[7:4]};
   endcase
end


//******************************************************************************
//* A shiftel�si �s a forgat�si m�veletek elv�gz�se.                           *
//******************************************************************************
reg [8:0] shift_result;

//Forgat�s eset�n a shift_sel[2] v�lasztja ki a bel�ptetend� bitet:
//0: sima forgat�s, a kil�p� bit ker�l bel�ptet�sre a m�sik oldalon
//1: forgat�s a carry flag-en kereszt�l
wire rot_in_l = (shift_sel[2]) ? flag_c : operand1[7];
wire rot_in_r = (shift_sel[2]) ? flag_c : operand1[0];

//A shift_sel[3] v�lasztja ki a shiftel�s t�pus�t:
//0: norm�l shiftel�s
//1: aritmetikai shiftel�s, az MSb (el�jel bit) helyben marad
wire shr_msb  = (shift_sel[3]) ? operand1[7] : shift_sel[2];

//A shiftel�s/forgat�s elv�gz�se. Az eredm�ny MSb-je a kimeneti �tvitel bit.
always @(*)
begin
   case (shift_sel[1:0])
      //Shiftel�s balra
      SHIFT_SHL: shift_result <= {operand1[7], operand1[6:0], shift_sel[2]};
      //Shiftel�s jobbra
      SHIFT_SHR: shift_result <= {operand1[0], shr_msb, operand1[7:1]};
      //Forgat�s balra
      SHIFT_ROL: shift_result <= {operand1[7], operand1[6:0], rot_in_l};
      //Forgat�s jobbra
      SHIFT_ROR: shift_result <= {operand1[0], rot_in_r, operand1[7:1]};
   endcase
end


//******************************************************************************
//* Az ALU eredm�nyt kiv�laszt� multiplexer.                                   *
//******************************************************************************
reg [8:0] alu_result;

always @(*)
begin
   case (op_type)
      ALU_MOVE : alu_result <= {1'b0, operand2};         //Adatmozgat�s
      ALU_ARITH: alu_result <= arith_result;             //Aritmetikai m�velet
      ALU_LOGIC: alu_result <= {1'b0, logic_result};     //Logikai m�velet
      ALU_SHIFT: alu_result <= shift_result;             //Shiftel�s/forgat�s
   endcase
end

//A multiplexer kimenet�nek als� 8 bitje az ALU eredm�ny, az MSb
//a carry flag �j �rt�k�t tartalmazza.
assign result = alu_result[7:0];


//******************************************************************************
//* Zero flag (Z).                                                             *
//*                                                                            *
//* Jelzi, ha az ALU m�velet eredm�nye 0. �rt�k�t friss�teni kell aritmetikai, *
//* logikai vagy shiftel�si/forgat�si m�veletek v�grehajt�sa eset�n. �rhat�nak *
//* kell lennie, mert megszak�t�sb�l val� visszat�r�sn�l vissza kell �ll�tani  *
//* a kor�bbi �rt�k�t.                                                         *
//******************************************************************************
always @(posedge clk)
begin
   if (flag_wr)
      flag_z <= flag_din[Z_FLAG];
   else begin
      if (op_type != ALU_MOVE)
      begin
         // Zero flag akkumulalasa SBC es CMY muveletek eseten
         if(arith_sel[1] & arith_sel[0])
            flag_z <= (flag_z) && (result == 8'd0);
         else
            flag_z <= (result == 8'd0);
      end
   end
end


//******************************************************************************
//* Carry flag (C).                                                            *
//*                                                                            *
//* Jelzi, ha az aritmetikai m�veletek sor�n �tvitel t�rt�nt, illetve felveszi *
//* a kishiftelt bit �rt�k�t shiftel�s/forgat�s v�grehajt�sa eset�n. �rhat�nak *
//* kell lennie, mert megszak�t�sb�l val� visszat�r�sn�l vissza kell �ll�tani  *
//* a kor�bbi �rt�k�t.                                                         *
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
//* Jelzi, ha az ALU m�velet eredm�nye negat�v (az el�jel bit 1). �rhat�nak    *
//* kell lennie, mert megszak�t�sb�l val� visszat�r�sn�l vissza kell �ll�tani  *
//* a kor�bbi �rt�k�t.                                                         *
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
//* Jelzi, ha kettes komplemens t�lcsordul�s t�rt�nt az aritmetikai m�veletek  *
//* v�grehajt�sa eset�n. �rhat�nak kell lennie, mert megszak�t�sb�l val�       *
//* visszat�r�sn�l vissza kell �ll�tani a kor�bbi �rt�k�t.                     *
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
