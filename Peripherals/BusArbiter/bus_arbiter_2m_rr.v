`timescale 1ns / 1ps

//******************************************************************************
//* Egyszer� busz arbiter 2 master egys�ghez.                                  *
//*                                                                            *
//* A busz hozz�f�r�s megad�sa round-robin (k�rforg�sos) �temez�s szerint      *
//* t�rt�nik, azaz minden hozz�f�r�s ut�n a k�vetkez� master egys�gnek lesz    *
//* nagyobb prior�t�sa. T�bb master egys�g egyidej� k�r�se eset�n a nagyobb    *
//* prior�t�s� kapja meg a buszt. A busz hozz�f�r�ssel nem rendelkez� master   *
//* egys�geknek inakt�v nulla �rt�kkel kell meghajtaniuk a kimeneteiket.       *
//*                                                                            *
//*                   ------        ------        ------        ------         *
//* CLK              |      |      |      |      |      |      |      |        *
//*               ---        ------        ------        ------        ---     *
//*                                                                            *
//* Priorit�s           MASTER 0   |   MASTER 1  |   MASTER 0  |  MASTER 1     *
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
//* MST2SLV_ADDR   0  X   MST0 C�M   X   MST1 C�M   X   MST0 C�M   X   0       *
//*               ---- -------------- ---- ------------------------ -----      *
//*               ---- -------------- -------------- -------------- -----      *
//* MST2SLV_DATA   0  X   MST0 ADAT  X   MST1 ADAT  X   MST0 ADAT  X   0       *
//* SLV2MST_DATA  ---- -------------- -------------- -------------- -----      *
//*                                 ^              ^              ^            *
//*                    Az �r�si vagy olvas�si parancsok itt hajt�dnak v�gre.   *
//******************************************************************************
module bus_arbiter_2m_rr(
   //�rajel �s reset.
   input  wire clk,              //�rajel
   input  wire rst,              //Reset jel
   
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
//A priorit�st kiv�laszt� jel:
//0: a master 0 egys�gnek van nagyobb priorit�sa
//1: a master 1 egys�gnek van nagyobb priorit�sa
reg priority_sel;

//A priorit�s dek�der kimenete.
reg [1:0] grant;

//A priorit�s dek�der bemenete.
wire [2:0] decoder_in = {priority_sel, mst1_req, mst0_req};

always @(*)                        //a buszt k�ri    priorit�sa      a buszt
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

//A busz hozz�f�r�s megad�s jelek meghajt�sa.
assign mst0_grant = grant[0];
assign mst1_grant = grant[1];


//******************************************************************************
//* A round-robin (k�rforg�sos) �temez�s megval�s�t�sa: minden busz hozz�f�r�s *
//* ut�n a k�vetkez� master egys�gnek lesz nagyobb priorit�sa.                 *
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
