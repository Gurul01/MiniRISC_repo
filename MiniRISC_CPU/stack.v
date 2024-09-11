`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* 16 sz� m�lys�g� HW verem a programsz�ml�l� �s az ALU flag-ek elment�s�hez  *
//* szubrutinh�v�s, illetve megszak�t�sk�r�s eset�n. A megval�s�t�s elosztott  *
//* mem�ri�t haszn�l.                                                          *
//******************************************************************************
module stack #(
   //Az adat sz�less�ge bitekben.
   parameter DATA_WIDTH = 8
) (
   //�rajel.
   input  wire                  clk,
   
   //Adatvonalak.
   input  wire [DATA_WIDTH-1:0] data_in,     //A verembe �rand� adat
   output wire [DATA_WIDTH-1:0] data_out,    //A verem tetej�n l�v� adat
   
   //Vez�rl� bemenetek.
   input  wire                  push,        //Adat �r�sa a verembe
   input  wire                  pop          //Adat olvas�sa a veremb�l
);

//******************************************************************************
//* �r�si c�msz�ml�l�. PUSH m�velet eset�n az �rt�k�t n�velj�k, POP m�velet    *
//* eset�n az �rt�k�t cs�kkentj�k.                                             *
//******************************************************************************
reg [3:0] wr_address;

always @(posedge clk)
begin
   if (push)
      wr_address <= wr_address + 4'd1;
   else
      if (pop)
         wr_address <= wr_address - 4'd1;
end


//******************************************************************************
//* Az �r�si c�mb�l egyet kivonva megkapjuk az olvas�si c�met.                 *
//******************************************************************************
wire [3:0] rd_address = wr_address - 4'd1;


//******************************************************************************
//* A 16 x DATA_WIDTH bites elosztott RAM. PUSH m�velet eset�n be�rjuk az      *
//* adatot a mem�ri�ba.                                                        *
//******************************************************************************
(* ram_style = "distributed" *)
reg [DATA_WIDTH-1:0] stack_ram [15:0];

always @(posedge clk)
begin
   if (push)
      stack_ram[wr_address] <= data_in;
end

assign data_out = stack_ram[rd_address];


endmodule
