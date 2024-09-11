`timescale 1ns / 1ps

//******************************************************************************
//* 16 x N bites FIFO. Az els� be�rt sz� azonnal megjelenik a kimeneten, nincs *
//* sz�ks�g az els� olvas�s el�tt a read jel aktiv�l�s�ra.                     *
//******************************************************************************  
module fifo #(
   //A sz�sz�less�g bitekben.
   parameter WIDTH = 8
) (
   //�rajel �s reset.
   input  wire             clk,        //�rajel
   input  wire             rst,        //Reset jel
   
   //Adatvonalak.
   input  wire [WIDTH-1:0] data_in,    //A FIFO-ba �rand� adat
   output wire [WIDTH-1:0] data_out,   //A FIFO-b�l kiolvasott adat
   
   //Vez�rl� bemenetek.
   input  wire             write,      //�r�s enged�lyez� jel
   input  wire             read,       //Olvas�s enged�lyez� jel
   
   //St�tusz kimenetek.
   output reg              empty,      //A FIFO �res
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
//* A dinamikus shiftregiszter olvas�si c�msz�ml�l�ja.                         *
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
//* A FIFO �res �llapot�nak jelz�se.                                           *
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
//* A FIFO tele �llapot�nak jelz�se.                                           *
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
