`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* 16 x 8 bites regisztertömb egy írási és két olvasási porttal. Az írási     *
//* port és az X olvasási port cím bemenete azonos. A megvalósítás elosztott   *
//* memóriát használ.                                                          *
//******************************************************************************
module reg_file(
   //Órajel.
   input  wire       clk,
   
   //Az írási és az X olvasási port.
   input  wire [3:0] addr_x,        //A regiszter címe
   input  wire       write_en,      //Írás engedélyezõ jel
   input  wire [7:0] wr_data_x,     //A regiszterbe írandó adat
   output wire [7:0] rd_data_x,     //A regiszterben tárolt adat
   
   //Az Y olvasási port.
   input  wire [3:0] addr_y,        //A regiszter címe
   output wire [7:0] rd_data_y      //A regiszterben tárolt adat
);

//******************************************************************************
//* A 16 x 8 bites elosztott RAM deklarálása.                                  *
//******************************************************************************
(* ram_style = "distributed" *)
reg [7:0] reg_file_ram [15:0];


//******************************************************************************
//* Az írási port megvalósítása. Az írás szinkron módon történik.              *
//******************************************************************************
always @(posedge clk)
begin
   if (write_en)
      reg_file_ram[addr_x] <= wr_data_x;
end


//******************************************************************************
//* Az X olvasási port megvalósítása. Az olvasás aszinkron módon történik.     *
//******************************************************************************
assign rd_data_x = reg_file_ram[addr_x];


//******************************************************************************
//* Az Y olvasási port megvalósítása. Az olvasás aszinkron módon történik.     *
//******************************************************************************
assign rd_data_y = reg_file_ram[addr_y];


endmodule
