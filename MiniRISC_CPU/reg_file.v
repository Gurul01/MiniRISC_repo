`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* 16 x 8 bites regisztert�mb egy �r�si �s k�t olvas�si porttal. Az �r�si     *
//* port �s az X olvas�si port c�m bemenete azonos. A megval�s�t�s elosztott   *
//* mem�ri�t haszn�l.                                                          *
//******************************************************************************
module reg_file(
   //�rajel.
   input  wire       clk,
   input  wire       rst,
   
   //Az �r�si �s az X olvas�si port.
   input  wire [3:0] addr_x,        //A regiszter c�me
   input  wire       write_en,      //�r�s enged�lyez� jel
   input  wire [7:0] wr_data_x,     //A regiszterbe �rand� adat
   output wire [7:0] rd_data_x,     //A regiszterben t�rolt adat
   
   //Az Y olvas�si port.
   input  wire [3:0] addr_y,        //A regiszter c�me
   output wire [7:0] rd_data_y,     //A regiszterben t�rolt adat

   output wire [7:0] SP
);

`include "src\MiniRISC_CPU\control_defs.vh"

//******************************************************************************
//* A 16 x 8 bites elosztott RAM deklar�l�sa.                                  *
//******************************************************************************
(* ram_style = "distributed" *)
reg [7:0] reg_file_ram [15:0];


//******************************************************************************
//* Az �r�si port megval�s�t�sa. Az �r�s szinkron m�don t�rt�nik.              *
//******************************************************************************
always @(posedge clk)
begin
   if(rst)
      reg_file_ram[SP_address] = 8'd127;

   if (write_en)
      reg_file_ram[addr_x] <= wr_data_x;
end


//******************************************************************************
//* Az X olvas�si port megval�s�t�sa. Az olvas�s aszinkron m�don t�rt�nik.     *
//******************************************************************************
assign rd_data_x = reg_file_ram[addr_x];


//******************************************************************************
//* Az Y olvas�si port megval�s�t�sa. Az olvas�s aszinkron m�don t�rt�nik.     *
//******************************************************************************
assign rd_data_y = reg_file_ram[addr_y];


//******************************************************************************
//* Az SP regiszter erteket folyamatosan elerhetove kell tenni.                *
//* Az olvas�s aszinkron m�don t�rt�nik.                                       *
//******************************************************************************
assign SP = reg_file_ram[SP_address];


endmodule
