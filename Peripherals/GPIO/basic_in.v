`timescale 1ns / 1ps

//******************************************************************************
//* Egyszer� 8 bites bemeneti modul. Semmi extra szolg�ltat�s, csak            * 
//* mintav�telez�s t�rt�nik.                                                   *
//*                                                                            *
//* A perif�ria c�me param�ter �tad�ssal �ll�that� be a fels� szint� modulban. *
//* a GPIO modul megp�ld�nyos�t�sakor. A szint�zis m�r ennek megfelele�en az   *
//* aktu�lis BASEADDR b�zisc�mmel t�rt�nik.                                    *
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
module basic_in #(
   //A perif�ria b�zisc�me.
   parameter BASEADDR = 8'hff
) (
   //�rajel �s reset.
   input  wire       clk,              //�rajel
   input  wire       rst,              //Reset jel
   
   //A slave busz interf�sz jelei.
   input  wire [7:0] s_mst2slv_addr,   //C�mbusz
   input  wire       s_mst2slv_rd,     //Olvas�s enged�lyez� jel
   output wire [7:0] s_slv2mst_data,   //Olvas�si adatbusz
   
   //A GPIO interf�sz jelei.
   input  wire [7:0] gpio_in           //Az IO l�bak aktu�lis �rt�ke
);

//******************************************************************************
//* C�mdek�dol�s.                                                              *
//******************************************************************************
//A perif�ria kiv�laszt� jele.
wire psel = (s_mst2slv_addr == BASEADDR);

//A bemeneti adatregiszter olvas�s�nak jelz�se.
wire in_reg_rd = psel & s_mst2slv_rd;


//******************************************************************************
//* A bemeneti adatregiszter.                                                  *
//*                                                                            *
//* Az alapfunkci�t egyszer� minav�telez�ssel val�s�tjuk meg, melyet minden    * 
//* �rajel ciklusban elv�gz�nk.                                                *
//******************************************************************************
reg [7:0] in_reg;

always @(posedge clk)
begin
   if (rst)
      in_reg <= 8'd0;                  //Reset eset�n t�r�lj�k a regisztert
   else
      in_reg <= gpio_in;               //Egy�bk�nt folyamatosan mintav�telezz�k
end                                    //az IO l�bak �rt�k�t


//******************************************************************************
//* A processzor olvas�si adatbusz�nak meghajt�sa. Az olvas�si adatbuszra csak *
//* az olvas�s ideje alatt kapcsoljuk r� a k�rt �rt�ket, egy�bk�nt egy inakt�v *
//* nulla �rt�k jelenik meg rajta (elosztott busz multiplexer funkci�).        *
//******************************************************************************
assign s_slv2mst_data = (in_reg_rd) ? in_reg : 8'd0;

endmodule
