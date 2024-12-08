`timescale 1ns / 1ps

//******************************************************************************
//* PS/2 billenty�zet interf�sz perif�ria. Az adatregiszterb�l a lenyomott     *
//* billenty� ASCII k�dja olvashat� ki.                                        *
//*                                                                            *
//* A programoz�i fel�let:                                                     *
//*                                                                            *
//* C�m         T�pus   Bitek                                                  *
//* BASEADDR+0          PS/2 billenty�zet kontroll/st�tusz regiszter           *
//*             WR      -     -     -     RXCLR IE    LSEL  MODE  EN           *
//*             RD      RXNE  ASCII IRQ   0     IE    LSEL  MODE  EN           *
//* BASEADDR+1          PS/2 billenty�zet adatregiszter                        *
//*             RD      A lenyomott billenty� 8 bites ASCII k�dja              *
//******************************************************************************
module ps2_keyboard #(
   //A perif�ria b�zisc�me.
   parameter BASEADDR = 8'hff
) (
   //�rajel �s reset.
   input  wire       clk,              //�rajel
   input  wire       rst,              //Reset jel
   
   //A PS/2 interf�sz jelei.
   input  wire       ps2_clk,          //�rajel bemenet
   input  wire       ps2_data,         //Soros adatbemenet
   output reg        ps2_enable,       //A PS/2 interf�sz enged�lyez� jele
   
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

//A kontroll/st�tusz regiszter �r�s�nak �s olvas�s�nak jelz�se.
wire ctrl_reg_wr = psel & s_mst2slv_wr & ~s_mst2slv_addr[0];
wire stat_reg_rd = psel & s_mst2slv_rd & ~s_mst2slv_addr[0];

//Az adatregiszter olvas�s�nak jelz�se.
wire data_reg_rd = psel & s_mst2slv_rd &  s_mst2slv_addr[0];


//******************************************************************************
//* Kontroll/st�tusz regiszter.                                                *
//******************************************************************************
//A PS/2 interf�szt enged�lyez� bit.
always @(posedge clk)
begin
   if (rst)
      ps2_enable <= 1'b0;
   else
      if (ctrl_reg_wr)
         ps2_enable <= s_mst2slv_data[0];
end

//Az �zemm�dot kiv�laszt� bit (ASCII k�d: 0, scan k�d: 1).
reg mode;

always @(posedge clk)
begin
   if (rst)
      mode <= 1'b0;
   else
      if (ctrl_reg_wr)
         mode <= s_mst2slv_data[1];
end

//A billenty�zet nyelv�t kiv�laszt� bit (angol: 0, magyar: 1).
reg lsel;

always @(posedge clk)
begin
   if (rst)
      lsel <= 1'b0;
   else
      if (ctrl_reg_wr)
         lsel <= s_mst2slv_data[2];
end

//A megszak�t�s enged�lyez� bit.
reg ie;

always @(posedge clk)
begin
   if (rst)
      ie <= 1'b0;
   else
      if (ctrl_reg_wr)
         ie <= s_mst2slv_data[3];
end

//A v�teli FIFO t�rl� jele.
wire fifo_clr = rst | (ctrl_reg_wr & s_mst2slv_data[4]);

//A st�tusz regiszter bitjei.
wire [7:0] stat_reg;
wire       fifo_empty;
wire [8:0] fifo_dout;

assign stat_reg[0] = ps2_enable;
assign stat_reg[1] = mode;
assign stat_reg[2] = lsel;
assign stat_reg[3] = ie;
assign stat_reg[4] = 1'b0;
assign stat_reg[5] = irq;
assign stat_reg[6] = fifo_dout[8];
assign stat_reg[7] = ~fifo_empty;


//******************************************************************************
//* Az olvas�si adatbusz �s a megszak�t�sk�r� kimenet meghajt�sa.              *
//******************************************************************************
wire [1:0] dout_sel = {data_reg_rd, stat_reg_rd};

always @(*)
begin
   case (dout_sel)
      2'b01  : s_slv2mst_data <= stat_reg;
      2'b10  : s_slv2mst_data <= fifo_dout[7:0];
      default: s_slv2mst_data <= 8'd0;
   endcase
end

assign irq = ~fifo_empty & ie;


//******************************************************************************
//* PS/2 vev� modul.                                                           *
//******************************************************************************
wire [7:0] ps2_dout;
wire       ps2_dout_valid;

ps2_receiver ps2_receiver(
   //�rajel �s reset.
   .clk(clk),                       //�rajel
   .rst(rst),                       //Reset jel
   
   //A PS/2 interf�sz jelei.
   .ps2_clk(ps2_clk),               //�rajel bemenet
   .ps2_data(ps2_data),             //Soros adatbemenet
   
   //A v�telt enged�lyez� jel.
   .rx_enable(ps2_enable),
   
   //P�rhuzamos adatkimenet.
   .data_out(ps2_dout),             //A vett adat
   .data_valid(ps2_dout_valid)      //�rv�nyes adat jelz�se
);


//******************************************************************************
//* A kib�v�tett billenty� prefix (0xE0) detekt�l�sa.                          *
//******************************************************************************
reg  extended_key;
wire extended_key_set = ps2_dout_valid & (ps2_dout == 8'he0);
wire extended_key_clr = ps2_dout_valid & (ps2_dout[7:5] != 3'b111);

always @(posedge clk)
begin
   if (rst || extended_key_clr)
      extended_key <= 1'b0;
   else
      if (extended_key_set)
         extended_key <= 1'b1;
end


//******************************************************************************
//* A billenty� felenged�s prefix (0xF0) detekt�l�sa.                          *
//******************************************************************************
reg  key_pressed;
wire key_pressed_set = ps2_dout_valid & (ps2_dout[7:5] != 3'b111);
wire key_pressed_clr = ps2_dout_valid & (ps2_dout == 8'hf0);

always @(posedge clk)
begin
   if (rst || key_pressed_set)
      key_pressed <= 1'b1;
   else
      if (key_pressed_clr)
         key_pressed <= 1'b0;
end


//******************************************************************************
//* A SHIFT billenty�k lenyom�s�nak detekt�l�sa.                               *
//* A bal SHIFT scan k�dja : 0x12                                              *
//* A jobb SHIFT scan k�dja: 0x59                                              *
//******************************************************************************
reg  lshift_pressed;
reg  rshift_pressed;
wire shift_pressed = lshift_pressed | rshift_pressed;
wire is_lshift     = ps2_dout_valid & ~extended_key & (ps2_dout == 8'h12);
wire is_rshift     = ps2_dout_valid & ~extended_key & (ps2_dout == 8'h59);

always @(posedge clk)
begin
   if (rst)
      lshift_pressed <= 1'b0;
   else
      if (is_lshift)
         lshift_pressed <= key_pressed;
end

always @(posedge clk)
begin
   if (rst)
      rshift_pressed <= 1'b0;
   else
      if (is_rshift)
         rshift_pressed <= key_pressed;
end


//******************************************************************************
//* Az ALT GR billenty� lenyom�s�nak detekt�l�sa (magyar billenty�zetn�l).     *
//* A jobb ALT scan k�dja: 0xe0 0x11                                           *
//******************************************************************************
reg  altgr_pressed;
wire is_right_alt = ps2_dout_valid & extended_key & (ps2_dout == 8'h11);

always @(posedge clk)
begin
   if (rst)
      altgr_pressed <= 1'b0;
   else
      if (is_right_alt)
         altgr_pressed <= key_pressed & lsel;
end


//******************************************************************************
//* ROM a scan k�d ASCII k�dra t�rt�n� �talak�t�s�hoz.                         *
//******************************************************************************
(* rom_style = "block" *)
reg  [7:0]  ascii_rom [2047:0];
wire [10:0] ascii_rom_addr;
reg  [7:0]  ascii_rom_dout;

`include "ascii_table.vh"

