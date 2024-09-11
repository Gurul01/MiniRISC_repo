`timescale 1ns / 1ps

//******************************************************************************
//* Soros kommunikációt biztosító slave USRT periféria.                        *
//*                                                                            *
//* Az USRT kommunikáció keretezett formátumot használ: 1 START bit (0),       *
//* 8 adatbit (LSb elõször) és 1 STOP bit (1), a soros adatvonal inaktív       *
//* szintje 1. Az USRT órajel határoza meg az adatátviteli sebességet, az      *
//* órajelet a master egység adja ki a slave egység felé. Az adó az USRT       *
//* órajel felfutó élére adja ki a következõ bitet, melyet a vevõ a lefutó     *
//* élre mintavételez. A vevõ csak a kerethiba mentes karaktereket tárolja     *
//* (STOP bit = 1), a hibás karaktereket eldobja.                              *
//*                                                                            *
//* A periféria címe paraméter átadással állítható be a felsõ szintû modulban  *
//* az USRT modul megpéldányosításakor. A szintézis már ennek megfeleleõen az  *
//* aktuális BASEADDR báziscímmel történik.                                    *
//*                                                                            *
//* A programozói felület:                                                     *
//*                                                                            *
//* Cím         Típus   Bitek                                                  *
//* BASEADDR+0          Kontroll regiszter                                     *
//*             WR      -     -     -     -     RXCLR TXCLR RXEN  TXEN         *
//*             RD      0     0     0     0     0     0     RXEN  TXEN         *
//* BASEADDR+1          FIFO státusz regiszter                                 *
//*             RD      0     0     0     0     RXFUL RXNE  TXNF  TXEMP        *
//* BASEADDR+2          Megszakítás engedélyezõ regiszter                      *
//*             WR      -     -     -     -     RXFUL RXNE  TXNF  TXEMP        *
//*             RD      0     0     0     0     RXFUL RXNE  TXNF  TXEMP        *
//* BASEADDR+3  WR      Az adási FIFO írása (ha TXNF=1)                        *
//* BASEADDR+3  RD      A vételi FIFO olvasása (ha RXNE=1)                     *
//*                     D7    D6    D5    D4    D3    D2    D1    D0           *
//******************************************************************************
module slave_usrt #(
   //A periféria báziscíme.
   parameter BASEADDR = 8'hff
) (
   //Órajel és reset.
   input  wire       clk,              //Órajel
   input  wire       rst,              //Reset jel
   
   //A soros interfész jelei.
   input  wire       usrt_clk,         //USRT órajel
   input  wire       usrt_rxd,         //Soros adatbemenet
   output wire       usrt_txd,         //Soros adatkimenet
   
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
wire psel = ((s_mst2slv_addr >> 2) == (BASEADDR >> 2));

//A kontroll regiszter írásának és olvasásának jelzése.
wire ctrl_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b00);
wire ctrl_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b00);

//A FIFO státusz regiszter olvasásának jelzése.
wire stat_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b01);

//A megszakítás engedélyezõ regiszter írásának és olvasásának jelzése.
wire ie_reg_wr   = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b10);
wire ie_reg_rd   = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b10);

//Az adatregiszter írásának és olvasásának jelzése.
wire data_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b11);
wire data_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b11);


//******************************************************************************
//* A kontroll regiszter.                                                      *
//******************************************************************************
//A kontroll regiszter TXEN bitje (adás engedélyezés).
reg tx_enable;

always @(posedge clk)
begin
   if (rst)
      tx_enable <= 1'b0;
   else
      if (ctrl_reg_wr)
         tx_enable <= s_mst2slv_data[0];
end

//A kontroll regiszter RXEN bitje (vétel engedélyezés).
reg rx_enable;

always @(posedge clk)
begin
   if (rst)
      rx_enable <= 1'b0;
   else
      if (ctrl_reg_wr)
         rx_enable <= s_mst2slv_data[1];
end

//A kontroll regiszter TXCLR bitje (adási FIFO törlése).
wire tx_fifo_clr = rst | (ctrl_reg_wr & s_mst2slv_data[2]);

//A kontroll regiszter RXCLR bitje (vételi FIFO törlése).
wire rx_fifo_clr = rst | (ctrl_reg_wr & s_mst2slv_data[3]);

//A kontroll regiszter vissaolvasható bitjei.
wire [7:0] ctrl_reg_dout = {6'b000000, rx_enable, tx_enable};


//******************************************************************************
//* A FIFO státusz regiszter.                                                  *
//******************************************************************************
wire [7:0] stat_reg;
wire       tx_fifo_empty;
wire       tx_fifo_full;
wire       rx_fifo_empty;
wire       rx_fifo_full;

//A FIFO státusz regiszter bitjei.
assign stat_reg[0]   = tx_fifo_empty;
assign stat_reg[1]   = ~tx_fifo_full;
assign stat_reg[2]   = ~rx_fifo_empty;
assign stat_reg[3]   = rx_fifo_full;
assign stat_reg[7:4] = 4'b0000;


//******************************************************************************
//* A megszakítás engedélyezõ regiszter.                                       *
//******************************************************************************
reg  [3:0] ie_reg;
wire [7:0] ie_reg_dout = {4'b0000, ie_reg};

always @(posedge clk)
begin
   if (rst)
      ie_reg <= 4'b0000;
   else
      if (ie_reg_wr)
         ie_reg <= s_mst2slv_data[3:0];
end

//A megszakításkérõ kimenet meghajtása.
assign irq = |(stat_reg[3:0] & ie_reg);


//******************************************************************************
//* Az olvasási adatbusz meghajtása.                                           *
//******************************************************************************
wire [7:0] rx_data;
wire [3:0] dout_sel = {data_reg_rd, ie_reg_rd, stat_reg_rd, ctrl_reg_rd};

always @(*)
begin
   case (dout_sel)
      4'b0001: s_slv2mst_data <= ctrl_reg_dout;
      4'b0010: s_slv2mst_data <= stat_reg;
      4'b0100: s_slv2mst_data <= ie_reg_dout;
      4'b1000: s_slv2mst_data <= rx_data;
      default: s_slv2mst_data <= 8'd0;
   endcase
end


//******************************************************************************
//* Éldetektálás az USRT órajelen és az RXD vonal késleltetése.                *
//******************************************************************************
(* shreg_extract = "no" *)
(* register_balancing = "no" *)
(* register_duplication = "no" *)
(* equivalent_register_removal = "no" *)
reg  [2:0] usrt_clk_samples;
wire       usrt_clk_rising  = (usrt_clk_samples[2:1] == 2'b01);
wire       usrt_clk_falling = (usrt_clk_samples[2:1] == 2'b10);

always @(posedge clk)
begin
   usrt_clk_samples <= {usrt_clk_samples[1:0], usrt_clk};
end

(* shreg_extract = "no" *)
(* register_balancing = "no" *)
(* register_duplication = "no" *)
(* equivalent_register_removal = "no" *)
reg  [1:0] rxd_samples;

always @(posedge clk)
begin
   rxd_samples <= {rxd_samples[0], usrt_rxd};
end


//******************************************************************************
//* USRT vevõ.                                                                 *
//******************************************************************************
//A vételi shiftregiszter.
reg  [9:0] rx_shr;
//A vételi shiftregisztert alapállapotba állító jel:
// - rendszer reset vagy
// - a vétel nincs engedélyezve vagy
// - a START bit 0
wire       rx_shr_rst = rst | ~rx_enable | ~rx_shr[0];
//A vett adat érvényességének jelzése (START bit 0, STOP bit 1).
wire       rx_valid   = ~rx_shr[0] & rx_shr[9];

//A vételi shiftregiszter. Az USRT órajel lefutó élére
//beléptetjük az RXD vonal aktuális értékét a regiszterbe.
always @(posedge clk)
begin
   if (rx_shr_rst)
      rx_shr <= 10'b11_1111_1111;
   else
      if (usrt_clk_falling)
         rx_shr <= {rxd_samples[1], rx_shr[9:1]};
end

//Vételi FIFO.
fifo rx_fifo(
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rx_fifo_clr),                  //Reset jel
   
   //Adatvonalak.
   .data_in(rx_shr[8:1]),              //A FIFO-ba írandó adat
   .data_out(rx_data),                 //A FIFO-ból kiolvasott adat
   
   //Vezérlõ bemenetek.
   .write(rx_valid),                   //Írás engedélyezõ jel
   .read(data_reg_rd),                 //Olvasás engedélyezõ jel
   
   //Státusz kimenetek.
   .empty(rx_fifo_empty),              //A FIFO üres
   .full(rx_fifo_full)                 //A FIFO tele van
);


//******************************************************************************
//* USRT adó.                                                                  *
//******************************************************************************
//Az adási shiftregiszter.
reg  [8:0] tx_shr;
//Az elküldött bitek számlálója.
reg  [3:0] tx_cnt;
//Az adási FIFO-ból beolvasott adat.
wire [7:0] tx_fifo_dout;
//Az adási shiftregiszter és a számláló betöltõ jele:
// - az adás engedélyezve van és
// - az elõzõ keret utolsó bitjét is elküldtük (tx_cnt = 9) és
// - az adási FIFO nem üres
wire       tx_load = tx_enable & (tx_cnt == 4'd9) & ~tx_fifo_empty;

//Adási FIFO.
fifo tx_fifo(
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(tx_fifo_clr),                  //Reset jel
   
   //Adatvonalak.
   .data_in(s_mst2slv_data),           //A FIFO-ba írandó adat
   .data_out(tx_fifo_dout),            //A FIFO-ból kiolvasott adat
   
   //Vezérlõ bemenetek.
   .write(data_reg_wr),                //Írás engedélyezõ jel
   .read(tx_load & usrt_clk_rising),   //Olvasás engedélyezõ jel
   
   //Státusz kimenetek.
   .empty(tx_fifo_empty),              //A FIFO üres
   .full(tx_fifo_full)                 //A FIFO tele van
);

//Az adási shiftregiszter. Az USRT órajel felfutó élére
//történik a betöltés vagy a léptetés.
always @(posedge clk)
begin
   if (rst)
      tx_shr <= 9'b1_1111_1111;
   else
      if (usrt_clk_rising)
         if (tx_load)
            tx_shr <= {tx_fifo_dout, 1'b0};
         else
            tx_shr <= {1'b1, tx_shr[8:1]};
end

//Az elküldött bitek számlálója.
always @(posedge clk)
begin
   if (rst)
      tx_cnt <= 4'd9;
   else
      if (usrt_clk_rising)
         if (tx_load)
            tx_cnt <= 4'd0;
         else
            if (tx_cnt != 4'd9)
               tx_cnt <= tx_cnt + 4'd1;
end

//Az USRT interfész TXD vonalának meghajtása.
assign usrt_txd = tx_shr[0];


endmodule
