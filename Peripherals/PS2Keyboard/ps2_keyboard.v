`timescale 1ns / 1ps

//******************************************************************************
//* PS/2 billentyûzet interfész periféria. Az adatregiszterbõl a lenyomott     *
//* billentyû ASCII kódja olvasható ki.                                        *
//*                                                                            *
//* A programozói felület:                                                     *
//*                                                                            *
//* Cím         Típus   Bitek                                                  *
//* BASEADDR+0          PS/2 billentyûzet kontroll/státusz regiszter           *
//*             WR      -     -     -     RXCLR IE    LSEL  MODE  EN           *
//*             RD      RXNE  ASCII IRQ   0     IE    LSEL  MODE  EN           *
//* BASEADDR+1          PS/2 billentyûzet adatregiszter                        *
//*             RD      A lenyomott billentyû 8 bites ASCII kódja              *
//******************************************************************************
module ps2_keyboard #(
   //A periféria báziscíme.
   parameter BASEADDR = 8'hff
) (
   //Órajel és reset.
   input  wire       clk,              //Órajel
   input  wire       rst,              //Reset jel
   
   //A PS/2 interfész jelei.
   input  wire       ps2_clk,          //Órajel bemenet
   input  wire       ps2_data,         //Soros adatbemenet
   output reg        ps2_enable,       //A PS/2 interfész engedélyezõ jele
   
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

//A kontroll/státusz regiszter írásának és olvasásának jelzése.
wire ctrl_reg_wr = psel & s_mst2slv_wr & ~s_mst2slv_addr[0];
wire stat_reg_rd = psel & s_mst2slv_rd & ~s_mst2slv_addr[0];

//Az adatregiszter olvasásának jelzése.
wire data_reg_rd = psel & s_mst2slv_rd &  s_mst2slv_addr[0];


//******************************************************************************
//* Kontroll/státusz regiszter.                                                *
//******************************************************************************
//A PS/2 interfészt engedélyezõ bit.
always @(posedge clk)
begin
   if (rst)
      ps2_enable <= 1'b0;
   else
      if (ctrl_reg_wr)
         ps2_enable <= s_mst2slv_data[0];
end

//Az üzemmódot kiválasztó bit (ASCII kód: 0, scan kód: 1).
reg mode;

always @(posedge clk)
begin
   if (rst)
      mode <= 1'b0;
   else
      if (ctrl_reg_wr)
         mode <= s_mst2slv_data[1];
end

//A billentyûzet nyelvét kiválasztó bit (angol: 0, magyar: 1).
reg lsel;

always @(posedge clk)
begin
   if (rst)
      lsel <= 1'b0;
   else
      if (ctrl_reg_wr)
         lsel <= s_mst2slv_data[2];
end

//A megszakítás engedélyezõ bit.
reg ie;

always @(posedge clk)
begin
   if (rst)
      ie <= 1'b0;
   else
      if (ctrl_reg_wr)
         ie <= s_mst2slv_data[3];
end

//A vételi FIFO törlõ jele.
wire fifo_clr = rst | (ctrl_reg_wr & s_mst2slv_data[4]);

//A státusz regiszter bitjei.
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
//* Az olvasási adatbusz és a megszakításkérõ kimenet meghajtása.              *
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
//* PS/2 vevõ modul.                                                           *
//******************************************************************************
wire [7:0] ps2_dout;
wire       ps2_dout_valid;

ps2_receiver ps2_receiver(
   //Órajel és reset.
   .clk(clk),                       //Órajel
   .rst(rst),                       //Reset jel
   
   //A PS/2 interfész jelei.
   .ps2_clk(ps2_clk),               //Órajel bemenet
   .ps2_data(ps2_data),             //Soros adatbemenet
   
   //A vételt engedélyezõ jel.
   .rx_enable(ps2_enable),
   
   //Párhuzamos adatkimenet.
   .data_out(ps2_dout),             //A vett adat
   .data_valid(ps2_dout_valid)      //Érvényes adat jelzése
);


//******************************************************************************
//* A kibõvített billentyû prefix (0xE0) detektálása.                          *
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
//* A billentyû felengedés prefix (0xF0) detektálása.                          *
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
//* A SHIFT billentyûk lenyomásának detektálása.                               *
//* A bal SHIFT scan kódja : 0x12                                              *
//* A jobb SHIFT scan kódja: 0x59                                              *
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
//* Az ALT GR billentyû lenyomásának detektálása (magyar billentyûzetnél).     *
//* A jobb ALT scan kódja: 0xe0 0x11                                           *
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
//* ROM a scan kód ASCII kódra történõ átalakításához.                         *
//******************************************************************************
(* rom_style = "block" *)
reg  [7:0]  ascii_rom [2047:0];
wire [10:0] ascii_rom_addr;
reg  [7:0]  ascii_rom_dout;

`include "src\Peripherals\PS2Keyboard\ascii_table.vh"

initial
begin
   $readmemh("src/Peripherals/PS2Keyboard/ascii_data.txt", ascii_rom, 0, 2047);
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

//A szükséges jeleket egy ütemmel késleltetjük
//a blokk-RAM olvasási késleltetése miatt.
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
//* Vételi FIFO.                                                               *
//******************************************************************************
//ASCII kód jelzése a nyomtatható karakterekhez.
//0: a karakter nem nyomtatható, a FIFO-ba a scan kód kerül
//1: a karakter nyomtatható, a FIFO-ba az ASCII kód kerül
wire is_ascii = ~mode & (ascii_rom_dout != 8'd0);

//A FIFO-ba írandó adat.
wire [8:0] fifo_din;

assign fifo_din[7:0] = (is_ascii) ? ascii_rom_dout : ps2_dout_reg;
assign fifo_din[8]   = is_ascii;

//A FIFO írás engedélyezõ jele.
wire fifo_wr = ps2_dout_valid_reg & (is_ascii | not_prefix_byte);

//A vételi FIFO.
fifo #(
   //A szószélesség bitekben.
   .WIDTH(9)
) rx_fifo (
   //Órajel és reset.
   .clk(clk),                       //Órajel
   .rst(fifo_clr),                  //Reset jel
   
   //Adatvonalak.
   .data_in(fifo_din),              //A FIFO-ba írandó adat
   .data_out(fifo_dout),            //A FIFO-ból kiolvasott adat
   
   //Vezérlõ bemenetek.
   .write(fifo_wr),                 //Írás engedélyezõ jel
   .read(data_reg_rd),              //Olvasás engedélyezõ jel
   
   //Státusz kimenetek.
   .empty(fifo_empty),              //A FIFO üres
   .full()                          //A FIFO tele van
);

endmodule
