`timescale 1ns / 1ps

//******************************************************************************
//* Alap periféria a hétszegmenses és a pontmátrix kijelzõ illesztéséhez.      *
//* Az egyes szegmensek egyedileg vezérelhetõk, a kijelzõk idõmultiplexelt     *
//* vezérlését a periféria elvégzi.                                            *
//*                                                                            *
//* A periféria címe paraméter átadással állítható be a felsõ szintû modulban  *
//* a megpéldányosításkor. A szintézis már ennek megfeleleõen az aktuális      *
//* BASEADDR báziscímmel történik. A periféria 16 bájtos címtartományt igényel,*
//* ebbõl csak az alsó 9 bájt van felhasználva.                                *
//*                                                                            *
//* A programozói felület:                                                     *
//*                                                                            *
//* Cím         Típus   Bitek                                                  *
//* BASEADDR+0  R/W     DIG0 adatregiszter                                     *
//* BASEADDR+1  R/W     DIG1 adatregiszter                                     *
//* BASEADDR+2  R/W     DIG2 adatregiszter                                     *
//* BASEADDR+3  R/W     DIG3 adatregiszter                                     *
//*                     DP    G     F     E     D     C     B     A            *
//* BASEADDR+4  R/W     COL0 adatregiszter                                     *
//* BASEADDR+5  R/W     COL1 adatregiszter                                     *
//* BASEADDR+6  R/W     COL2 adatregiszter                                     *
//* BASEADDR+7  R/W     COL3 adatregiszter                                     *
//* BASEADDR+8  R/W     COL4 adatregiszter                                     *
//*                     -     ROW7  ROW6  ROW5  ROW4  ROW3  ROW2  ROW1         *
//******************************************************************************
module basic_display #(
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
   output wire [7:0] s_slv2mst_data,   //Olvasási adatbusz
   
   //A kijelzõk vezérléséhez szükséges jelek.
   output wire [7:0] seg_n,            //Szegmens vezérlõ jelek (aktív alacsony)
   output wire [3:0] dig_n,            //Digit kiválasztó jelek (aktív alacsony)
   output wire [4:0] col_n             //Oszlop kiválasztó jelek (aktív alacsony)
);

//******************************************************************************
//* Címdekódolás.                                                              *
//******************************************************************************
//A periféria kiválasztó jele.
wire psel = ((s_mst2slv_addr >> 4) == (BASEADDR >> 4));


//******************************************************************************
//* Számláló a memória törléséhez.                                             *
//******************************************************************************
reg  [4:0] rst_cnt;
wire       mem_clr = (rst_cnt[4] == 0);

always @(posedge clk)
begin
   if (rst)
      rst_cnt <= 5'd0;
   else
      if (mem_clr)
         rst_cnt <= rst_cnt + 5'd1;
end


//******************************************************************************
//* A regisztereket egy 16 x 8 bites elosztott RAM-mal valósítjuk meg.         *
//******************************************************************************
(* ram_style = "distributed" *)
reg  [7:0] registers [15:0];
wire [3:0] reg_addr = (mem_clr) ? rst_cnt[3:0] : s_mst2slv_addr[3:0];
wire [7:0] reg_din  = (mem_clr) ? 8'd0         : s_mst2slv_data;
wire       reg_wr   = mem_clr | (psel & s_mst2slv_wr);

always @(posedge clk)
begin
   if (reg_wr)
      registers[reg_addr] <= reg_din;
end

//Az olvasási adatbusz meghajtása.
assign s_slv2mst_data = (psel & s_mst2slv_rd) ? registers[reg_addr] : 8'd0;


//******************************************************************************
//* A rendszerórajel leosztása 16385-tel (2^14 + 1).                           *
//******************************************************************************
reg  [14:0] clk_divider;
wire        clk_divider_tc = clk_divider[14];

always @(posedge clk)
begin
   if (rst || clk_divider_tc)
      clk_divider <= 15'd0;
   else
      clk_divider <= clk_divider + 15'd1;
end


//******************************************************************************
//* A RAM olvasási címszámlálója.                                              *
//******************************************************************************
reg [3:0] rd_addr;

always @(posedge clk)
begin
   if (rst)
      rd_addr <= 4'd0;
   else
      if (clk_divider_tc)
         if (rd_addr[3])
            rd_addr <= 4'd0;
         else
            rd_addr <= rd_addr + 4'd1;
end

//A szegmens vezérlõ jelek meghajtása.
assign seg_n = ~registers[rd_addr];


//******************************************************************************
//* A digit és oszlop kiválasztó jeleket elõállító shiftregiszter.             *
//******************************************************************************
reg [8:0] shr;

always @(posedge clk)
begin
   if (rst)
      shr <= 9'b00000_0001;
   else
      if (clk_divider_tc)
         shr <= {shr[7:0], shr[8]};
end

//A digit és oszlop kiválasztó jelek meghajtása.
assign dig_n = ~shr[3:0];
assign col_n = ~shr[8:4];


endmodule
