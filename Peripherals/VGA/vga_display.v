`timescale 1ns / 1ps

//******************************************************************************
//* 1024 x 768 @ 60 Hz VGA megjelen�t� modul grafikus �s karakteres �zemm�d    *
//* t�mogat�ssal.                                                              *
//*                                                                            *
//* A programoz�i fel�let:                                                     *
//*                                                                            *
//* C�m         T�pus   Bitek                                                  *
//* BASEADDR+0          VGA kontroll/st�tusz regiszter                         *
//*             WR      -     -     -     -     -     INC   MODE  EN           *
//*             RD      VBL   IRQ   0     0     0     INC   MODE  EN           *
//* BASEADDR+1          Megszak�t�s enged�lyez� regiszter                      *
//*             WR      -     -     -     -     -     -     -     VBIE         *
//*             RD      0     0     0     0     0     0     0     VBIE         *
//* BASEADDR+2          Megszak�t�s flag regiszter                             *
//*             W1C     -     -     -     -     -     -     -     VBIF         *
//*             RD      0     0     0     0     0     0     0     VBIF         *
//* BASEADDR+3  RD/WR   Adatregiszter                                          *
//* BASEADDR+4  RD/WR   X-koordin�ta regiszter                                 *
//* BASEADDR+5  RD/WR   Y-koordin�ta regiszter                                 *
//*                                                                            *
//* A grafikus �zemm�d (MODE=0) felbont�sa 256x192 pixel, a karakteres �zemm�d *
//* (MODE=1) felbont�sa pedig 32x24 karakter. A koordin�ta regiszterekbe ennek *
//* megfelel� �rt�kek �rand�k. A (0, 0) a bal fels� sarok koordin�t�ja.        *
//*                                                                            *
//* Grafikus �zemm�d eset�n egy adatregiszter �r�ssal egy pixel vez�relhet�.   *
//* A pixel sz�n�t a be�rt b�jt als� h�rom bitje hat�rozza meg.                *
//*                                                                            *
//* Karakteres m�d eset�n egy karakterhez k�t adatregiszter el�r�s tartozik:   *
//*                  D7    | D6 | D5  D4  D3 | D2   D1   D0                    *
//* 1. �r�s/olvas�s: a megjelen�tend� karakter ASCII k�dja                     *
//* 2. �r�s/olvas�s: BLINK | -  | h�tt�rsz�n | karaktersz�n                    *
//*                                                                            *
//* Az adatregiszter el�r�s sor�n az INC bit �rt�k�nek megfelel�en v�ltoznak a *
//* koordin�t�k:                                                               *
//* INC=0: v�zszintes �r�s/olvas�s, az X-koordin�ta n�vekszik el�sz�r          *
//* INC=1: f�gg�leges �r�s/olvas�s, az Y-koordin�ta n�vekszik el�sz�r          *
//******************************************************************************
module vga_display #(
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
   output reg  [7:0] s_slv2mst_data,   //Olvas�si adatbusz
   
   //Megszak�t�sk�r� kimenet.
   output wire       irq,
   
   //A VGA interf�sz jelei.
   output wire       vga_enabled,      //A VGA interf�sz enged�lyezett
   output reg  [5:0] rgb_out,          //Sz�n adatok
   output wire       hsync_out,        //Horizont�lis szinkronjel
   output wire       vsync_out         //Vertik�lis szinkronjel
);

//******************************************************************************
//* C�mdek�dol�s.                                                              *
//******************************************************************************
//A perif�ria kiv�laszt� jele.
wire psel = ((s_mst2slv_addr >> 3) == (BASEADDR >> 3));

//A kontroll/st�tusz regiszter �r�s�nak �s olvas�s�nak jelz�se.
wire ctrl_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b000);
wire stat_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b000);

//A megszak�t�s enged�lyez� regiszter �r�s�nak �s olvas�s�nak jelz�se.
wire ie_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b001);
wire ie_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b001);

//A megszak�t�s flag regiszter �r�s�nak �s olvas�s�nak jelz�se.
wire if_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b010);
wire if_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b010);

//Az adatregiszter �r�s�nak �s olvas�s�nak jelz�se.
wire data_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b011);
wire data_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b011);

//A c�msz�ml�l� �r�s�nak �s olvas�s�nak jelz�se.
wire xcnt_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b100);
wire xcnt_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b100);
wire ycnt_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b101);
wire ycnt_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b101);


//******************************************************************************
//* Kontroll/st�tusz regiszter.                                                *
//******************************************************************************
reg [2:0] ctrl_reg;

always @(posedge clk)
begin
   if (rst)
      ctrl_reg <= 3'b000;
   else
      if (ctrl_reg_wr)
         ctrl_reg <= s_mst2slv_data[2:0];
end

//A kontroll regiszter bitjei.
assign vga_enabled = ctrl_reg[0];
wire   disp_mode   = ctrl_reg[1];
wire   adr_inc_sel = ctrl_reg[2];

//A st�tusz regiszter bitjei.
wire [7:0] stat_reg;
wire       v_blank;

assign stat_reg[2:0] = ctrl_reg;
assign stat_reg[5:3] = 3'b000;
assign stat_reg[6]   = irq;
assign stat_reg[7]   = v_blank;


//******************************************************************************
//* Megszak�t�s enged�lyez� regiszter.                                         *
//******************************************************************************
reg ie_reg;

always @(posedge clk)
begin
   if (rst)
      ie_reg <= 1'b0;
   else
      if (ie_reg_wr)
         ie_reg <= s_mst2slv_data[0];
end


//******************************************************************************
//* Megszak�t�s flag regiszter.                                                *
//******************************************************************************
reg  if_reg;
wire v_blank_begin;
wire v_blank_end;

always @(posedge clk)
begin
   if (rst)
      if_reg <= 1'b0;
   else
      if (v_blank_begin)
         if_reg <= 1'b1;
      else
         if (v_blank_end || (if_reg_wr && s_mst2slv_data[0]))
            if_reg <= 1'b0;
end

//A megszak�t�sk�r� kimenet meghajt�sa.
assign irq = ie_reg & if_reg;


//******************************************************************************
//* Adatregiszter (video mem�ria).                                             *
//******************************************************************************
reg  [15:0] vram_cpu_addr;
wire [7:0]  vram_cpu_dout;

reg  [15:0] vram_vga_addr;
wire [2:0]  vram_rgb_data;
wire [15:0] vram_chr_data;

video_memory video_memory(
   //�rajel.
   .clk(clk),
   
   //�zemm�d kiv�laszt� jel (0: grafikus, 1: karakteres).
   .mode(disp_mode),
   
   //�r�si/olvas�si port a CPU fel�.
   .cpu_addr(vram_cpu_addr),           //C�mbusz
   .cpu_write(data_reg_wr),            //�r�s enged�lyez� jel
   .cpu_din(s_mst2slv_data),           //�r�si adatbusz
   .cpu_dout(vram_cpu_dout),           //Olvas�si adatbusz
   
   //Olvas�si port a VGA modul fel�.
   .vga_addr(vram_vga_addr),           //Olvas�si c�m
   .vga_rgb_data(vram_rgb_data),       //Adat (grafikus m�d)
   .vga_char_data(vram_chr_data)       //Adat (karakteres m�d)
);


//******************************************************************************
//* C�msz�ml�l�.                                                               *
//******************************************************************************
//Sz�ml�l� az X-koordin�t�hoz.
reg  [7:0] x_cnt;
reg        x_cnt_en;
wire       x_cnt_max = (x_cnt == ((disp_mode) ? 8'd31 : 8'd255));

always @(posedge clk)
begin
   if (rst)
      x_cnt <= 8'd0;
   else
      if (xcnt_reg_wr)
         x_cnt <= s_mst2slv_data;
      else
         if (x_cnt_en)
            if (x_cnt_max)
               x_cnt <= 8'd0;
            else
               x_cnt <= x_cnt + 8'd1;
end

//Sz�ml�l� az X-koordin�t�hoz.
reg  [7:0] y_cnt;
reg        y_cnt_en;
wire       y_cnt_max = (y_cnt == ((disp_mode) ? 8'd23 : 8'd191));

always @(posedge clk)
begin
   if (rst)
      y_cnt <= 8'd0;
   else
      if (ycnt_reg_wr)
         y_cnt <= s_mst2slv_data;
      else
         if (y_cnt_en)
            if (y_cnt_max)
               y_cnt <= 8'd0;
            else
               y_cnt <= y_cnt + 8'd1;
end

//Karakteres �zemm�d eset�n a c�m LSb-je.
reg  chr_addr_lsb;
wire data_reg_rdwr = data_reg_wr | data_reg_rd;

always @(posedge clk)
begin
   if (rst || xcnt_reg_wr)
      chr_addr_lsb <= 1'b0;
   else
      if (data_reg_rdwr)
         chr_addr_lsb <= ~chr_addr_lsb;
end

//Az X sz�ml�l� enged�lyez� jel�nek el��ll�t�sa.
always @(*)
begin
   if (disp_mode)
      if (adr_inc_sel)
         //Karakteres �zemm�d, f�gg�leges �r�s/olvas�s.
         x_cnt_en <= data_reg_rdwr & chr_addr_lsb & y_cnt_max;
      else
         //Karakteres �zemm�d, v�zszintes �r�s/olvas�s.
         x_cnt_en <= data_reg_rdwr & chr_addr_lsb;
   else
      if (adr_inc_sel)
         //Grafikus �zemm�d, f�gg�leges �r�s/olvas�s.
         x_cnt_en <= data_reg_rdwr & y_cnt_max;
      else
         //Grafikus �zemm�d, v�zszintes �r�s/olvas�s.
         x_cnt_en <= data_reg_rdwr;
end

//Az Y sz�ml�l� enged�lyez� jel�nek el��ll�t�sa.
always @(*)
begin
   if (disp_mode)
      if (adr_inc_sel)
         //Karakteres �zemm�d, f�gg�leges �r�s/olvas�s.
         y_cnt_en <= data_reg_rdwr & chr_addr_lsb;
      else
         //Karakteres �zemm�d, v�zszintes �r�s/olvas�s.
         y_cnt_en <= data_reg_rdwr & chr_addr_lsb & x_cnt_max;
   else
      if (adr_inc_sel)
         //Grafikus �zemm�d, f�gg�leges �r�s/olvas�s.
         y_cnt_en <= data_reg_rdwr;
      else
         //Grafikus �zemm�d, v�zszintes �r�s/olvas�s.
         y_cnt_en <= data_reg_rdwr & x_cnt_max;
end

//A CPU oldali video mem�ria c�m el��ll�t�sa.
always @(*)
begin
   if (disp_mode)
      vram_cpu_addr <= {5'd0, y_cnt[4:0], x_cnt[4:0], chr_addr_lsb};
   else
      vram_cpu_addr <= {y_cnt, x_cnt};
end


//******************************************************************************
//* A processzor olvas�si adatbusz�nak meghajt�sa. Az olvas�si adatbuszra csak *
//* az olvas�s ideje alatt kapcsoljuk r� a k�rt �rt�ket, egy�bk�nt egy inakt�v *
//* nulla �rt�k jelenik meg rajta (elosztott busz multiplexer funkci�).        *
//******************************************************************************
wire [5:0] dout_sel;

assign dout_sel[0] = stat_reg_rd;
assign dout_sel[1] = ie_reg_rd;
assign dout_sel[2] = if_reg_rd;
assign dout_sel[3] = data_reg_rd;
assign dout_sel[4] = xcnt_reg_rd;
assign dout_sel[5] = ycnt_reg_rd;

always @(*)
begin
   case (dout_sel)
      6'b000001: s_slv2mst_data <= stat_reg;
      6'b000010: s_slv2mst_data <= {7'd0, ie_reg};
      6'b000100: s_slv2mst_data <= {7'd0, if_reg};
      6'b001000: s_slv2mst_data <= vram_cpu_dout;
      6'b010000: s_slv2mst_data <= x_cnt;
      6'b100000: s_slv2mst_data <= y_cnt;
      default  : s_slv2mst_data <= 8'd0;
   endcase
end


//******************************************************************************
//* VGA id�z�t�s gener�tor.                                                    *
//******************************************************************************
wire [8:0] h_cnt;
wire [9:0] v_cnt;
wire       h_blank;
wire       h_sync;
wire       v_sync;

vga_timing vga_timing(
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //Horizont�lis �s vertik�lis sz�ml�l�k.
   .h_cnt(h_cnt),                      //Horizont�lis sz�ml�l�
   .v_cnt(v_cnt),                      //Vertik�lis sz�ml�l�
   
   //Szinkron- �s kiolt�jelek. 
   .h_blank(h_blank),                  //Horizont�lis kiolt�jel
   .v_blank(v_blank),                  //Vertik�lis kiolt�jel
   .v_blank_begin(v_blank_begin),      //A vertik�lis visszafut�s kezdete
   .v_blank_end(v_blank_end),          //A vertik�lis visszafut�s v�ge
   .h_sync(h_sync),                    //Horizont�lis szinkronjel
   .v_sync(v_sync)                     //Vertik�lis szinkronjel
);

//A kiolt� jel el��ll�t�sa.
wire blank = h_blank | v_blank;

//A videomem�ria VGA oldali c�m�nek el��ll�t�sa.
always @(*)
begin
   if (disp_mode)
      //Karakteres �zemm�d.
      vram_vga_addr <= {5'd0, v_cnt[9:5], h_cnt[7:3], 1'd0};
   else
      //Grafikus �zemm�d.
      vram_vga_addr <= {v_cnt[9:2], h_cnt[7:0]};
end


//******************************************************************************
//* Karakter ROM.                                                              *
//******************************************************************************
(* rom_style = "block" *)
reg chr_rom [16383:0];
reg chr_rom_dout;

initial
begin
   $readmemh("font_data.txt", chr_rom, 0, 16383);
end

//A karakter ROM c�m als� 6 bitj�nek k�sleltet�se. Ez az�rt sz�ks�ges, mert
//a video mem�ria blokk-RAM-mal van megval�s�tva, �gy olvas�s eset�n 1 �rajel
//�temnyit k�sleltet.
reg  [5:0]  chr_rom_adrl;
wire [13:0] chr_rom_addr = {vram_chr_data[7:0], chr_rom_adrl}; 

always @(posedge clk)
begin
   chr_rom_adrl = {v_cnt[4:2], h_cnt[2:0]};
end

//A karakrer ROM kimenete.
always @(posedge clk)
begin
   chr_rom_dout <= chr_rom[chr_rom_addr];
end


//******************************************************************************
//* A VGA interf�sz kimeneteinek meghajt�sa.                                   *
//******************************************************************************
//A sz�ks�ges jelek k�sleltet�se a blokk-RAM-ok sz�m�nak megfelel�en.
reg [7:0] chr_reg;
reg [2:0] rgb_reg;
reg [1:0] blank_reg;
reg [2:0] h_sync_reg;
reg [2:0] v_sync_reg;

always @(posedge clk)
begin
   chr_reg    <= vram_chr_data[15:8];
   rgb_reg    <= vram_rgb_data;
   blank_reg  <= {blank_reg[0], blank};
   h_sync_reg <= {h_sync_reg[1:0], h_sync};
   v_sync_reg <= {v_sync_reg[1:0], v_sync};
end

//�rajel oszt� a karakterek villogtat�s�hoz.
reg [5:0] blink_cnt;

always @(posedge clk)
begin
   if (rst)
      blink_cnt <= 6'd0;
   else
      if (v_blank_begin)
         blink_cnt <= blink_cnt + 6'd1;
end

//Az RGB kimenet meghajt�sa.
always @(posedge clk)
begin
   if (blank_reg[1])
      rgb_out <= 6'b00_00_00;
   else
      if (disp_mode)
         if (chr_rom_dout && (~chr_reg[7] || ~blink_cnt[5]))
            rgb_out <= {chr_reg[2], chr_reg[2], chr_reg[1], chr_reg[1], chr_reg[0], chr_reg[0]};
         else
            rgb_out <= {chr_reg[5], chr_reg[5], chr_reg[4], chr_reg[4], chr_reg[3], chr_reg[3]};
      else
         rgb_out <= {rgb_reg[2], rgb_reg[2], rgb_reg[1], rgb_reg[1], rgb_reg[0], rgb_reg[0]};
end

//A szinkronjelek meghajt�sa.
assign hsync_out = h_sync_reg[2];
assign vsync_out = v_sync_reg[2];

endmodule
