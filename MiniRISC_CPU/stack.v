`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* 16 szó mélységû HW verem a programszámláló és az ALU flag-ek elmentéséhez  *
//* szubrutinhívás, illetve megszakításkérés esetén. A megvalósítás elosztott  *
//* memóriát használ.                                                          *
//******************************************************************************
module stack #(
   //Az adat szélessége bitekben.
   parameter DATA_WIDTH = 8
) (
   //Órajel.
   input  wire                  clk,
   
   //Adatvonalak.
   input  wire [DATA_WIDTH-1:0] data_in,     //A verembe írandó adat
   output wire [DATA_WIDTH-1:0] data_out,    //A verem tetején lévõ adat
   
   //Vezérlõ bemenetek.
   input  wire                  push,        //Adat írása a verembe
   input  wire                  pop          //Adat olvasása a verembõl
);

//******************************************************************************
//* Írási címszámláló. PUSH mûvelet esetén az értékét növeljük, POP mûvelet    *
//* esetén az értékét csökkentjük.                                             *
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
//* Az írási címbõl egyet kivonva megkapjuk az olvasási címet.                 *
//******************************************************************************
wire [3:0] rd_address = wr_address - 4'd1;


//******************************************************************************
//* A 16 x DATA_WIDTH bites elosztott RAM. PUSH mûvelet esetén beírjuk az      *
//* adatot a memóriába.                                                        *
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
