`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* A m�veleteket v�grehajt� adatstrukt�ra.                                    *
//******************************************************************************
module datapath(
   //�rajel.
   input  wire       clk,
   input  wire       rst,
   
   //Az adatmem�ri�val kapcsolatos jelek.
   output wire [7:0] data_mem_addr,    //C�mbusz
   input  wire [7:0] data_mem_din,     //Olvas�si adatbusz
   output wire [7:0] data_mem_dout,    //�r�si adatbusz
   
   //Az utas�t�sban l�v� konstans adat.
   input  wire [7:0] const_data,
   
   //A multiplexerek vez�rl� jelei.
   input  wire       wr_data_sel,      //A regiszterbe �rand� adat kiv�laszt�sa
   input  wire       addr_op2_sel,     //Az ALU 2. operandus�nak kiv�laszt�sa
   
   //A regisztert�mbbel kapcsolatos jelek.
   input  wire [3:0] reg_addr_x,       //Regiszter c�me (X port)
   input  wire [3:0] reg_addr_y,       //Regiszter c�me (Y port)
   input  wire       reg_wr_en,        //�r�s enged�lyez� jel
   
   //Az ALU-val kapcsolatos jelek.
   input  wire [1:0] alu_op_type,      //ALU m�velet kiv�laszt� jel
   input  wire [1:0] alu_arith_sel,    //Aritmetikai m�velet kiv�laszt� jel
   input  wire [1:0] alu_logic_sel,    //Logikai m�velet kiv�laszt� jel
   input  wire [3:0] alu_shift_sel,    //Shiftel�si m�velet kiv�laszt� jel
   input  wire [3:0] alu_flag_din,     //A flag-ekbe �rand� �rt�k
   input  wire       alu_flag_wr,      //A flag-ek �r�s enged�lyez� jele
   output wire       alu_flag_z,       //Zero flag
   output wire       alu_flag_c,       //Carry flag
   output wire       alu_flag_n,       //Negative flag
   output wire       alu_flag_v,       //Overflow flag
   
   //A programsz�ml�l� �j �rt�ke ugr�s eset�n.
   output wire [7:0] jump_address,

   output wire [7:0] SP,
   
   //A debug interf�sz jelei.
   input  wire [7:0] dbg_addr_in,      //C�m bemenet
   input  wire [7:0] dbg_data_in,      //Adatbemenet
   input  wire       dbg_is_brk,       //A t�r�spont �llapot jelz�se
   output wire [7:0] dbg_reg_dout      //A regisztert�mbb�l beolvasott adat
);

//******************************************************************************
//* A regiszter�mbbe �rand� adatot kiv�laszt� multiplexer.                     *
//******************************************************************************
wire [7:0] alu_result;                 //Az ALU m�velet eredm�nye.
reg  [7:0] reg_wr_data;                //A regisztert�mbbe �rand� adat.

always @(*)
begin
   case ({dbg_is_brk, wr_data_sel})
      2'b00  : reg_wr_data <= alu_result;
      2'b01  : reg_wr_data <= data_mem_din;
      default: reg_wr_data <= dbg_data_in;
   endcase
end


//******************************************************************************
//* A regisztert�mb.                                                           *
//******************************************************************************
wire [7:0] reg_rd_data_x;
wire [7:0] reg_rd_data_y;
wire [3:0] address_x = (dbg_is_brk) ? dbg_addr_in[3:0] : reg_addr_x;

reg_file reg_file(
   //�rajel.
   .clk(clk),
   .rst(rst),
   
   //Az �r�si �s az X olvas�si port.
   .addr_x(address_x),                 //A regiszter c�me
   .write_en(reg_wr_en),               //�r�s enged�lyez� jel
   .wr_data_x(reg_wr_data),            //A regiszterbe �rand� adat
   .rd_data_x(reg_rd_data_x),          //A regiszterben t�rolt adat
   
   //Az Y olvas�si port.
   .addr_y(reg_addr_y),                //A regiszter c�me
   .rd_data_y(reg_rd_data_y),           //A regiszterben t�rolt adat

   //SP olvasasa mindig elerheto
   .SP(SP)
);

//A mem�ria �r�si adatbusz�nak meghajt�sa.
assign data_mem_dout = (dbg_is_brk) ? dbg_data_in : reg_rd_data_x;

//A regisztert�mbb�l beolvasott adat a debug interf�sz fel�.
assign dbg_reg_dout  = reg_rd_data_x;


//******************************************************************************
//* Az ALU 2. operandus�t �s a mem�riac�met kiv�laszt� multiplexer.            *
//* -addr_op2_sel=0: konstans / abszol�t c�mz�s                                *
//* -addr_op2_sel=1: regiszter / indirekt c�mz�s                               *
//******************************************************************************
wire [7:0] alu_operand2 = (addr_op2_sel) ? reg_rd_data_y : const_data;

//A mem�ria c�mbusz�nak meghajt�sa.
assign data_mem_addr    = (dbg_is_brk)   ? dbg_addr_in   : alu_operand2;

//A programsz�ml�l� �j �rt�ke ugr�s eset�n.
assign jump_address     = alu_operand2;


//******************************************************************************
//* Az aritmetikai-logikai egys�g (ALU).                                       *
//******************************************************************************
alu alu(
   //�rajel.
   .clk(clk),
   
   //Vez�rl� bemenetek.
   .op_type(alu_op_type),              //Az ALU m�velet t�pus�t kiv�laszt� jel
   .arith_sel(alu_arith_sel),          //Az aritmetikai m�veletet kiv�laszt� jel
   .logic_sel(alu_logic_sel),          //A logikai m�veletet kiv�laszt� jel
   .shift_sel(alu_shift_sel),          //A shiftel�si m�veletet kiv�laszt� jel
   
   //Az operandusok �s az eredm�ny.
   .operand1(reg_rd_data_x),           //Els� operandus
   .operand2(alu_operand2),            //M�sodik operandus
   .result(alu_result),                //Az ALU m�velet eredm�nye
   
   //ALU felt�tel jelek.
   .flag_din(alu_flag_din),            //A flag-ekbe �rand� �rt�k
   .flag_wr(alu_flag_wr),              //A flag-ek �r�s enged�lyez� jele
   .flag_z(alu_flag_z),                //Zero flag
   .flag_c(alu_flag_c),                //Carry flag
   .flag_n(alu_flag_n),                //Negative flag
   .flag_v(alu_flag_v)                 //Overflow flag
);

endmodule
