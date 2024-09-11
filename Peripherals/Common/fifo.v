`timescale 1ns / 1ps

//******************************************************************************
//* 16 x N bites FIFO. Az elsõ beírt szó azonnal megjelenik a kimeneten, nincs *
//* szükség az elsõ olvasás elõtt a read jel aktiválására.                     *
//******************************************************************************  
module fifo #(
   //A szószélesség bitekben.
   parameter WIDTH = 8
) (
   //Órajel és reset.
   input  wire             clk,        //Órajel
   input  wire             rst,        //Reset jel
   
   //Adatvonalak.
   input  wire [WIDTH-1:0] data_in,    //A FIFO-ba írandó adat
   output wire [WIDTH-1:0] data_out,   //A FIFO-ból kiolvasott adat
   
   //Vezérlõ bemenetek.
   input  wire             write,      //Írás engedélyezõ jel
   input  wire             read,       //Olvasás engedélyezõ jel
   
   //Státusz kimenetek.
   output reg              empty,      //A FIFO üres
   output reg              full        //A FIFO tele van
);


//******************************************************************************
//* 16 x 8 bites dinamikus shiftregiszter.                                     *
//******************************************************************************    
reg  [15:0] fifo_shr [WIDTH-1:0];
reg  [3:0]  read_address;
wire        fifo_shr_en = write & (~full | read);

genvar i;   

generate
   for (i = 0; i < WIDTH; i = i + 1)
   begin : shr_loop
      always @(posedge clk)
         if (fifo_shr_en)
            fifo_shr[i] <= {fifo_shr[i][14:0], data_in[i]};
      
      assign data_out[i] = fifo_shr[i][read_address];
   end
endgenerate


//******************************************************************************
//* A dinamikus shiftregiszter olvasási címszámlálója.                         *
//******************************************************************************
wire read_address_min = (read_address == 4'b0000);
wire read_address_max = (read_address == 4'b1111);
wire read_address_inc = ~read_address_max &  write & ~read & ~empty;
wire read_address_dec = ~read_address_min & ~write &  read;
  
always @(posedge clk)
begin
   if (rst)
      read_address <= 0;
   else
      if (read_address_inc)
         read_address <= read_address + 4'd1;
      else
         if (read_address_dec)
            read_address <= read_address - 4'd1;
end 


//******************************************************************************
//* A FIFO üres állapotának jelzése.                                           *
//******************************************************************************
wire empty_set = read_address_min & read & ~write;
wire empty_clr = write & ~read;

always @(posedge clk)
begin
   if (rst || empty_set)
      empty <= 1'b1;
   else
      if (empty_clr)
         empty <= 1'b0;
end


//******************************************************************************
//* A FIFO tele állapotának jelzése.                                           *
//******************************************************************************
wire full_set = (read_address == 4'b1110) & write & ~read;
wire full_clr = ~write & read;

always @(posedge clk)
begin
   if (rst || full_clr)
      full <= 1'b0;
   else
      if (full_set)
         full <= 1'b1;
end


endmodule
