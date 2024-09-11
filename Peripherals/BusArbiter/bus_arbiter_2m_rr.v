`timescale 1ns / 1ps

//******************************************************************************
//* Egyszerû busz arbiter 2 master egységhez.                                  *
//*                                                                            *
//* A busz hozzáférés megadása round-robin (körforgásos) ütemezés szerint      *
//* történik, azaz minden hozzáférés után a következõ master egységnek lesz    *
//* nagyobb priorítása. Több master egység egyidejû kérése esetén a nagyobb    *
//* priorítású kapja meg a buszt. A busz hozzáféréssel nem rendelkezõ master   *
//* egységeknek inaktív nulla értékkel kell meghajtaniuk a kimeneteiket.       *
//*                                                                            *
//*                   ------        ------        ------        ------         *
//* CLK              |      |      |      |      |      |      |      |        *
//*               ---        ------        ------        ------        ---     *
//*                                                                            *
//* Prioritás           MASTER 0   |   MASTER 1  |   MASTER 0  |  MASTER 1     *
//*                                                                            *
//*                   ------------------------------------------               *
//* MST0_REQ         /                                          \              *
//*               ---                                            ---------     *
//*                                  -------------                             *
//* MST1_REQ                        /             \                            *
//*               ------------------               -----------------------     *
//*                    --------------                -------------             *
//* MST0_GRANT        /              \              /             \            *
//*               ----                --------------               -------     *
//*                                   --------------                           *
//* MST1_GRANT                       /              \                          *
//*               -------------------                ---------------------     *
//*                                                                            *
//*                    -------------- -------------- --------------            *
//* MST2SLV_WR        /  MST0 RD/WR  X  MST1 RD/WR  X  MST0 RD/WR  \           *
//* MST2SLV_RD    ------------------- -------------- --------------------      *
//*               ---- -------------- -------------- -------------- -----      *
//* MST2SLV_ADDR   0  X   MST0 CÍM   X   MST1 CÍM   X   MST0 CÍM   X   0       *
//*               ---- -------------- ---- ------------------------ -----      *
//*               ---- -------------- -------------- -------------- -----      *
//* MST2SLV_DATA   0  X   MST0 ADAT  X   MST1 ADAT  X   MST0 ADAT  X   0       *
//* SLV2MST_DATA  ---- -------------- -------------- -------------- -----      *
//*                                 ^              ^              ^            *
//*                    Az írási vagy olvasási parancsok itt hajtódnak végre.   *
//******************************************************************************
module bus_arbiter_2m_rr(
   //Órajel és reset.
   input  wire clk,              //Órajel
   input  wire rst,              //Reset jel
   
   //A master 0 egységhez tartozó jelek.
   input  wire mst0_req,         //Busz hozzáférés kérése
   output wire mst0_grant,       //Busz hozzáférés megadása
   
   //A master 1 egységhez tartozó jelek.
   input  wire mst1_req,         //Busz hozzáférés kérése
   output wire mst1_grant        //Busz hozzáférés megadása
);

//******************************************************************************
//* Prioritás dekóder.                                                         *
//******************************************************************************
//A prioritást kiválasztó jel:
//0: a master 0 egységnek van nagyobb prioritása
//1: a master 1 egységnek van nagyobb prioritása
reg priority_sel;

//A prioritás dekóder kimenete.
reg [1:0] grant;

//A prioritás dekóder bemenete.
wire [2:0] decoder_in = {priority_sel, mst1_req, mst0_req};

always @(*)                        //a buszt kéri    prioritása      a buszt
begin                              //MST0    MST1        van         megkapja
   case (decoder_in)               //------------------------------------------
      3'b000: grant <= 2'b00;      //nem     nem      MST0-nak   ->  egyik sem
      3'b001: grant <= 2'b01;      //igen    nem      MST0-nak   ->    MST0 
      3'b010: grant <= 2'b10;      //nem     igen     MST0-nak   ->    MST1 
      3'b011: grant <= 2'b01;      //igen    igen     MST0-nak   ->    MST0
      3'b100: grant <= 2'b00;      //nem     nem      MST1-nek   ->  egyik sem      
      3'b101: grant <= 2'b01;      //igen    nem      MST1-nek   ->    MST0 
      3'b110: grant <= 2'b10;      //nem     igen     MST1-nek   ->    MST1 
      3'b111: grant <= 2'b10;      //igen    igen     MST1-nek   ->    MST1 
   endcase
end

//A busz hozzáférés megadás jelek meghajtása.
assign mst0_grant = grant[0];
assign mst1_grant = grant[1];


//******************************************************************************
//* A round-robin (körforgásos) ütemezés megvalósítása: minden busz hozzáférés *
//* után a következõ master egységnek lesz nagyobb prioritása.                 *
//******************************************************************************
always @(posedge clk)
begin
   if (rst)
      priority_sel <= 1'b0;
   else
      if (grant != 0)
         priority_sel <= ~priority_sel;
end

endmodule
