`timescale 1ns / 1ps

//******************************************************************************
//* Soros kommunik�ci�t biztos�t� slave USRT perif�ria.                        *
//*                                                                            *
//* Az USRT kommunik�ci� keretezett form�tumot haszn�l: 1 START bit (0),       *
//* 8 adatbit (LSb el�sz�r) �s 1 STOP bit (1), a soros adatvonal inakt�v       *
//* szintje 1. Az USRT �rajel hat�roza meg az adat�tviteli sebess�get, az      *
//* �rajelet a master egys�g adja ki a slave egys�g fel�. Az ad� az USRT       *
//* �rajel felfut� �l�re adja ki a k�vetkez� bitet, melyet a vev� a lefut�     *
//* �lre mintav�telez. A vev� csak a kerethiba mentes karaktereket t�rolja     *
//* (STOP bit = 1), a hib�s karaktereket eldobja.                              *
//*                                                                            *
//* A perif�ria c�me param�ter �tad�ssal �ll�that� be a fels� szint� modulban  *
//* az USRT modul megp�ld�nyos�t�sakor. A szint�zis m�r ennek megfelele�en az  *
//* aktu�lis BASEADDR b�zisc�mmel t�rt�nik.                                    *
//*                                                                            *
//* A programoz�i fel�let:                                                     *
//*                                                                            *
//* C�m         T�pus   Bitek                                                  *
//* BASEADDR+0          Kontroll regiszter                                     *
//*             WR      -     -     -     -     RXCLR TXCLR RXEN  TXEN         *
//*             RD      0     0     0     0     0     0     RXEN  TXEN         *
//* BASEADDR+1          FIFO st�tusz regiszter                                 *
//*             RD      0     0     0     0     RXFUL RXNE  TXNF  TXEMP        *
//* BASEADDR+2          Megszak�t�s enged�lyez� regiszter                      *
//*             WR      -     -     -     -     RXFUL RXNE  TXNF  TXEMP        *
//*             RD      0     0     0     0     RXFUL RXNE  TXNF  TXEMP        *
//* BASEADDR+3  WR      Az ad�si FIFO �r�sa (ha TXNF=1)                        *
//* BASEADDR+3  RD      A v�teli FIFO olvas�sa (ha RXNE=1)                     *
//*                     D7    D6    D5    D4    D3    D2    D1    D0           *
//******************************************************************************
module slave_usrt #(
   //A perif�ria b�zisc�me.
   parameter BASEADDR = 8'hff
) (
   //�rajel �s reset.
   input  wire       clk,              //�rajel
   input  wire       rst,              //Reset jel
   
   //A soros interf�sz jelei.
   input  wire       usrt_clk,         //USRT �rajel
   input  wire       usrt_rxd,         //Soros adatbemenet
   output wire       usrt_txd,         //Soros adatkimenet
   
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
wire psel = ((s_mst2slv_addr >> 2) == (BASEADDR >> 2));

//A kontroll regiszter �r�s�nak �s olvas�s�nak jelz�se.
wire ctrl_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b00);
wire ctrl_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b00);

//A FIFO st�tusz regiszter olvas�s�nak jelz�se.
wire stat_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b01);

//A megszak�t�s enged�lyez� regiszter �r�s�nak �s olvas�s�nak jelz�se.
wire ie_reg_wr   = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b10);
wire ie_reg_rd   = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b10);

//Az adatregiszter �r�s�nak �s olvas�s�nak jelz�se.
wire data_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b11);
wire data_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b11);


//******************************************************************************
//* A kontroll regiszter.                                                      *
//******************************************************************************
//A kontroll regiszter TXEN bitje (ad�s enged�lyez�s).
reg tx_enable;

always @(posedge clk)
begin
   if (rst)
      tx_enable <= 1'b0;
   else
      if (ctrl_reg_wr)
         tx_enable <= s_mst2slv_data[0];
end

//A kontroll regiszter RXEN bitje (v�tel enged�lyez�s).
reg rx_enable;

always @(posedge clk)
begin
   if (rst)
      rx_enable <= 1'b0;
   else
      if (ctrl_reg_wr)
         rx_enable <= s_mst2slv_data[1];
end

//A kontroll regiszter TXCLR bitje (ad�si FIFO t�rl�se).
wire tx_fifo_clr = rst | (ctrl_reg_wr & s_mst2slv_data[2]);

//A kontroll regiszter RXCLR bitje (v�teli FIFO t�rl�se).
wire rx_fifo_clr = rst | (ctrl_reg_wr & s_mst2slv_data[3]);

//A kontroll regiszter vissaolvashat� bitjei.
wire [7:0] ctrl_reg_dout = {6'b000000, rx_enable, tx_enable};


//******************************************************************************
//* A FIFO st�tusz regiszter.                                                  *
//******************************************************************************
wire [7:0] stat_reg;
wire       tx_fifo_empty;
wire       tx_fifo_full;
wire       rx_fifo_empty;
wire       rx_fifo_full;

//A FIFO st�tusz regiszter bitjei.
assign stat_reg[0]   = tx_fifo_empty;
assign stat_reg[1]   = ~tx_fifo_full;
assign stat_reg[2]   = ~rx_fifo_empty;
assign stat_reg[3]   = rx_fifo_full;
assign stat_reg[7:4] = 4'b0000;


//******************************************************************************
//* A megszak�t�s enged�lyez� regiszter.                                       *
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

//A megszak�t�sk�r� kimenet meghajt�sa.
assign irq = |(stat_reg[3:0] & ie_reg);


//******************************************************************************
//* Az olvas�si adatbusz meghajt�sa.                                           *
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
//* �ldetekt�l�s az USRT �rajelen �s az RXD vonal k�sleltet�se.                *
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
//* USRT vev�.                                                                 *
//******************************************************************************
//A v�teli shiftregiszter.
reg  [9:0] rx_shr;
//A v�teli shiftregisztert alap�llapotba �ll�t� jel:
// - rendszer reset vagy
// - a v�tel nincs enged�lyezve vagy
// - a START bit 0
wire       rx_shr_rst = rst | ~rx_enable | ~rx_shr[0];
//A vett adat �rv�nyess�g�nek jelz�se (START bit 0, STOP bit 1).
wire       rx_valid   = ~rx_shr[0] & rx_shr[9];

//A v�teli shiftregiszter. Az USRT �rajel lefut� �l�re
//bel�ptetj�k az RXD vonal aktu�lis �rt�k�t a regiszterbe.
always @(posedge clk)
begin
   if (rx_shr_rst)
      rx_shr <= 10'b11_1111_1111;
   else
      if (usrt_clk_falling)
         rx_shr <= {rxd_samples[1], rx_shr[9:1]};
end

//V�teli FIFO.
fifo rx_fifo(
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rx_fifo_clr),                  //Reset jel
   
   //Adatvonalak.
   .data_in(rx_shr[8:1]),              //A FIFO-ba �rand� adat
   .data_out(rx_data),                 //A FIFO-b�l kiolvasott adat
   
   //Vez�rl� bemenetek.
   .write(rx_valid),                   //�r�s enged�lyez� jel
   .read(data_reg_rd),                 //Olvas�s enged�lyez� jel
   
   //St�tusz kimenetek.
   .empty(rx_fifo_empty),              //A FIFO �res
   .full(rx_fifo_full)                 //A FIFO tele van
);


//******************************************************************************
//* USRT ad�.                                                                  *
//******************************************************************************
//Az ad�si shiftregiszter.
reg  [8:0] tx_shr;
//Az elk�ld�tt bitek sz�ml�l�ja.
reg  [3:0] tx_cnt;
//Az ad�si FIFO-b�l beolvasott adat.
wire [7:0] tx_fifo_dout;
//Az ad�si shiftregiszter �s a sz�ml�l� bet�lt� jele:
// - az ad�s enged�lyezve van �s
// - az el�z� keret utols� bitj�t is elk�ldt�k (tx_cnt = 9) �s
// - az ad�si FIFO nem �res
wire       tx_load = tx_enable & (tx_cnt == 4'd9) & ~tx_fifo_empty;

//Ad�si FIFO.
fifo tx_fifo(
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(tx_fifo_clr),                  //Reset jel
   
   //Adatvonalak.
   .data_in(s_mst2slv_data),           //A FIFO-ba �rand� adat
   .data_out(tx_fifo_dout),            //A FIFO-b�l kiolvasott adat
   
   //Vez�rl� bemenetek.
   .write(data_reg_wr),                //�r�s enged�lyez� jel
   .read(tx_load & usrt_clk_rising),   //Olvas�s enged�lyez� jel
   
   //St�tusz kimenetek.
   .empty(tx_fifo_empty),              //A FIFO �res
   .full(tx_fifo_full)                 //A FIFO tele van
);

//Az ad�si shiftregiszter. Az USRT �rajel felfut� �l�re
//t�rt�nik a bet�lt�s vagy a l�ptet�s.
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

//Az elk�ld�tt bitek sz�ml�l�ja.
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

//Az USRT interf�sz TXD vonal�nak meghajt�sa.
assign usrt_txd = tx_shr[0];


endmodule
