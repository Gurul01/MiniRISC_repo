`timescale 1ns / 1ps

//******************************************************************************
//* PS/2 vevõ modul.                                                           *
//******************************************************************************
module ps2_receiver(
   //Órajel és reset.
   input  wire       clk,              //Órajel
   input  wire       rst,              //Reset jel
   
   //A PS/2 interfész jelei.
   input  wire       ps2_clk,          //Órajel bemenet
   input  wire       ps2_data,         //Soros adatbemenet
   
   //A vételt engedélyezõ jel.
   input  wire       rx_enable,
   
   //Párhuzamos adatkimenet.
   output reg  [7:0] data_out,         //A vett adat
   output reg        data_valid        //Érvényes adat jelzése
);

//******************************************************************************
//* Az 1 MHz-es engedélyezõ jel elõállítása a PS/2 jelek mintavételezéséhez.   *
//******************************************************************************
reg  [3:0] clk_divider;
wire       clk_divider_tc = (clk_divider == 4'd15);

always @(posedge clk)
begin
   clk_divider <= clk_divider + 4'd1;
end


//******************************************************************************
//* A PS/2 interfész jelek mintavételezése és éldetektálás az órajelen.        *
//******************************************************************************
reg  [1:0] ps2_data_samples;
reg  [2:0] ps2_clk_samples;
wire       ps2_clk_falling = (ps2_clk_samples[2:1] == 2'b10) & clk_divider_tc;

always @(posedge clk)
begin
   if (clk_divider_tc)
      ps2_clk_samples <= {ps2_clk_samples[1:0], ps2_clk};
end

always @(posedge clk)
begin
   if (clk_divider_tc)
      ps2_data_samples <= {ps2_data_samples[0], ps2_data};
end


//******************************************************************************
//* Shiftregiszter a soros/párhuzamos átalakításhoz. A PS/2 keret felépítése:  *
//* START bit (0) | 8 adatbit | Pritásbit (páratlan) | STOP bit (1)            *
//******************************************************************************
reg  [10:0] rx_shr;
//A shiftregiszter alapállapotba állító jele:
// - rendszer reset vagy
// - a vétel nincs engedélyezve vagy
// - a START bit 0
wire        rx_shr_rst = rst | ~rx_enable | ~rx_shr[0];

//A vételi shiftregiszter. A léptetés a PS/2 órajel lefutó élére történik.
always @(posedge clk)
begin
   if (rx_shr_rst)
      rx_shr <= 11'b111_1111_1111;
   else
      if (ps2_clk_falling)
         rx_shr <= {ps2_data_samples[1], rx_shr[10:1]};
end

//A párhuzamos adatkimenet meghajtása.
always @(posedge clk)
begin
   data_out <= rx_shr[8:1];
end

//Az érvényes adat jelzése:
// - a START bit 0 és
// - érvényes páratlan paritás és
// - a STOP bit 1
always @(posedge clk)
begin
   if (rst)
      data_valid <= 1'b0;
   else
      data_valid <= ~rx_shr[0] & ^rx_shr[9:1] & rx_shr[10];
end


endmodule
