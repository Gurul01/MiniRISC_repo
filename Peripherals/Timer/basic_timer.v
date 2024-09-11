`timescale 1ns / 1ps

//******************************************************************************
//* Egyszerû 8 bites idõzítõ periféria.                                        *
//*                                                                            *
//* Az itõzítõ periódusideje T = (TR + 1) * PS * Tclk, ahol TR az idõzítõ      *
//* számláló kezdõállapota (0 - 255), PS az elõosztás (1, 16, 64, 256, 1024,   *
//* 4096, 16384 vagy 65536) és Tclk a rendszerórajel periódusideje. A mûködési *
//* mód lehet egyszeres vagy periódikus, ismételt újratöltéssel. Az idõzítési  *
//* periódus végén lehetõség van megszakításkérésre is.                        *
//*                                                                            *
//* A periféria címe paraméter átadással állítható be a felsõ szintû modulban  *
//* az idõzítõ megpéldányosításakor. A szintézis már ennek megfeleleõen az     *
//* aktuális BASEADDR báziscímmel történik.                                    *
//*                                                                            *
//* A programozói felület:                                                     *
//*                                                                            *
//* Cím         Típus   Bitek                                                  *
//* BASEADDR+0  WR      Az idõzítõ számláló kezdõállapota                      *
//*                     TR7   TR6   TR5   TR4   TR3   TR2   TR1   TR0          *
//* BASEADDR+0  RD      Az idõzítõ számláló aktuális értéke                    *
//*                     TM7   TM6   TM5   TM4   TM3   TM2   TM1   TM0          *
//* BASEADDR+1  WR      Parancs regiszter                                      *
//*                     TIE   TPS2  TPS1  TPS0  -     -     TREP  TEN          *
//* BASEADDR+1  RD      Státusz regiszter                                      *
//*                     TIT   TPS2  TPS1  TPS0  0     TOUT  TREP  TEN          *
//*                                                                            *
//* A parancs regiszter bitjei statikus set/clear értelemben használhatók. A   *
//* státusz regiszter mód bitjei statikusak, az eseményjelzõ TOUT (és ezzel    * 
//* együtt az esetleg aktív IRQ is) olvasásra törlõdik.                        *
//******************************************************************************
module basic_timer #(
   //A periféria báziscíme.
   parameter BASEADDR = 8'hff
) (
   //Órajel és reset.
   input  wire       clk,              //Órajel
   input  wire       rst,              //Reset jel
   
   //A slave busz interfész jelei.
   input  wire [7:0] s_mst2slv_addr,   //Címbusz
   input  wire       s_mst2slv_wr,     //Írás engedélyezõ jel
   input  wire       s_mst2slv_rd,     //Olvasás engedélyezõ jel
   input  wire [7:0] s_mst2slv_data,   //Írási adatbusz
   output reg  [7:0] s_slv2mst_data,   //Olvasási adatbusz
   
   //Megszakításkérõ kimenet.
   output wire       irq
);

//******************************************************************************
//* Címdekódolás.                                                              *
//******************************************************************************
//A periféria kiválasztó jele.
wire psel = ((s_mst2slv_addr >> 1) == (BASEADDR >> 1));

//A számláló kezdõállapot regiszter írásának jelzése.
wire tr_wr = psel & s_mst2slv_wr & ~s_mst2slv_addr[0];

//A parancs regiszter írásának jelzése.
wire tc_wr = psel & s_mst2slv_wr &  s_mst2slv_addr[0];

//A számláló olvasásának jelzése.
wire tm_rd = psel & s_mst2slv_rd & ~s_mst2slv_addr[0];

//A státusz regiszter olvasásának jelzése.
wire ts_rd = psel & s_mst2slv_rd &  s_mst2slv_addr[0];


//******************************************************************************
//* Az idõzítõ számlálójának kezdõállapotát tároló regiszter.                  *
//******************************************************************************
reg [7:0] tr_reg;

always @(posedge clk)
begin
   if (rst)
      tr_reg <= 8'hff;                       //Reset: maximum periódus beállítása
   else
      if (tr_wr)
         tr_reg <= s_mst2slv_data;           //A kezdõállapot regiszter írása   
end


//******************************************************************************
//* A parancs regiszter bitjeit egyedileg specifikáljuk.                       *
//******************************************************************************
//Az elõosztó és a számláló végállapot jelzései.
wire       ps_tc, tmr_cnt_tc;
//A parancs regiszter bitjei.
reg        ten, trep, tie;
reg  [2:0] tps;

always @(posedge clk)
begin
   if (rst)
      ten <= 1'b0;                           //Reset: az idõzítõ tiltása
   else
      if (tc_wr)
         ten <= s_mst2slv_data[0];           //Parancs regiszter írás
      else
         if (ps_tc && tmr_cnt_tc && !trep)   //Ha egyszeri üzemmódban lejárt,
            ten <= 1'b0;                     //akkor az engedélyezést töröljük
end

always @(posedge clk)
begin
   if (rst)
      trep <= 1'b0;                          //Reset: egyszeri üzemmód beállítása
   else
      if (tc_wr)
         trep <= s_mst2slv_data[1];          //Parancs regiszter írás
end

always @(posedge clk)
begin
   if (rst)
      tps <= 3'd0;                           //Reset: ÷1 elõosztás
   else
      if (tc_wr)
         tps <= s_mst2slv_data[6:4];         //Parancs regiszter írás
end

always @(posedge clk)
begin
   if (rst)
      tie <= 1'b0;                           //Reset: megszakítás tiltása
   else
      if (tc_wr)
         tie <= s_mst2slv_data[7];           //Parancs regiszter írás
end


//******************************************************************************
//* Az elõosztó.                                                               *
//******************************************************************************
//Az elõosztás értékének kiválasztása.
reg [15:0] ps_val;

always @(*)
begin
   case (tps)
      3'b000: ps_val <= 16'd0;               // ÷    1 elõosztás
      3'b001: ps_val <= 16'd15;              // ÷   16 elõosztás
      3'b010: ps_val <= 16'd63;              // ÷   64 elõosztás
      3'b011: ps_val <= 16'd255;             // ÷  256 elõosztás
      3'b100: ps_val <= 16'd1023;            // ÷ 1024 elõosztás
      3'b101: ps_val <= 16'd4095;            // ÷ 4096 elõosztás
      3'b110: ps_val <= 16'd16383;           // ÷16384 elõosztás
      3'b111: ps_val <= 16'd65535;           // ÷65536 elõosztás
   endcase
end

//Az elõosztó számlálója.
reg [15:0] ps_cnt;
reg        ps_cnt_clr;

assign ps_tc = (ps_cnt == 16'd0);            //Az elõosztó végállapotának jelzése

always @(posedge clk)
begin
   ps_cnt_clr <= tc_wr;
end

always @(posedge clk)
begin
   if (rst)
      ps_cnt <= 16'd0;                       //Reset: ÷1 elõosztás
   else
      if (ps_cnt_clr)
         ps_cnt <= ps_val;                   //Parancs regiszter írás: újratöltés
      else
         if (ten)
            if (ps_tc)
               ps_cnt <= ps_val;             //Végállapot: újratöltés
            else
               ps_cnt <= ps_cnt - 16'd1;     //Egyébként lefele számlál
end
      

//******************************************************************************
//* Az idõzítõ egy 8 bites lefelé számláló.                                    *
//******************************************************************************     
reg [7:0] tmr_cnt;      

assign tmr_cnt_tc = (tmr_cnt == 8'h00);      //A nulla végértéket jelezzük

always @ (posedge clk) 
begin                     
   if (rst)
      tmr_cnt <= 8'hff;                      //Reset: max. érték betöltése
   else 
      if (tr_wr)
         tmr_cnt <= s_mst2slv_data;          //Új kezdõérték betöltése közvetlenül
      else
         if (ten && ps_tc)                   //Ha az idõzítõ engedélyezett és az
            if (tmr_cnt_tc)                  //elõosztó végállapotban van:
               tmr_cnt <= tr_reg;            // -idõzítés végén, 0-nál újratöltés   
            else
               tmr_cnt <= tmr_cnt - 8'd1;    // -egyébként számol lefelé
end


//******************************************************************************
//* A státusz regiszter bitjei.                                                *
//****************************************************************************** 
reg tout;
     
//Idõzítés lejárt jelzés a státusz regiszterben.
//A beállítás nagyobb prioritású, mint a törlés.
always @ (posedge clk) 
begin                     
   if (rst)
      tout <= 1'b0;                          //Reset: a TOUT jelzés törlése
   else 
      if (ps_tc && tmr_cnt_tc && ten)        //Ha az idõzítõ engedélyezett és
         tout <= 1'b1;                       //elérte a végértéket, akkor jelzés 
      else
         if (ts_rd)
            tout <= 1'b0;                    //A státusz reg. olvasása törli
end

//Megszakításkérés az idõzítés lejártakor, ha engedélyezett.
assign irq = tie & tout;

//A 8 bites státusz információ összeállítása az egyedi bitek alapján.
//Az IRQ és a TOUT bit majdnem azonos jelentésû, de az IRQ bit magába
//foglalja az ITEN állapotát is. 
wire [7:0] status_reg = {irq, tps, 1'b0, tout, trep, ten};


//******************************************************************************
//* Az olvasási adatbusz meghajtása.                                           *
//****************************************************************************** 
always @(*)
begin
   case ({ts_rd, tm_rd})
      2'b01  : s_slv2mst_data <= tmr_cnt;       //Idõzítõ számlálója
      2'b10  : s_slv2mst_data <= status_reg;    //Státusz regiszter
      default: s_slv2mst_data <= 8'd0;          //Inaktív 0 érték, ha nincs olvasás
   endcase
end

endmodule
