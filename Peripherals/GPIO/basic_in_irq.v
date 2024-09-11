`timescale 1ns / 1ps

//******************************************************************************
//* Egyszer� 8 bites bemeneti modul megszak�t�sk�r�si lehet�s�ggel a bemeneti  * 
//* jelek megv�ltoz�sa eset�n. A gpio_in bemenet 200 Hz-es mintav�telez�ssel   *
//* perg�smentes�tve van.                                                      *
//*                                                                            *
//* A perif�ria c�me param�ter �tad�ssal �ll�that� be a fels� szint� modulban. *
//* a GPIO modul megp�ld�nyos�t�sakor. A szint�zis m�r ennek megfelele�en az   *
//* aktu�lis BASEADDR b�zisc�mmel t�rt�nik.                                    *
//*                                                                            *
//* A programoz�i fel�let:                                                     *
//*                                                                            *
//* C�m         T�pus   Bitek                                                  *
//* BASEADDR+0  RD      Adatregiszter                                          *
//*                     IN7   IN6   IN5   IN4   IN3   IN2   IN1   IN0          *
//* BASEADDR+1  RD/WR   Megszak�t�s enged�lyez� regiszter                      *
//*                     IE7   IE6   IE5   IE4   IE3   IE2   IE1   IE0          *
//* BASEADDR+2  RD/W1C  Megszak�t�s flag regiszter                             *
//*                     IF7   IF6   IF5   IF4   IF3   IF2   IF1   IF0          *
//*                                                                            *
//* A megszak�t�s flag regiszter bitjei 1 be�r�s�val t�r�lhet�ek, ezzel        *
//* nyugt�zva a megszak�t�sk�r�st.                                             * 
//******************************************************************************
module basic_in_irq #(
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
   
   //Megszak�t�sk�r� kimenet.
   output wire       irq,
   
   //A GPIO interf�sz jelei.
   input  wire [7:0] gpio_in           //Az IO l�bak aktu�lis �rt�ke
);

//******************************************************************************
//* C�mdek�dol�s.                                                              *
//******************************************************************************
//A perif�ria kiv�laszt� jele.
wire psel = ((s_mst2slv_addr >> 2) == (BASEADDR >> 2));

//Az adatregiszter olvas�s�nak jelz�se.
wire in_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b00);

//A megszak�t�s enged�lyez� regiszter �r�s�nak �s olvas�s�nak jelz�se.
wire ie_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b01);
wire ie_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b01);

//A megszak�t�s flag regiszter �r�s�nak �s olvas�s�nak jelz�se.
wire if_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b10);
wire if_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b10);


//******************************************************************************
//* A 200 Hz-es enged�lyez� jel el��ll�t�sa a bemenet perg�smentes�t�s�hez.    *
//* A sz�ml�l� modulusa: 16000000 Hz / 200 Hz = 80000 (79999-0).               * 
//******************************************************************************
reg  [16:0] clk_div_cnt;
wire        gpio_in_sample = (clk_div_cnt == 0);

always @(posedge clk)
begin
   if (rst || gpio_in_sample)
      clk_div_cnt <= 17'd79999;
   else
      clk_div_cnt <= clk_div_cnt - 17'd1;
end


//******************************************************************************
//* Az adatregiszter.                                                          *
//******************************************************************************
reg [7:0] in_reg;

always @(posedge clk)
begin
   if (rst)
      in_reg <= 8'd0;                  //Reset eset�n t�r�lj�k a regisztert
   else
      if (gpio_in_sample)              //Egy�bk�nt 200 Hz-el folyamatosan
         in_reg <= gpio_in;            //mintav�telezz�k a bemenetet
end

//A bemeneti v�ltoz�s detekt�l�sa.
reg  [7:0] in_reg_prev;
wire [7:0] in_reg_changed = in_reg ^ in_reg_prev;

always @(posedge clk)
begin
   if (rst)
      in_reg_prev <= 8'd0;
   else
      in_reg_prev <= in_reg;
end


//******************************************************************************
//* A megszak�t�s enged�lyez� regiszter.                                       *
//******************************************************************************
reg [7:0] ie_reg;

always @(posedge clk)
begin
   if (rst)
      ie_reg <= 8'd0;                  //Reset: tiltjuk a megszak�t�sokat
   else
      if (ie_reg_wr)
         ie_reg <= s_mst2slv_data;     //Regiszter �r�s
end


//******************************************************************************
//* A megszak�t�s flag regiszter.                                              *
//******************************************************************************
reg [7:0] if_reg;

integer i;

always @(posedge clk)
begin
   for (i = 0; i < 8; i = i + 1)
      if (rst)
         if_reg[i] <= 1'b0;            //Reset: a jelz�sek t�rl�se
      else
         if (in_reg_changed[i])
            if_reg[i] <= 1'b1;         //A bemenet megv�ltoz�s�nak jelz�se
         else
            if (if_reg_wr && s_mst2slv_data[i])
               if_reg[i] <= 1'b0;      //1 be�r�sa eset�n t�r�lj�k a jelz�st
end

//A megszak�t�sk�r� kimenet meghajt�sa.
assign irq = |(if_reg & ie_reg);


//******************************************************************************
//* Az olvas�si adatbusz meghajt�sa.                                           *
//******************************************************************************
wire [2:0] dout_sel = {if_reg_rd, ie_reg_rd, in_reg_rd};

always @(*)
begin
   case (dout_sel)
      3'b001 : s_slv2mst_data <= in_reg;
      3'b010 : s_slv2mst_data <= ie_reg;
      3'b100 : s_slv2mst_data <= if_reg;
      default: s_slv2mst_data <= 8'd0;
   endcase
end

endmodule
