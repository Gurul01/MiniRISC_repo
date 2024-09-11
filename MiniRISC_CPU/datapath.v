`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* A mûveleteket végrehajtó adatstruktúra.                                    *
//******************************************************************************
module datapath(
   //Órajel.
   input  wire       clk,
   
   //Az adatmemóriával kapcsolatos jelek.
   output wire [7:0] data_mem_addr,    //Címbusz
   input  wire [7:0] data_mem_din,     //Olvasási adatbusz
   output wire [7:0] data_mem_dout,    //Írási adatbusz
   
   //Az utasításban lévõ konstans adat.
   input  wire [7:0] const_data,
   
   //A multiplexerek vezérlõ jelei.
   input  wire       wr_data_sel,      //A regiszterbe írandó adat kiválasztása
   input  wire       addr_op2_sel,     //Az ALU 2. operandusának kiválasztása
   
   //A regisztertömbbel kapcsolatos jelek.
   input  wire [3:0] reg_addr_x,       //Regiszter címe (X port)
   input  wire [3:0] reg_addr_y,       //Regiszter címe (Y port)
   input  wire       reg_wr_en,        //Írás engedélyezõ jel
   
   //Az ALU-val kapcsolatos jelek.
   input  wire [1:0] alu_op_type,      //ALU mûvelet kiválasztó jel
   input  wire [1:0] alu_arith_sel,    //Aritmetikai mûvelet kiválasztó jel
   input  wire [1:0] alu_logic_sel,    //Logikai mûvelet kiválasztó jel
   input  wire [3:0] alu_shift_sel,    //Shiftelési mûvelet kiválasztó jel
   input  wire [3:0] alu_flag_din,     //A flag-ekbe írandó érték
   input  wire       alu_flag_wr,      //A flag-ek írás engedélyezõ jele
   output wire       alu_flag_z,       //Zero flag
   output wire       alu_flag_c,       //Carry flag
   output wire       alu_flag_n,       //Negative flag
   output wire       alu_flag_v,       //Overflow flag
   
   //A programszámláló új értéke ugrás esetén.
   output wire [7:0] jump_address,
   
   //A debug interfész jelei.
   input  wire [7:0] dbg_addr_in,      //Cím bemenet
   input  wire [7:0] dbg_data_in,      //Adatbemenet
   input  wire       dbg_is_brk,       //A töréspont állapot jelzése
   output wire [7:0] dbg_reg_dout      //A regisztertömbbõl beolvasott adat
);

//******************************************************************************
//* A regiszterömbbe írandó adatot kiválasztó multiplexer.                     *
//******************************************************************************
wire [7:0] alu_result;                 //Az ALU mûvelet eredménye.
reg  [7:0] reg_wr_data;                //A regisztertömbbe írandó adat.

always @(*)
begin
   case ({dbg_is_brk, wr_data_sel})
      2'b00  : reg_wr_data <= alu_result;
      2'b01  : reg_wr_data <= data_mem_din;
      default: reg_wr_data <= dbg_data_in;
   endcase
end


//******************************************************************************
//* A regisztertömb.                                                           *
//******************************************************************************
wire [7:0] reg_rd_data_x;
wire [7:0] reg_rd_data_y;
wire [3:0] address_x = (dbg_is_brk) ? dbg_addr_in[3:0] : reg_addr_x;

reg_file reg_file(
   //Órajel.
   .clk(clk),
   
   //Az írási és az X olvasási port.
   .addr_x(address_x),                 //A regiszter címe
   .write_en(reg_wr_en),               //Írás engedélyezõ jel
   .wr_data_x(reg_wr_data),            //A regiszterbe írandó adat
   .rd_data_x(reg_rd_data_x),          //A regiszterben tárolt adat
   
   //Az Y olvasási port.
   .addr_y(reg_addr_y),                //A regiszter címe
   .rd_data_y(reg_rd_data_y)           //A regiszterben tárolt adat
);

//A memória írási adatbuszának meghajtása.
assign data_mem_dout = (dbg_is_brk) ? dbg_data_in : reg_rd_data_x;

//A regisztertömbbõl beolvasott adat a debug interfész felé.
assign dbg_reg_dout  = reg_rd_data_x;


//******************************************************************************
//* Az ALU 2. operandusát és a memóriacímet kiválasztó multiplexer.            *
//* -addr_op2_sel=0: konstans / abszolút címzés                                *
//* -addr_op2_sel=1: regiszter / indirekt címzés                               *
//******************************************************************************
wire [7:0] alu_operand2 = (addr_op2_sel) ? reg_rd_data_y : const_data;

//A memória címbuszának meghajtása.
assign data_mem_addr    = (dbg_is_brk)   ? dbg_addr_in   : alu_operand2;

//A programszámláló új értéke ugrás esetén.
assign jump_address     = alu_operand2;


//******************************************************************************
//* Az aritmetikai-logikai egység (ALU).                                       *
//******************************************************************************
alu alu(
   //Órajel.
   .clk(clk),
   
   //Vezérlõ bemenetek.
   .op_type(alu_op_type),              //Az ALU mûvelet típusát kiválasztó jel
   .arith_sel(alu_arith_sel),          //Az aritmetikai mûveletet kiválasztó jel
   .logic_sel(alu_logic_sel),          //A logikai mûveletet kiválasztó jel
   .shift_sel(alu_shift_sel),          //A shiftelési mûveletet kiválasztó jel
   
   //Az operandusok és az eredmény.
   .operand1(reg_rd_data_x),           //Elsõ operandus
   .operand2(alu_operand2),            //Második operandus
   .result(alu_result),                //Az ALU mûvelet eredménye
   
   //ALU feltétel jelek.
   .flag_din(alu_flag_din),            //A flag-ekbe írandó érték
   .flag_wr(alu_flag_wr),              //A flag-ek írás engedélyezõ jele
   .flag_z(alu_flag_z),                //Zero flag
   .flag_c(alu_flag_c),                //Carry flag
   .flag_n(alu_flag_n),                //Negative flag
   .flag_v(alu_flag_v)                 //Overflow flag
);

endmodule
