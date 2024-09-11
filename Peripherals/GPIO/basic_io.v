`timescale 1ns / 1ps

//******************************************************************************
//* Egyszer� 8 bites k�tir�ny� I/O modul.                                      *
//*                                                                            *
//* A perif�ria c�me param�ter �tad�ssal �ll�that� be a fels� szint� modulban  *
//* a GPIO modul megp�ld�nyos�t�sakor. A szint�zis m�r ennek megfelele�en az   *
//* aktu�lis BASEADDR b�zisc�mmel t�rt�nik.                                    *
//*                                                                            *
//* A BASEADDR c�m szolg�l a kimeneti regiszter �r�s�ra �s visszaolvas�s�ra,   *
//* a BASEADDR+1 c�mr�l olvashat� be a GPIO l�bak aktu�lis �rt�ke, valamint    *
//* a BASEADDR+2 c�m szolg�l az ir�ny regiszter �r�s�ra �s visszaolvas�s�ra.   * 
//*                                                                            *
//* Teh�t a BASIC_IO perif�ria a szok�sos mikrovez�rl�k port GPIO funkci�j�t   *
//* val�s�tja meg. Term�szetesen egy adott id�ben egy GPIO vonal vagy csak     * 
//* kimenet, vagy csak bemenet lehet, m�g ha ezt a programb�l dinamikusan      * 
//* �ll�thatjuk is. S�t k�l�n�s figyelmet ig�nyel egy �ramk�r�n bel�l az adott *
//* vonal k�ls� interf�sze, elker�lend� az ellent�tes �llapot� kimenetek       *
//* �sszekapcsol�s�t!                                                          *
//*                                                                            *
//* Egyetlen IC l�b (=Port pin) funkci�ja grafikusan �br�zolva:                *
//*                                                                            *
//*                   -------               Vcc                                *
//*    DIR         >--|D   Q|---------|     |                                  *
//*                   |     |  |      |     |                                  *
//*                   |>    |  |      |    |-|  Rf felh�z� ellen�ll�s          *
//*                   -------  |      |    | |                                 *
//*    DIR olvas�s <-----------|    |\|    |-|                                 *
//*                   -------       | \     |                                  *
//*    adat KI     >--|D   Q|-------|  >-------------<-> az IC programozhat�   *
//*                   |     |  |    | /        |         IO l�ba               *
//*                   |>    |  |    |/         |                               *
//*                   -------  |               |                               *
//*    KI olvas�s  <-----------|               |                               *
//*                   -------                  |                               *
//*    IO l�b olv. <--|Q   D|------------------|                               *
//*                   |     |                                                  *
//*                   |    <|                                                  *
//*                   -------                                                  *
//*                                                                            *
//* A programoz�i fel�let:                                                     *
//*                                                                            *
//* C�m         T�pus   Bitek                                                  *
//* BASEADDR+0  RD/WR   Kimeneti adatregiszter                                 *
//*                     OUT7  OUT6  OUT5  OUT4  OUT3  OUT2  OUT1  OUT0         *
//* BASEADDR+1  RD      Adat az IO l�bakon                                     *  
//*                     IN7   IN6   IN5   IN4   IN3   IN2   IN1   IN0          *
//* BASEADDR+2  RD/WR   Az IO l�b ir�ny�nak be�ll�t�sa (0: be, 1:ki)           *
//*                     DIR7  DIR6  DIR5  DIR4  DIR3  DIR2  DIR1  DIR0         *
//* BASEADDR+3  RD      Nem haszn�lt, olvas�s eset�n mindig 0                  *
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
module basic_io #(
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
   output reg  [7:0] s_slv2mst_data,   //Olvas�si adatbusz
   
   //A GPIO interf�sz jelei.
   output wire [7:0] gpio_out,         //Az IO l�bakra ki�rand� adat
   input  wire [7:0] gpio_in,          //Az IO l�bak aktu�lis �rt�ke
   output wire [7:0] gpio_dir          //A kimeneti meghajt� enged�lyez� jele
);
  
//******************************************************************************
//* C�mdek�dol�s.                                                              *
//******************************************************************************
//A perif�ria kiv�laszt� jele.
wire psel = ((s_mst2slv_addr >> 2) == (BASEADDR >> 2));

//A kimeneti adatregiszter �r�s�nak �s olvas�s�nak jelz�se.
wire out_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b00);
wire out_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b00);

//A bemeneti adatregiszter olvas�s�nak jelz�se.
wire in_reg_rd  = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b01);

//Az ir�ny kiv�laszt� regiszter �r�s�nak �s olvas�s�nak jelz�se.
wire dir_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b10);
wire dir_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b10);


//******************************************************************************
//* A kimeneti adatregiszter.                                                  *
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

//Az IO l�bak meghajt�sa.
assign gpio_out = out_reg;


//******************************************************************************
//* A bemeneti adatregiszter.                                                  *
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
//* Az ir�ny kiv�laszt� regiszter.                                             *
//* 0: az adott IO l�b ir�nya bemenet                                          *
//* 1: az adott IO l�b ir�nya kimenet                                          *
//******************************************************************************
reg [7:0] dir_reg;

always @(posedge clk)
begin
   if (rst)
      dir_reg <= 8'd0;                 //Reset eset�n minden IO l�b bemenet
   else
      if (dir_reg_wr)
         dir_reg <= s_mst2slv_data;    //Ir�ny kiv�laszt� regiszter �r�sa
end

//Az ir�ny kiv�laszt� kimenet meghajt�sa.
assign gpio_dir = dir_reg;


//******************************************************************************
//* A processzor olvas�si adatbusz�nak meghajt�sa. Az olvas�si adatbuszra csak *
//* az olvas�s ideje alatt kapcsoljuk r� a k�rt �rt�ket, egy�bk�nt egy inakt�v *
//* nulla �rt�k jelenik meg rajta (elosztott busz multiplexer funkci�).        *
//******************************************************************************
wire [2:0] dout_sel = {dir_reg_rd, in_reg_rd, out_reg_rd};

always @(*)
begin
   case (dout_sel)
      3'b001 : s_slv2mst_data <= out_reg;    //A kimeneti adatregiszter olvas�sa
      3'b010 : s_slv2mst_data <= in_reg;     //A bemeneti adatregiszter olvas�sa
      3'b100 : s_slv2mst_data <= dir_reg;    //Az ir�ny kiv�laszt� reg. olvas�sa
      default: s_slv2mst_data <= 8'd0;       //Egy�bk�nt inakt�v nulla �rt�k
   endcase
end

endmodule
