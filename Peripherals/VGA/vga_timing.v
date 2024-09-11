`timescale 1ns / 1ps

//******************************************************************************
//* 1024 x 768 @ 60 Hz VGA idõzítés generátor modul.                           *
//*                                                                            *
//* A 65 MHz pixel órajel helyett 16 MHz pixel órajelet használunk, ezért egy  *
//* "makropixel" 4 x 4 pixelnek felel meg a képernyõn.                         *
//******************************************************************************
module vga_timing(
   //Órajel és reset.
   input  wire       clk,              //Órajel
   input  wire       rst,              //Reset jel
   
   //Horizontális és vertikális számlálók.
   output reg  [8:0] h_cnt,            //Horizontális számláló
   output reg  [9:0] v_cnt,            //Vertikális számláló
   
   //Szinkron- és kioltójelek. 
   output reg        h_blank,          //Horizontális kioltójel
   output reg        v_blank,          //Vertikális kioltójel
   output reg        v_blank_begin,    //A vertikális visszafutás kezdete
   output reg        v_blank_end,      //A vertikális visszafutás vége
   output reg        h_sync,           //Horizontális szinkronjel
   output reg        v_sync            //Vertikális szinkronjel
);

//******************************************************************************
//* Az idõzítési paraméterek.                                                  *
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
//* A horizontális és a vertikális számláló.                                   *
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
//* A kioltójelek elõállítása.                                                 *
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
//* A szinkronjelek elõállítása (mindegyik aktív alacsony szintû).             *
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
//* A vertikális visszafutás kezdetének és végének jelzése.                    *
//******************************************************************************
always @(posedge clk)
begin
   v_blank_begin <= (h_cnt == H_BLANK_END) & (v_cnt == V_BLANK_BEGIN);
   v_blank_end   <= (h_cnt == H_BLANK_END) & (v_cnt == V_BLANK_END);
end


endmodule
