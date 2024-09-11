`timescale 1ns / 1ps

//******************************************************************************
//* Visszaolvashat� 8 bites kimeneti modul. A kimeneti adat visszaolvashat� a  *
//* RMW (Read-Modify-Write) t�pus� m�veletekhez.                               *
//*                                                                            *
//* A perif�ria c�me param�ter �tad�ssal �ll�that� be a fels� szint� modulban. *
//* a GPIO modul megp�ld�nyos�t�sakor. A szint�zis m�r ennek megfelele�en az   *
//* aktu�lis BASEADDR b�zisc�mmel t�rt�nik.                                    *
//*                                                                            *
//* A processzor �r�si (WRITE) ciklus�nak id�diagramja:                        *
//* Az �r�si ciklust az 1 �rajel ciklus ideig akt�v S_MST2SLV_WR jel jelzi. Az *
//* �r�si ciklus ideje alatt a c�m �s a kimeneti adat stabil.                  *
//*                                                                            *
//*                     --------          --------          --------           *
//* CLK                |        |        |        |        |        |          *
//*                ----          --------          --------          ----      *
//*                                        ------------------                  *
//* S_MST2SLV_WR                          /                  \                 *
//*                -----------------------                    -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_MST2SLV_ADDR                        X   �RV�NYES C�M   X                 *
//*                ----------------------- ------------------ -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_MST2SLV_DATA                        X   �RV�NYES ADAT  X                 *
//*                ----------------------- ------------------ -----------      *
//*                                                        ^                   *
//*                                Az �r�si parancs v�grehajt�sa itt t�rt�nik. *
//*                                                                            *
//* A processzor olvas�si (READ) ciklus�nak id�diagramja:                      *
//* Az olvas�si ciklust az 1 �rajel ciklus ideig akt�v S_MST2SLV_RD jel jelzi. *
//* Az olvas�si ciklus ideje alatt a c�m stabil �s a kiv�lasztott perif�ria az *
//* olvas�si adatbuszra kapuzza az adatot. Az olvas�si ciklus el�tt �s ut�n    *
//* az olvas�si adatbusz �rt�ke inakt�v 0 kell, hogy legyen.                   *
//*                                                                            *
//*                     --------          --------          --------           *
//* CLK                |        |        |        |        |        |          *
//*                ----          --------          --------          ----      *
//*                                        ------------------                  *
//* S_MST2SLV_RD                          /                  \                 *
//*                -----------------------                    -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_MST2SLV_ADDR                        X   �RV�NYES C�M   X                 *
//*                ----------------------- ------------------ -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_SLV2MST_DATA           0            X   �RV�NYES ADAT  X       0         *
//*                ----------------------- ------------------ -----------      *
//*                                                        ^                   *
//*                              A bemeneti adat mintav�telez�se itt t�rt�nik. *  
//******************************************************************************
module basic_owr #(
   //A perif�ria b�zisc�me.
   parameter BASEADDR = 8'hff
) (
   //�rajel �s reset.
   input  wire       clk,              //�rajel
   input  wire       rst,              //Reset jel
   
   //A slave busz interf�sz jelei.
   input  wire [7:0] s_mst2slv_addr,   //C�mbusz
   input  wire       s_mst2slv_wr,     //�r�s enged�lyez� jel
   input  wire       s_mst2slv_rd,     //Olvas�s enged�lyez� jel
   input  wire [7:0] s_mst2slv_data,   //�r�si adatbusz
   output wire [7:0] s_slv2mst_data,   //Olvas�si adatbusz
   
   //A GPIO interf�sz jelei.
   output wire [7:0] gpio_out          //Az IO l�bakra ki�rand� adat
);
  
//******************************************************************************
//* C�mdek�dol�s.                                                              *
//******************************************************************************
//A perif�ria kiv�laszt� jele.
wire psel = (s_mst2slv_addr == BASEADDR);

//A kimeneti adatregiszter �r�s�nak �s olvas�s�nak jelz�se.
wire out_reg_wr = psel & s_mst2slv_wr;
wire out_reg_rd = psel & s_mst2slv_rd;


//******************************************************************************
//* A kimeneti adatregiszter.                                                  *
//*                                                                            *
//* Az alapfunkci�t egyszer� adatkiad�ssal val�s�tjuk meg. A kimeneti adat     *
//* egy regiszterbe ker�l, ez fogja meghajtani a kimeneti vonalakat. Teh�t a   *
//* kimeneti buszon egy �r�si ciklus ideig megjelen�  dinamikus a regiszter    *
//* egy statikus, stabil adatt� alak�tja (am�g �jra nem �rjuk).                *
//******************************************************************************
reg [7:0] out_reg;

always @(posedge clk)
begin
   if (rst)
      out_reg <= 8'd0;                 //Reset eset�n t�r�lj�k a regisztert
   else
      if (out_reg_wr)
         out_reg <= s_mst2slv_data;    //Kimeneti adatregiszter �r�sa
end

//A kimeneti l�bak meghajt�sa.
assign gpio_out = out_reg;


//******************************************************************************
//* A processzor olvas�si adatbusz�nak meghajt�sa. Az olvas�si adatbuszra csak *
//* az olvas�s ideje alatt kapcsoljuk r� a k�rt �rt�ket, egy�bk�nt egy inakt�v *
//* nulla �rt�k jelenik meg rajta (elosztott busz multiplexer funkci�).        *
//******************************************************************************
assign s_slv2mst_data = (out_reg_rd) ? out_reg : 8'd0;

endmodule