initial
begin
   $readmemh("ascii_data.txt", ascii_rom, 0, 2047);
end

assign ascii_rom_addr[6:0] = ps2_dout[6:0];
assign ascii_rom_addr[7]   = ps2_dout[7] | extended_key;
assign ascii_rom_addr[8]   = shift_pressed;
assign ascii_rom_addr[9]   = altgr_pressed;
assign ascii_rom_addr[10]  = lsel;

always @(posedge clk)
begin
   ascii_rom_dout <= ascii_rom[ascii_rom_addr];
end

//A sz�ks�ges jeleket egy �temmel k�sleltetj�k
//a blokk-RAM olvas�si k�sleltet�se miatt.
reg       not_prefix_byte; 
reg [7:0] ps2_dout_reg;
reg       ps2_dout_valid_reg;

always @(posedge clk)
begin
   not_prefix_byte    <= (ps2_dout[7:5] != 3'b111);
   ps2_dout_reg       <= ascii_rom_addr[7:0];
   ps2_dout_valid_reg <= ps2_dout_valid & key_pressed;
end


//******************************************************************************
//* V�teli FIFO.                                                               *
//******************************************************************************
//ASCII k�d jelz�se a nyomtathat� karakterekhez.
//0: a karakter nem nyomtathat�, a FIFO-ba a scan k�d ker�l
//1: a karakter nyomtathat�, a FIFO-ba az ASCII k�d ker�l
wire is_ascii = ~mode & (ascii_rom_dout != 8'd0);

//A FIFO-ba �rand� adat.
wire [8:0] fifo_din;

assign fifo_din[7:0] = (is_ascii) ? ascii_rom_dout : ps2_dout_reg;
assign fifo_din[8]   = is_ascii;

//A FIFO �r�s enged�lyez� jele.
wire fifo_wr = ps2_dout_valid_reg & (is_ascii | not_prefix_byte);

//A v�teli FIFO.
fifo #(
   //A sz�sz�less�g bitekben.
   .WIDTH(9)
) rx_fifo (
   //�rajel �s reset.
   .clk(clk),                       //�rajel
   .rst(fifo_clr),                  //Reset jel
   
   //Adatvonalak.
   .data_in(fifo_din),              //A FIFO-ba �rand� adat
   .data_out(fifo_dout),            //A FIFO-b�l kiolvasott adat
   
   //Vez�rl� bemenetek.
   .write(fifo_wr),                 //�r�s enged�lyez� jel
   .read(data_reg_rd),              //Olvas�s enged�lyez� jel
   
   //St�tusz kimenetek.
   .empty(fifo_empty),              //A FIFO �res
   .full()                          //A FIFO tele van
);

endmodule
