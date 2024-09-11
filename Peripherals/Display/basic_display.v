`timescale 1ns / 1ps

//******************************************************************************
//* Alap perif�ria a h�tszegmenses �s a pontm�trix kijelz� illeszt�s�hez.      *
//* Az egyes szegmensek egyedileg vez�relhet�k, a kijelz�k id�multiplexelt     *
//* vez�rl�s�t a perif�ria elv�gzi.                                            *
//*                                                                            *
//* A perif�ria c�me param�ter �tad�ssal �ll�that� be a fels� szint� modulban  *
//* a megp�ld�nyos�t�skor. A szint�zis m�r ennek megfelele�en az aktu�lis      *
//* BASEADDR b�zisc�mmel t�rt�nik. A perif�ria 16 b�jtos c�mtartom�nyt ig�nyel,*
//* ebb�l csak az als� 9 b�jt van felhaszn�lva.                                *
//*                                                                            *
//* A programoz�i fel�let:                                                     *
//*                                                                            *
//* C�m         T�pus   Bitek                                                  *
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
   
   //A kijelz�k vez�rl�s�hez sz�ks�ges jelek.
   output wire [7:0] seg_n,            //Szegmens vez�rl� jelek (akt�v alacsony)
   output wire [3:0] dig_n,            //Digit kiv�laszt� jelek (akt�v alacsony)
   output wire [4:0] col_n             //Oszlop kiv�laszt� jelek (akt�v alacsony)
);

//******************************************************************************
//* C�mdek�dol�s.                                                              *
//******************************************************************************
//A perif�ria kiv�laszt� jele.
wire psel = ((s_mst2slv_addr >> 4) == (BASEADDR >> 4));


//******************************************************************************
//* Sz�ml�l� a mem�ria t�rl�s�hez.                                             *
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
//* A regisztereket egy 16 x 8 bites elosztott RAM-mal val�s�tjuk meg.         *
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

//Az olvas�si adatbusz meghajt�sa.
assign s_slv2mst_data = (psel & s_mst2slv_rd) ? registers[reg_addr] : 8'd0;


//******************************************************************************
//* A rendszer�rajel leoszt�sa 16385-tel (2^14 + 1).                           *
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
//* A RAM olvas�si c�msz�ml�l�ja.                                              *
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

//A szegmens vez�rl� jelek meghajt�sa.
assign seg_n = ~registers[rd_addr];


//******************************************************************************
//* A digit �s oszlop kiv�laszt� jeleket el��ll�t� shiftregiszter.             *
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

//A digit �s oszlop kiv�laszt� jelek meghajt�sa.
assign dig_n = ~shr[3:0];
assign col_n = ~shr[8:4];


endmodule
