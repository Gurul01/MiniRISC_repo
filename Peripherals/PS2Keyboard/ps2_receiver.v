`timescale 1ns / 1ps

//******************************************************************************
//* PS/2 vev� modul.                                                           *
//******************************************************************************
module ps2_receiver(
   //�rajel �s reset.
   input  wire       clk,              //�rajel
   input  wire       rst,              //Reset jel
   
   //A PS/2 interf�sz jelei.
   input  wire       ps2_clk,          //�rajel bemenet
   input  wire       ps2_data,         //Soros adatbemenet
   
   //A v�telt enged�lyez� jel.
   input  wire       rx_enable,
   
   //P�rhuzamos adatkimenet.
   output reg  [7:0] data_out,         //A vett adat
   output reg        data_valid        //�rv�nyes adat jelz�se
);

//******************************************************************************
//* Az 1 MHz-es enged�lyez� jel el��ll�t�sa a PS/2 jelek mintav�telez�s�hez.   *
//******************************************************************************
reg  [3:0] clk_divider;
wire       clk_divider_tc = (clk_divider == 4'd15);

always @(posedge clk)
begin
   clk_divider <= clk_divider + 4'd1;
end


//******************************************************************************
//* A PS/2 interf�sz jelek mintav�telez�se �s �ldetekt�l�s az �rajelen.        *
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
//* Shiftregiszter a soros/p�rhuzamos �talak�t�shoz. A PS/2 keret fel�p�t�se:  *
//* START bit (0) | 8 adatbit | Prit�sbit (p�ratlan) | STOP bit (1)            *
//******************************************************************************
reg  [10:0] rx_shr;
//A shiftregiszter alap�llapotba �ll�t� jele:
// - rendszer reset vagy
// - a v�tel nincs enged�lyezve vagy
// - a START bit 0
wire        rx_shr_rst = rst | ~rx_enable | ~rx_shr[0];

//A v�teli shiftregiszter. A l�ptet�s a PS/2 �rajel lefut� �l�re t�rt�nik.
always @(posedge clk)
begin
   if (rx_shr_rst)
      rx_shr <= 11'b111_1111_1111;
   else
      if (ps2_clk_falling)
         rx_shr <= {ps2_data_samples[1], rx_shr[10:1]};
end

//A p�rhuzamos adatkimenet meghajt�sa.
always @(posedge clk)
begin
   data_out <= rx_shr[8:1];
end

//Az �rv�nyes adat jelz�se:
// - a START bit 0 �s
// - �rv�nyes p�ratlan parit�s �s
// - a STOP bit 1
always @(posedge clk)
begin
   if (rst)
      data_valid <= 1'b0;
   else
      data_valid <= ~rx_shr[0] & ^rx_shr[9:1] & rx_shr[10];
end


endmodule
