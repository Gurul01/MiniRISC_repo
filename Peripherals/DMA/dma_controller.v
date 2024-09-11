`timescale 1ns / 1ps

//******************************************************************************
//* Egyszerû DMA vezérlõ.                                                      *
//*                                                                            *
//* A DMA átvitel a forrás- és célcímek megadása után az adatméret regiszter   *
//* írásával indítható. A címek automatikus növelése engedélyezhetõ, illetve   *
//* tiltható. Az adatátvitel végét megszakítás jelzi, ha engedélyezve van.     *
//*                                                                            *
//* A DMA vezérlõ regisztereinek elérése a slave busz interfészen keresztül    *
//* történik, a DMA átvitel pedig a master busz interfészen keresztül.         *
//*                                                                            *
//* A periféria címe paraméter átadással állítható be a felsõ szintû modulban  *
//* az megpéldányosításkor. A szintézis már ennek megfeleleõen az aktuális     *
//* BASEADDR báziscímmel történik.                                             *
//*                                                                            *
//* A programozói felület:                                                     *
//*                                                                            *
//* Cím         Típus   Bitek                                                  *
//* BASEADDR+0  WR      A DMA vezérlõ parancs regisztere                       *
//*                     -     -     -     -     -     IEN   DINC  SINC         *
//* BASEADDR+0  RD      A DMA vezérlõ státusz regisztere                       *
//*                     BUSY  IRQ   IFLG  0     0     IEN   DINC  SINC         *
//* BASEADDR+1  WR      Forráscím regiszter                                    *
//* BASEADDR+2  WR      Célcím regiszter                                       *
//* BASEADDR+3  WR      Adatméret regiszter                                    *
//*                                                                            *
//* A parancs regiszter bitjei statikus set/clear értelemben használhatók. A   *
//* státusz regiszter mód bitjei statikusak, az eseményjelzõ IFLG (és ezzel    * 
//* együtt az esetleg aktív IRQ is) 1 beírására törlõdik.                      *
//******************************************************************************
module dma_controller #(
   //A periféria báziscíme.
   parameter BASEADDR = 8'hff
) (
   //Órajel és reset.
   input  wire       clk,              //Órajel
   input  wire       rst,              //Reset jel
   
   //A slave busz interfész jelei (regiszter elérés).
   input  wire [7:0] s_mst2slv_addr,   //Címbusz
   input  wire       s_mst2slv_wr,     //Írás engedélyezõ jel
   input  wire       s_mst2slv_rd,     //Olvasás engedélyezõ jel
   input  wire [7:0] s_mst2slv_data,   //Írási adatbusz
   output wire [7:0] s_slv2mst_data,   //Olvasási adatbusz
   
   //A master busz interfész jelei (DMA átvitel).
   output wire       m_bus_req,        //Busz hozzáférés kérése
   input  wire       m_bus_grant,      //Busz hozzáférés megadása
   output reg  [7:0] m_mst2slv_addr,   //Címbusz
   output wire       m_mst2slv_wr,     //Írás engedélyezõ jel
   output wire       m_mst2slv_rd,     //Olvasás engedélyezõ jel
   output wire [7:0] m_mst2slv_data,   //Írási adatbusz
   input  wire [7:0] m_slv2mst_data,   //Olvasási adatbusz
   
   //Megszakításkérõ kimenet.
   output wire       irq
);

//******************************************************************************
//* Címdekódolás.                                                              *
//******************************************************************************
//A periféria kiválasztó jele.
wire psel = ((s_mst2slv_addr >> 2) == (BASEADDR >> 2));

//A parancs regiszter írásának jelzése.
wire cmd_wr   = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b00); 

//A státusz regiszter olvasásának jelzése.
wire stat_rd  = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b00);

//A forráscím regiszter írásának jelzése. 
wire saddr_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b01);

//A célcím regiszter írásának jelzése. 
wire daddr_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b10);

//Az adatméret regiszter írásának jelzése. 
wire len_wr   = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b11);


//******************************************************************************
//* A DMA vezérlõ parancs és státusz regisztere.                               *
//******************************************************************************
wire busy;
wire done;

//A parancs regiszter SINC bitje (forráscím növelés engedélyezése).
reg sinc;

always @(posedge clk)
begin
   if (rst)
      sinc <= 1'b1;
   else
      if (cmd_wr && (busy == 0))
         sinc <= s_mst2slv_data[0];
end

//A parancs regiszter DINC bitje (célcím növelés engedélyezése).
reg dinc;

always @(posedge clk)
begin
   if (rst)
      dinc <= 1'b1;
   else
      if (cmd_wr && (busy == 0))
         dinc <= s_mst2slv_data[1];
end

//A parancs regiszter IEN bitje (megszakítás engedélyezés).
reg ien;

always @(posedge clk)
begin
   if (rst)
      ien <= 1'b0;
   else
      if (cmd_wr && (busy == 0))
         ien <= s_mst2slv_data[2];
end

//A státusz regiszter IFLG bitje (megszakítás flag). Beállítódik, ha
//véget ért a DMA adatátvitel. A jelzés 1 beírásával törölhetõ.
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

//A 8 bites státusz információ összeállítása az egyedi bitek alapján.
//Az IRQ és az IFLG bit majdnem azonos jelentésû, de az IRQ bit magába
//foglalja az IEN állapotát is. 
wire [7:0] status_reg = {busy, irq, iflg, 2'b00, ien, dinc, sinc};

//A slave olvasási adatbusz meghajtása. Csak a státusz regiszter olvasható.
assign s_slv2mst_data = (stat_rd) ? status_reg : 8'd0;

//A megszakításkérõ kimenet meghajtása.
assign irq = ien & iflg;


//******************************************************************************
//* A forráscím számláló.                                                      *
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
//* A célcím számláló.                                                         *
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
//* Az adatméret számláló.                                                     *
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
//* A vezérlõ állapotgép.                                                      *
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
         //Várakozás a DMA adatátvitel indítására. Az adatméret
         //regiszter írásával indítható az átvitel.
         STATE_IDLE: if (len_wr)
                        state <= STATE_RD;
                     else
                        state <= STATE_IDLE;
                        
         //Memória olvasás a forráscímrõl.
         STATE_RD  : if (m_bus_grant)
                        state <= STATE_WR;
                     else
                        state <= STATE_RD;
         
         //Memória írás a célcímre és a hátralévõ bájtok számának
         //vizsgálata.
         STATE_WR  : if (m_bus_grant)
                        if (len_cnt_tc)
                           state <= STATE_DONE;
                        else
                           state <= STATE_RD;
                     else
                        state <= STATE_WR;
                        
         //A DMA átvitel befejezõdésének jelzése.
         STATE_DONE: state <= STATE_IDLE;
      endcase
end

//Foglaltság jelzés.
assign busy = ~(state == STATE_IDLE);

//Az adatátvitel befejezõdésének jelzése.
assign done = (state == STATE_DONE);

//A számlálók engedélyezõ jelei.
assign saddr_cnt_en = (state == STATE_RD) & m_bus_grant;
assign daddr_cnt_en = (state == STATE_WR) & m_bus_grant;
assign len_cnt_en   = (state == STATE_RD) & m_bus_grant;


//******************************************************************************
//* A master busz interfész kimeneteinek meghajtása.                           *
//******************************************************************************
//Busz hozzáférés kérése.
assign m_bus_req = (state == STATE_RD) | (state == STATE_WR);

//A címbuszra memória olvasás esetén a forráscím, memória írás
//esetén a célcím, egyébként pedig inaktív nulla érték kerül.
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

//Írás és olvasás engedélyezõ jelek.
assign m_mst2slv_wr = (state == STATE_WR) & m_bus_grant;
assign m_mst2slv_rd = (state == STATE_RD) & m_bus_grant;

//A slave egységrõl beolvasott adatot tároló regiszter.
reg [7:0] data_reg;

always @(posedge clk)
begin
   if (m_mst2slv_rd)
      data_reg <= m_slv2mst_data;
end

//Az írási adatbusz meghajtása.
assign m_mst2slv_data = (m_mst2slv_wr) ? data_reg : 8'd0;

endmodule
