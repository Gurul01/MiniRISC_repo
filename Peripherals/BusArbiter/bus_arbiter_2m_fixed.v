`timescale 1ns / 1ps

//******************************************************************************
//* Egyszer� busz arbiter 2 master egys�ghez.                                  *
//*                                                                            *
//* A busz hozz�f�r�s megad�sa fix priorit�s� �temez�s szerint t�rt�nik,       *
//* az MST0 rendelkezik a nagyobb priorit�ssal. T�bb master egys�g egyidej�    *
//* k�r�se eset�n a nagyobb priorit�s� kapja meg a buszt. A busz hozz�f�r�ssel *
//* nem rendelkez� master egys�geknek inakt�v nulla �rt�kkel kell meghajtaniuk *
//* a kimeneteiket.                                                            *
//*                                                                            *
//*                   ------        ------        ------        ------         *
//* CLK              |      |      |      |      |      |      |      |        *
//*               ---        ------        ------        ------        ---     *
//*                                                                            *
//* Priorit�s           MASTER 0   |   MASTER 0  |   MASTER 0  |  MASTER 0     *
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
//* MST2SLV_ADDR   0  X   MST1 C�M   X   MST0 C�M   X   MST1 C�M   X   0       *
//*               ---- -------------- ---- ------------------------ -----      *
//*               ---- -------------- -------------- -------------- -----      *
//* MST2SLV_DATA   0  X   MST1 ADAT  X   MST0 ADAT  X   MST1 ADAT  X   0       *
//* SLV2MST_DATA  ---- -------------- -------------- -------------- -----      *
//*                                 ^              ^              ^            *
//*                    Az �r�si vagy olvas�si parancsok itt hajt�dnak v�gre.   *
//******************************************************************************
module bus_arbiter_2m_fixed(
   //A master 0 egys�ghez tartoz� jelek.
   input  wire mst0_req,         //Busz hozz�f�r�s k�r�se
   output wire mst0_grant,       //Busz hozz�f�r�s megad�sa
   
   //A master 1 egys�ghez tartoz� jelek.
   input  wire mst1_req,         //Busz hozz�f�r�s k�r�se
   output wire mst1_grant        //Busz hozz�f�r�s megad�sa
);

//******************************************************************************
//* Priorit�s dek�der.                                                         *
//******************************************************************************
//A priorit�s dek�der kimenete.
reg [1:0] grant;

//A priorit�s dek�der bemenete.
wire [2:0] decoder_in = {mst1_req, mst0_req};

always @(*)                       //a buszt k�ri    priorit�sa      a buszt
begin                             //MST0    MST1        van         megkapja
   case (decoder_in)              //------------------------------------------
      2'b00: grant <= 2'b00;      //nem     nem      MST0-nak   ->  egyik sem
      2'b01: grant <= 2'b01;      //igen    nem      MST0-nak   ->    MST0 
      2'b10: grant <= 2'b10;      //nem     igen     MST0-nak   ->    MST1 
      2'b11: grant <= 2'b01;      //igen    igen     MST0-nak   ->    MST0
   endcase
end

//A busz hozz�f�r�s megad�s jelek meghajt�sa.
assign mst0_grant = grant[0];
assign mst1_grant = grant[1];

endmodule
