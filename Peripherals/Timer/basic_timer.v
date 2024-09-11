`timescale 1ns / 1ps

//******************************************************************************
//* Egyszer� 8 bites id�z�t� perif�ria.                                        *
//*                                                                            *
//* Az it�z�t� peri�dusideje T = (TR + 1) * PS * Tclk, ahol TR az id�z�t�      *
//* sz�ml�l� kezd��llapota (0 - 255), PS az el�oszt�s (1, 16, 64, 256, 1024,   *
//* 4096, 16384 vagy 65536) �s Tclk a rendszer�rajel peri�dusideje. A m�k�d�si *
//* m�d lehet egyszeres vagy peri�dikus, ism�telt �jrat�lt�ssel. Az id�z�t�si  *
//* peri�dus v�g�n lehet�s�g van megszak�t�sk�r�sre is.                        *
//*                                                                            *
//* A perif�ria c�me param�ter �tad�ssal �ll�that� be a fels� szint� modulban  *
//* az id�z�t� megp�ld�nyos�t�sakor. A szint�zis m�r ennek megfelele�en az     *
//* aktu�lis BASEADDR b�zisc�mmel t�rt�nik.                                    *
//*                                                                            *
//* A programoz�i fel�let:                                                     *
//*                                                                            *
//* C�m         T�pus   Bitek                                                  *
//* BASEADDR+0  WR      Az id�z�t� sz�ml�l� kezd��llapota                      *
//*                     TR7   TR6   TR5   TR4   TR3   TR2   TR1   TR0          *
//* BASEADDR+0  RD      Az id�z�t� sz�ml�l� aktu�lis �rt�ke                    *
//*                     TM7   TM6   TM5   TM4   TM3   TM2   TM1   TM0          *
//* BASEADDR+1  WR      Parancs regiszter                                      *
//*                     TIE   TPS2  TPS1  TPS0  -     -     TREP  TEN          *
//* BASEADDR+1  RD      St�tusz regiszter                                      *
//*                     TIT   TPS2  TPS1  TPS0  0     TOUT  TREP  TEN          *
//*                                                                            *
//* A parancs regiszter bitjei statikus set/clear �rtelemben haszn�lhat�k. A   *
//* st�tusz regiszter m�d bitjei statikusak, az esem�nyjelz� TOUT (�s ezzel    * 
//* egy�tt az esetleg akt�v IRQ is) olvas�sra t�rl�dik.                        *
//******************************************************************************
module basic_timer #(
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
   output wire       irq
);

//******************************************************************************
//* C�mdek�dol�s.                                                              *
//******************************************************************************
//A perif�ria kiv�laszt� jele.
wire psel = ((s_mst2slv_addr >> 1) == (BASEADDR >> 1));

//A sz�ml�l� kezd��llapot regiszter �r�s�nak jelz�se.
wire tr_wr = psel & s_mst2slv_wr & ~s_mst2slv_addr[0];

//A parancs regiszter �r�s�nak jelz�se.
wire tc_wr = psel & s_mst2slv_wr &  s_mst2slv_addr[0];

//A sz�ml�l� olvas�s�nak jelz�se.
wire tm_rd = psel & s_mst2slv_rd & ~s_mst2slv_addr[0];

//A st�tusz regiszter olvas�s�nak jelz�se.
wire ts_rd = psel & s_mst2slv_rd &  s_mst2slv_addr[0];


//******************************************************************************
//* Az id�z�t� sz�ml�l�j�nak kezd��llapot�t t�rol� regiszter.                  *
//******************************************************************************
reg [7:0] tr_reg;

always @(posedge clk)
begin
   if (rst)
      tr_reg <= 8'hff;                       //Reset: maximum peri�dus be�ll�t�sa
   else
      if (tr_wr)
         tr_reg <= s_mst2slv_data;           //A kezd��llapot regiszter �r�sa   
end


//******************************************************************************
//* A parancs regiszter bitjeit egyedileg specifik�ljuk.                       *
//******************************************************************************
//Az el�oszt� �s a sz�ml�l� v�g�llapot jelz�sei.
wire       ps_tc, tmr_cnt_tc;
//A parancs regiszter bitjei.
reg        ten, trep, tie;
reg  [2:0] tps;

always @(posedge clk)
begin
   if (rst)
      ten <= 1'b0;                           //Reset: az id�z�t� tilt�sa
   else
      if (tc_wr)
         ten <= s_mst2slv_data[0];           //Parancs regiszter �r�s
      else
         if (ps_tc && tmr_cnt_tc && !trep)   //Ha egyszeri �zemm�dban lej�rt,
            ten <= 1'b0;                     //akkor az enged�lyez�st t�r�lj�k
end

always @(posedge clk)
begin
   if (rst)
      trep <= 1'b0;                          //Reset: egyszeri �zemm�d be�ll�t�sa
   else
      if (tc_wr)
         trep <= s_mst2slv_data[1];          //Parancs regiszter �r�s
end

always @(posedge clk)
begin
   if (rst)
      tps <= 3'd0;                           //Reset: �1 el�oszt�s
   else
      if (tc_wr)
         tps <= s_mst2slv_data[6:4];         //Parancs regiszter �r�s
end

always @(posedge clk)
begin
   if (rst)
      tie <= 1'b0;                           //Reset: megszak�t�s tilt�sa
   else
      if (tc_wr)
         tie <= s_mst2slv_data[7];           //Parancs regiszter �r�s
end


//******************************************************************************
//* Az el�oszt�.                                                               *
//******************************************************************************
//Az el�oszt�s �rt�k�nek kiv�laszt�sa.
reg [15:0] ps_val;

always @(*)
begin
   case (tps)
      3'b000: ps_val <= 16'd0;               // �    1 el�oszt�s
      3'b001: ps_val <= 16'd15;              // �   16 el�oszt�s
      3'b010: ps_val <= 16'd63;              // �   64 el�oszt�s
      3'b011: ps_val <= 16'd255;             // �  256 el�oszt�s
      3'b100: ps_val <= 16'd1023;            // � 1024 el�oszt�s
      3'b101: ps_val <= 16'd4095;            // � 4096 el�oszt�s
      3'b110: ps_val <= 16'd16383;           // �16384 el�oszt�s
      3'b111: ps_val <= 16'd65535;           // �65536 el�oszt�s
   endcase
end

//Az el�oszt� sz�ml�l�ja.
reg [15:0] ps_cnt;
reg        ps_cnt_clr;

assign ps_tc = (ps_cnt == 16'd0);            //Az el�oszt� v�g�llapot�nak jelz�se

always @(posedge clk)
begin
   ps_cnt_clr <= tc_wr;
end

always @(posedge clk)
begin
   if (rst)
      ps_cnt <= 16'd0;                       //Reset: �1 el�oszt�s
   else
      if (ps_cnt_clr)
         ps_cnt <= ps_val;                   //Parancs regiszter �r�s: �jrat�lt�s
      else
         if (ten)
            if (ps_tc)
               ps_cnt <= ps_val;             //V�g�llapot: �jrat�lt�s
            else
               ps_cnt <= ps_cnt - 16'd1;     //Egy�bk�nt lefele sz�ml�l
end
      

//******************************************************************************
//* Az id�z�t� egy 8 bites lefel� sz�ml�l�.                                    *
//******************************************************************************     
reg [7:0] tmr_cnt;      

assign tmr_cnt_tc = (tmr_cnt == 8'h00);      //A nulla v�g�rt�ket jelezz�k

always @ (posedge clk) 
begin                     
   if (rst)
      tmr_cnt <= 8'hff;                      //Reset: max. �rt�k bet�lt�se
   else 
      if (tr_wr)
         tmr_cnt <= s_mst2slv_data;          //�j kezd��rt�k bet�lt�se k�zvetlen�l
      else
         if (ten && ps_tc)                   //Ha az id�z�t� enged�lyezett �s az
            if (tmr_cnt_tc)                  //el�oszt� v�g�llapotban van:
               tmr_cnt <= tr_reg;            // -id�z�t�s v�g�n, 0-n�l �jrat�lt�s   
            else
               tmr_cnt <= tmr_cnt - 8'd1;    // -egy�bk�nt sz�mol lefel�
end


//******************************************************************************
//* A st�tusz regiszter bitjei.                                                *
//****************************************************************************** 
reg tout;
     
//Id�z�t�s lej�rt jelz�s a st�tusz regiszterben.
//A be�ll�t�s nagyobb priorit�s�, mint a t�rl�s.
always @ (posedge clk) 
begin                     
   if (rst)
      tout <= 1'b0;                          //Reset: a TOUT jelz�s t�rl�se
   else 
      if (ps_tc && tmr_cnt_tc && ten)        //Ha az id�z�t� enged�lyezett �s
         tout <= 1'b1;                       //el�rte a v�g�rt�ket, akkor jelz�s 
      else
         if (ts_rd)
            tout <= 1'b0;                    //A st�tusz reg. olvas�sa t�rli
end

//Megszak�t�sk�r�s az id�z�t�s lej�rtakor, ha enged�lyezett.
assign irq = tie & tout;

//A 8 bites st�tusz inform�ci� �ssze�ll�t�sa az egyedi bitek alapj�n.
//Az IRQ �s a TOUT bit majdnem azonos jelent�s�, de az IRQ bit mag�ba
//foglalja az ITEN �llapot�t is. 
wire [7:0] status_reg = {irq, tps, 1'b0, tout, trep, ten};


//******************************************************************************
//* Az olvas�si adatbusz meghajt�sa.                                           *
//****************************************************************************** 
always @(*)
begin
   case ({ts_rd, tm_rd})
      2'b01  : s_slv2mst_data <= tmr_cnt;       //Id�z�t� sz�ml�l�ja
      2'b10  : s_slv2mst_data <= status_reg;    //St�tusz regiszter
      default: s_slv2mst_data <= 8'd0;          //Inakt�v 0 �rt�k, ha nincs olvas�s
   endcase
end

endmodule
