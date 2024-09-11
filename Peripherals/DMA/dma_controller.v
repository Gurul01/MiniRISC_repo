`timescale 1ns / 1ps

//******************************************************************************
//* Egyszer� DMA vez�rl�.                                                      *
//*                                                                            *
//* A DMA �tvitel a forr�s- �s c�lc�mek megad�sa ut�n az adatm�ret regiszter   *
//* �r�s�val ind�that�. A c�mek automatikus n�vel�se enged�lyezhet�, illetve   *
//* tilthat�. Az adat�tvitel v�g�t megszak�t�s jelzi, ha enged�lyezve van.     *
//*                                                                            *
//* A DMA vez�rl� regisztereinek el�r�se a slave busz interf�szen kereszt�l    *
//* t�rt�nik, a DMA �tvitel pedig a master busz interf�szen kereszt�l.         *
//*                                                                            *
//* A perif�ria c�me param�ter �tad�ssal �ll�that� be a fels� szint� modulban  *
//* az megp�ld�nyos�t�skor. A szint�zis m�r ennek megfelele�en az aktu�lis     *
//* BASEADDR b�zisc�mmel t�rt�nik.                                             *
//*                                                                            *
//* A programoz�i fel�let:                                                     *
//*                                                                            *
//* C�m         T�pus   Bitek                                                  *
//* BASEADDR+0  WR      A DMA vez�rl� parancs regisztere                       *
//*                     -     -     -     -     -     IEN   DINC  SINC         *
//* BASEADDR+0  RD      A DMA vez�rl� st�tusz regisztere                       *
//*                     BUSY  IRQ   IFLG  0     0     IEN   DINC  SINC         *
//* BASEADDR+1  WR      Forr�sc�m regiszter                                    *
//* BASEADDR+2  WR      C�lc�m regiszter                                       *
//* BASEADDR+3  WR      Adatm�ret regiszter                                    *
//*                                                                            *
//* A parancs regiszter bitjei statikus set/clear �rtelemben haszn�lhat�k. A   *
//* st�tusz regiszter m�d bitjei statikusak, az esem�nyjelz� IFLG (�s ezzel    * 
//* egy�tt az esetleg akt�v IRQ is) 1 be�r�s�ra t�rl�dik.                      *
//******************************************************************************
module dma_controller #(
   //A perif�ria b�zisc�me.
   parameter BASEADDR = 8'hff
) (
   //�rajel �s reset.
   input  wire       clk,              //�rajel
   input  wire       rst,              //Reset jel
   
   //A slave busz interf�sz jelei (regiszter el�r�s).
   input  wire [7:0] s_mst2slv_addr,   //C�mbusz
   input  wire       s_mst2slv_wr,     //�r�s enged�lyez� jel
   input  wire       s_mst2slv_rd,     //Olvas�s enged�lyez� jel
   input  wire [7:0] s_mst2slv_data,   //�r�si adatbusz
   output wire [7:0] s_slv2mst_data,   //Olvas�si adatbusz
   
   //A master busz interf�sz jelei (DMA �tvitel).
   output wire       m_bus_req,        //Busz hozz�f�r�s k�r�se
   input  wire       m_bus_grant,      //Busz hozz�f�r�s megad�sa
   output reg  [7:0] m_mst2slv_addr,   //C�mbusz
   output wire       m_mst2slv_wr,     //�r�s enged�lyez� jel
   output wire       m_mst2slv_rd,     //Olvas�s enged�lyez� jel
   output wire [7:0] m_mst2slv_data,   //�r�si adatbusz
   input  wire [7:0] m_slv2mst_data,   //Olvas�si adatbusz
   
   //Megszak�t�sk�r� kimenet.
   output wire       irq
);

//******************************************************************************
//* C�mdek�dol�s.                                                              *
//******************************************************************************
//A perif�ria kiv�laszt� jele.
wire psel = ((s_mst2slv_addr >> 2) == (BASEADDR >> 2));

//A parancs regiszter �r�s�nak jelz�se.
wire cmd_wr   = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b00); 

//A st�tusz regiszter olvas�s�nak jelz�se.
wire stat_rd  = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b00);

//A forr�sc�m regiszter �r�s�nak jelz�se. 
wire saddr_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b01);

//A c�lc�m regiszter �r�s�nak jelz�se. 
wire daddr_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b10);

//Az adatm�ret regiszter �r�s�nak jelz�se. 
wire len_wr   = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b11);


//******************************************************************************
//* A DMA vez�rl� parancs �s st�tusz regisztere.                               *
//******************************************************************************
wire busy;
wire done;

//A parancs regiszter SINC bitje (forr�sc�m n�vel�s enged�lyez�se).
reg sinc;

always @(posedge clk)
begin
   if (rst)
      sinc <= 1'b1;
   else
      if (cmd_wr && (busy == 0))
         sinc <= s_mst2slv_data[0];
end

//A parancs regiszter DINC bitje (c�lc�m n�vel�s enged�lyez�se).
reg dinc;

always @(posedge clk)
begin
   if (rst)
      dinc <= 1'b1;
   else
      if (cmd_wr && (busy == 0))
         dinc <= s_mst2slv_data[1];
end

//A parancs regiszter IEN bitje (megszak�t�s enged�lyez�s).
reg ien;

always @(posedge clk)
begin
   if (rst)
      ien <= 1'b0;
   else
      if (cmd_wr && (busy == 0))
         ien <= s_mst2slv_data[2];
end

//A st�tusz regiszter IFLG bitje (megszak�t�s flag). Be�ll�t�dik, ha
//v�get �rt a DMA adat�tvitel. A jelz�s 1 be�r�s�val t�r�lhet�.
reg iflg;

always @(posedge clk)
begin
   if (rst)
      iflg <= 1'b0;
   else
      if (done)
         iflg <= 1'b1;
      else
         if (cmd_wr && (busy == 0) && s_mst2slv_data[5])
            iflg <= 1'b0;
end

//A 8 bites st�tusz inform�ci� �ssze�ll�t�sa az egyedi bitek alapj�n.
//Az IRQ �s az IFLG bit majdnem azonos jelent�s�, de az IRQ bit mag�ba
//foglalja az IEN �llapot�t is. 
wire [7:0] status_reg = {busy, irq, iflg, 2'b00, ien, dinc, sinc};

//A slave olvas�si adatbusz meghajt�sa. Csak a st�tusz regiszter olvashat�.
assign s_slv2mst_data = (stat_rd) ? status_reg : 8'd0;

//A megszak�t�sk�r� kimenet meghajt�sa.
assign irq = ien & iflg;


//******************************************************************************
//* A forr�sc�m sz�ml�l�.                                                      *
//******************************************************************************
reg  [7:0] saddr_cnt;
wire       saddr_cnt_en;

always @(posedge clk)
begin
   if (saddr_wr && (busy == 0))
      saddr_cnt <= s_mst2slv_data;
   else
      if (saddr_cnt_en && sinc)
         saddr_cnt <= saddr_cnt + 8'd1;
end


//******************************************************************************
//* A c�lc�m sz�ml�l�.                                                         *
//******************************************************************************
reg  [7:0] daddr_cnt;
wire       daddr_cnt_en;

always @(posedge clk)
begin
   if (daddr_wr && (busy == 0))
      daddr_cnt <= s_mst2slv_data;
   else
      if (daddr_cnt_en && dinc)
         daddr_cnt <= daddr_cnt + 8'd1;
end


//******************************************************************************
//* Az adatm�ret sz�ml�l�.                                                     *
//******************************************************************************
reg  [7:0] len_cnt;
wire       len_cnt_en;
wire       len_cnt_tc = (len_cnt == 8'd0);

always @(posedge clk)
begin
   if (len_wr && (busy == 0))
      len_cnt <= s_mst2slv_data;
   else
      if (len_cnt_en)
         len_cnt <= len_cnt - 8'd1;
end


//******************************************************************************
//* A vez�rl� �llapotg�p.                                                      *
//******************************************************************************
localparam STATE_IDLE = 2'd0;
localparam STATE_RD   = 2'd1;
localparam STATE_WR   = 2'd2;
localparam STATE_DONE = 2'd3;

reg [1:0] state;

always @(posedge clk)
begin
   if (rst)
      state <= STATE_IDLE;
   else
      case (state)
         //V�rakoz�s a DMA adat�tvitel ind�t�s�ra. Az adatm�ret
         //regiszter �r�s�val ind�that� az �tvitel.
         STATE_IDLE: if (len_wr)
                        state <= STATE_RD;
                     else
                        state <= STATE_IDLE;
                        
         //Mem�ria olvas�s a forr�sc�mr�l.
         STATE_RD  : if (m_bus_grant)
                        state <= STATE_WR;
                     else
                        state <= STATE_RD;
         
         //Mem�ria �r�s a c�lc�mre �s a h�tral�v� b�jtok sz�m�nak
         //vizsg�lata.
         STATE_WR  : if (m_bus_grant)
                        if (len_cnt_tc)
                           state <= STATE_DONE;
                        else
                           state <= STATE_RD;
                     else
                        state <= STATE_WR;
                        
         //A DMA �tvitel befejez�d�s�nek jelz�se.
         STATE_DONE: state <= STATE_IDLE;
      endcase
end

//Foglalts�g jelz�s.
assign busy = ~(state == STATE_IDLE);

//Az adat�tvitel befejez�d�s�nek jelz�se.
assign done = (state == STATE_DONE);

//A sz�ml�l�k enged�lyez� jelei.
assign saddr_cnt_en = (state == STATE_RD) & m_bus_grant;
assign daddr_cnt_en = (state == STATE_WR) & m_bus_grant;
assign len_cnt_en   = (state == STATE_RD) & m_bus_grant;


//******************************************************************************
//* A master busz interf�sz kimeneteinek meghajt�sa.                           *
//******************************************************************************
//Busz hozz�f�r�s k�r�se.
assign m_bus_req = (state == STATE_RD) | (state == STATE_WR);

//A c�mbuszra mem�ria olvas�s eset�n a forr�sc�m, mem�ria �r�s
//eset�n a c�lc�m, egy�bk�nt pedig inakt�v nulla �rt�k ker�l.
always @(*)
begin
   if (m_bus_grant)
      case (state)
         STATE_RD: m_mst2slv_addr <= saddr_cnt;
         STATE_WR: m_mst2slv_addr <= daddr_cnt;
         default : m_mst2slv_addr <= 8'd0;
      endcase
   else
      m_mst2slv_addr <= 8'd0;
end

//�r�s �s olvas�s enged�lyez� jelek.
assign m_mst2slv_wr = (state == STATE_WR) & m_bus_grant;
assign m_mst2slv_rd = (state == STATE_RD) & m_bus_grant;

//A slave egys�gr�l beolvasott adatot t�rol� regiszter.
reg [7:0] data_reg;

always @(posedge clk)
begin
   if (m_mst2slv_rd)
      data_reg <= m_slv2mst_data;
end

//Az �r�si adatbusz meghajt�sa.
assign m_mst2slv_data = (m_mst2slv_wr) ? data_reg : 8'd0;

endmodule
