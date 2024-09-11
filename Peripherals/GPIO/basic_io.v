`timescale 1ns / 1ps

//******************************************************************************
//* Egyszerû 8 bites kétirányú I/O modul.                                      *
//*                                                                            *
//* A periféria címe paraméter átadással állítható be a felsõ szintû modulban  *
//* a GPIO modul megpéldányosításakor. A szintézis már ennek megfeleleõen az   *
//* aktuális BASEADDR báziscímmel történik.                                    *
//*                                                                            *
//* A BASEADDR cím szolgál a kimeneti regiszter írására és visszaolvasására,   *
//* a BASEADDR+1 címrõl olvasható be a GPIO lábak aktuális értéke, valamint    *
//* a BASEADDR+2 cím szolgál az irány regiszter írására és visszaolvasására.   * 
//*                                                                            *
//* Tehát a BASIC_IO periféria a szokásos mikrovezérlõk port GPIO funkcióját   *
//* valósítja meg. Természetesen egy adott idõben egy GPIO vonal vagy csak     * 
//* kimenet, vagy csak bemenet lehet, még ha ezt a programból dinamikusan      * 
//* állíthatjuk is. Sõt különös figyelmet igényel egy áramkörön belül az adott *
//* vonal külsõ interfésze, elkerülendõ az ellentétes állapotú kimenetek       *
//* összekapcsolását!                                                          *
//*                                                                            *
//* Egyetlen IC láb (=Port pin) funkciója grafikusan ábrázolva:                *
//*                                                                            *
//*                   -------               Vcc                                *
//*    DIR         >--|D   Q|---------|     |                                  *
//*                   |     |  |      |     |                                  *
//*                   |>    |  |      |    |-|  Rf felhúzó ellenállás          *
//*                   -------  |      |    | |                                 *
//*    DIR olvasás <-----------|    |\|    |-|                                 *
//*                   -------       | \     |                                  *
//*    adat KI     >--|D   Q|-------|  >-------------<-> az IC programozható   *
//*                   |     |  |    | /        |         IO lába               *
//*                   |>    |  |    |/         |                               *
//*                   -------  |               |                               *
//*    KI olvasás  <-----------|               |                               *
//*                   -------                  |                               *
//*    IO láb olv. <--|Q   D|------------------|                               *
//*                   |     |                                                  *
//*                   |    <|                                                  *
//*                   -------                                                  *
//*                                                                            *
//* A programozói felület:                                                     *
//*                                                                            *
//* Cím         Típus   Bitek                                                  *
//* BASEADDR+0  RD/WR   Kimeneti adatregiszter                                 *
//*                     OUT7  OUT6  OUT5  OUT4  OUT3  OUT2  OUT1  OUT0         *
//* BASEADDR+1  RD      Adat az IO lábakon                                     *  
//*                     IN7   IN6   IN5   IN4   IN3   IN2   IN1   IN0          *
//* BASEADDR+2  RD/WR   Az IO láb irányának beállítása (0: be, 1:ki)           *
//*                     DIR7  DIR6  DIR5  DIR4  DIR3  DIR2  DIR1  DIR0         *
//* BASEADDR+3  RD      Nem használt, olvasás esetén mindig 0                  *
//*                                                                            *
//* A processzor írási (WRITE) ciklusának idõdiagramja:                        *
//* Az írási ciklust az 1 órajel ciklus ideig aktív S_MST2SLV_WR jel jelzi. Az *
//* írási ciklus ideje alatt a cím és a kimeneti adat stabil.                  *
//*                                                                            *
//*                     --------          --------          --------           *
//* CLK                |        |        |        |        |        |          *
//*                ----          --------          --------          ----      *
//*                                        ------------------                  *
//* S_MST2SLV_WR                          /                  \                 *
//*                -----------------------                    -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_MST2SLV_ADDR                        X   ÉRVÉNYES CÍM   X                 *
//*                ----------------------- ------------------ -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_MST2SLV_DATA                        X   ÉRVÉNYES ADAT  X                 *
//*                ----------------------- ------------------ -----------      *
//*                                                        ^                   *
//*                                Az írási parancs végrehajtása itt történik. *
//*                                                                            *
//* A processzor olvasási (READ) ciklusának idõdiagramja:                      *
//* Az olvasási ciklust az 1 órajel ciklus ideig aktív S_MST2SLV_RD jel jelzi. *
//* Az olvasási ciklus ideje alatt a cím stabil és a kiválasztott periféria az *
//* olvasási adatbuszra kapuzza az adatot. Az olvasási ciklus elõtt és után    *
//* az olvasási adatbusz értéke inaktív 0 kell, hogy legyen.                   *
//*                                                                            *
//*                     --------          --------          --------           *
//* CLK                |        |        |        |        |        |          *
//*                ----          --------          --------          ----      *
//*                                        ------------------                  *
//* S_MST2SLV_RD                          /                  \                 *
//*                -----------------------                    -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_MST2SLV_ADDR                        X   ÉRVÉNYES CÍM   X                 *
//*                ----------------------- ------------------ -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_SLV2MST_DATA           0            X   ÉRVÉNYES ADAT  X       0         *
//*                ----------------------- ------------------ -----------      *
//*                                                        ^                   *
//*                              A bemeneti adat mintavételezése itt történik. *   
//******************************************************************************
module basic_io #(
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
   
   //A GPIO interfész jelei.
   output wire [7:0] gpio_out,         //Az IO lábakra kiírandó adat
   input  wire [7:0] gpio_in,          //Az IO lábak aktuális értéke
   output wire [7:0] gpio_dir          //A kimeneti meghajtó engedélyezõ jele
);
  
//******************************************************************************
//* Címdekódolás.                                                              *
//******************************************************************************
//A periféria kiválasztó jele.
wire psel = ((s_mst2slv_addr >> 2) == (BASEADDR >> 2));

//A kimeneti adatregiszter írásának és olvasásának jelzése.
wire out_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b00);
wire out_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b00);

//A bemeneti adatregiszter olvasásának jelzése.
wire in_reg_rd  = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b01);

//Az irány kiválasztó regiszter írásának és olvasásának jelzése.
wire dir_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b10);
wire dir_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b10);


//******************************************************************************
//* A kimeneti adatregiszter.                                                  *
//******************************************************************************
reg [7:0] out_reg;

always @(posedge clk)
begin
   if (rst)
      out_reg <= 8'd0;                 //Reset esetén töröljük a regisztert
   else
      if (out_reg_wr)
         out_reg <= s_mst2slv_data;    //Kimeneti adatregiszter írása
end

//Az IO lábak meghajtása.
assign gpio_out = out_reg;


//******************************************************************************
//* A bemeneti adatregiszter.                                                  *
//******************************************************************************
reg [7:0] in_reg;

always @(posedge clk)
begin
   if (rst)
      in_reg <= 8'd0;                  //Reset esetén töröljük a regisztert
   else
      in_reg <= gpio_in;               //Egyébként folyamatosan mintavételezzük
end                                    //az IO lábak értékét


//******************************************************************************
//* Az irány kiválasztó regiszter.                                             *
//* 0: az adott IO láb iránya bemenet                                          *
//* 1: az adott IO láb iránya kimenet                                          *
//******************************************************************************
reg [7:0] dir_reg;

always @(posedge clk)
begin
   if (rst)
      dir_reg <= 8'd0;                 //Reset esetén minden IO láb bemenet
   else
      if (dir_reg_wr)
         dir_reg <= s_mst2slv_data;    //Irány kiválasztó regiszter írása
end

//Az irány kiválasztó kimenet meghajtása.
assign gpio_dir = dir_reg;


//******************************************************************************
//* A processzor olvasási adatbuszának meghajtása. Az olvasási adatbuszra csak *
//* az olvasás ideje alatt kapcsoljuk rá a kért értéket, egyébként egy inaktív *
//* nulla érték jelenik meg rajta (elosztott busz multiplexer funkció).        *
//******************************************************************************
wire [2:0] dout_sel = {dir_reg_rd, in_reg_rd, out_reg_rd};

always @(*)
begin
   case (dout_sel)
      3'b001 : s_slv2mst_data <= out_reg;    //A kimeneti adatregiszter olvasása
      3'b010 : s_slv2mst_data <= in_reg;     //A bemeneti adatregiszter olvasása
      3'b100 : s_slv2mst_data <= dir_reg;    //Az irány kiválasztó reg. olvasása
      default: s_slv2mst_data <= 8'd0;       //Egyébként inaktív nulla érték
   endcase
end

endmodule
