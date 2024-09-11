`timescale 1ns / 1ps

//******************************************************************************
//* Egyszerû busz arbiter 2 master egységhez.                                  *
//*                                                                            *
//* A busz hozzáférés megadása fix prioritású ütemezés szerint történik,       *
//* az MST0 rendelkezik a nagyobb prioritással. Több master egység egyidejû    *
//* kérése esetén a nagyobb prioritású kapja meg a buszt. A busz hozzáféréssel *
//* nem rendelkezõ master egységeknek inaktív nulla értékkel kell meghajtaniuk *
//* a kimeneteiket.                                                            *
//*                                                                            *
//*                   ------        ------        ------        ------         *
//* CLK              |      |      |      |      |      |      |      |        *
//*               ---        ------        ------        ------        ---     *
//*                                                                            *
//* Prioritás           MASTER 0   |   MASTER 0  |   MASTER 0  |  MASTER 0     *
//*                                                                            *
//*                                  -------------                             *
//* MST0_REQ                        /             \                            *
//*               ------------------               -----------------------     *
//*                   ------------------------------------------               *
//* MST1_REQ         /                                          \              *
//*               ---                                            ---------     *
//*                                   --------------                           *
//* MST0_GRANT                       /              \                          *
//*               -------------------                ---------------------     *
//*                    --------------                -------------             *
//* MST1_GRANT        /              \              /             \            *
//*               ----                --------------               -------     *
//*                                                                            *
//*                    -------------- -------------- --------------            *
//* MST2SLV_WR        /  MST1 RD/WR  X  MST0 RD/WR  X  MST1 RD/WR  \           *
//* MST2SLV_RD    ------------------- -------------- --------------------      *
//*               ---- -------------- -------------- -------------- -----      *
//* MST2SLV_ADDR   0  X   MST1 CÍM   X   MST0 CÍM   X   MST1 CÍM   X   0       *
//*               ---- -------------- ---- ------------------------ -----      *
//*               ---- -------------- -------------- -------------- -----      *
//* MST2SLV_DATA   0  X   MST1 ADAT  X   MST0 ADAT  X   MST1 ADAT  X   0       *
//* SLV2MST_DATA  ---- -------------- -------------- -------------- -----      *
//*                                 ^              ^              ^            *
//*                    Az írási vagy olvasási parancsok itt hajtódnak végre.   *
//******************************************************************************
module bus_arbiter_2m_fixed(
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
//A prioritás dekóder kimenete.
reg [1:0] grant;

//A prioritás dekóder bemenete.
wire [2:0] decoder_in = {mst1_req, mst0_req};

always @(*)                       //a buszt kéri    prioritása      a buszt
begin                             //MST0    MST1        van         megkapja
   case (decoder_in)              //------------------------------------------
      2'b00: grant <= 2'b00;      //nem     nem      MST0-nak   ->  egyik sem
      2'b01: grant <= 2'b01;      //igen    nem      MST0-nak   ->    MST0 
      2'b10: grant <= 2'b10;      //nem     igen     MST0-nak   ->    MST1 
      2'b11: grant <= 2'b01;      //igen    igen     MST0-nak   ->    MST0
   endcase
end

//A busz hozzáférés megadás jelek meghajtása.
assign mst0_grant = grant[0];
assign mst1_grant = grant[1];

endmodule
