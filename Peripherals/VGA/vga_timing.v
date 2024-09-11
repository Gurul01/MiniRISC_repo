`timescale 1ns / 1ps

//******************************************************************************
//* 1024 x 768 @ 60 Hz VGA id�z�t�s gener�tor modul.                           *
//*                                                                            *
//* A 65 MHz pixel �rajel helyett 16 MHz pixel �rajelet haszn�lunk, ez�rt egy  *
//* "makropixel" 4 x 4 pixelnek felel meg a k�perny�n.                         *
//******************************************************************************
module vga_timing(
   //�rajel �s reset.
   input  wire       clk,              //�rajel
   input  wire       rst,              //Reset jel
   
   //Horizont�lis �s vertik�lis sz�ml�l�k.
   output reg  [8:0] h_cnt,            //Horizont�lis sz�ml�l�
   output reg  [9:0] v_cnt,            //Vertik�lis sz�ml�l�
   
   //Szinkron- �s kiolt�jelek. 
   output reg        h_blank,          //Horizont�lis kiolt�jel
   output reg        v_blank,          //Vertik�lis kiolt�jel
   output reg        v_blank_begin,    //A vertik�lis visszafut�s kezdete
   output reg        v_blank_end,      //A vertik�lis visszafut�s v�ge
   output reg        h_sync,           //Horizont�lis szinkronjel
   output reg        v_sync            //Vertik�lis szinkronjel
);

//******************************************************************************
//* Az id�z�t�si param�terek.                                                  *
//******************************************************************************
localparam H_VISIBLE     = 9'd256;
localparam H_FRONT_PORCH = 9'd6;
localparam H_SYNC_PULSE  = 9'd34;
localparam H_BACK_PORCH  = 9'd39;

localparam V_VISIBLE     = 10'd768;
localparam V_FRONT_PORCH = 10'd3;
localparam V_SYNC_PULSE  = 10'd6;
localparam V_BACK_PORCH  = 10'd28;

localparam H_BLANK_BEGIN = H_VISIBLE - 9'd1;
localparam H_SYNC_BEGIN  = H_VISIBLE + H_FRONT_PORCH - 9'd1;
localparam H_SYNC_END    = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE - 9'd1;
localparam H_BLANK_END   = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH - 9'd1;

localparam V_BLANK_BEGIN = V_VISIBLE - 10'd1;
localparam V_SYNC_BEGIN  = V_VISIBLE + V_FRONT_PORCH - 10'd1;
localparam V_SYNC_END    = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE - 10'd1;
localparam V_BLANK_END   = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH - 10'd1;


//******************************************************************************
//* A horizont�lis �s a vertik�lis sz�ml�l�.                                   *
//******************************************************************************
always @(posedge clk)
begin
   if (rst || (h_cnt == H_BLANK_END))
      h_cnt <= 9'd0;
   else
      h_cnt <= h_cnt + 9'd1;
end

always @(posedge clk)
begin
   if (rst)
      v_cnt <= 10'd0;
   else
      if (h_cnt == H_BLANK_END)
         if (v_cnt == V_BLANK_END)
            v_cnt <= 10'd0;
         else
            v_cnt <= v_cnt + 10'd1;
end


//******************************************************************************
//* A kiolt�jelek el��ll�t�sa.                                                 *
//******************************************************************************
always @(posedge clk)
begin
   if (rst || (h_cnt == H_BLANK_END))
      h_blank <= 1'b0;
   else
      if (h_cnt == H_BLANK_BEGIN)
         h_blank <= 1'b1;
end

always @(posedge clk)
begin
   if (rst)
      v_blank <= 1'b0;
   else
      if (h_cnt == H_BLANK_END)
         if (v_cnt == V_BLANK_BEGIN)
            v_blank <= 1'b1;
         else
            if (v_cnt == V_BLANK_END)
               v_blank <= 1'b0;
end


//******************************************************************************
//* A szinkronjelek el��ll�t�sa (mindegyik akt�v alacsony szint�).             *
//******************************************************************************
always @(posedge clk)
begin
   if (rst || (h_cnt == H_SYNC_END))
      h_sync <= 1'b1;
   else
      if (h_cnt == H_SYNC_BEGIN)
         h_sync <= 1'b0;
end

always @(posedge clk)
begin
   if (rst)
      v_sync <= 1'b1;
   else
      if (h_cnt == H_BLANK_END)
         if (v_cnt == V_SYNC_BEGIN)
            v_sync <= 1'b0;
         else
            if (v_cnt == V_SYNC_END)
               v_sync <= 1'b1;
end


//******************************************************************************
//* A vertik�lis visszafut�s kezdet�nek �s v�g�nek jelz�se.                    *
//******************************************************************************
always @(posedge clk)
begin
   v_blank_begin <= (h_cnt == H_BLANK_END) & (v_cnt == V_BLANK_BEGIN);
   v_blank_end   <= (h_cnt == H_BLANK_END) & (v_cnt == V_BLANK_END);
end


endmodule
