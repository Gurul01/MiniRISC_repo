`timescale 1ns / 1ps

//******************************************************************************
//* 1024 x 768 @ 60 Hz VGA megjelenítõ modul grafikus és karakteres üzemmód    *
//* támogatással.                                                              *
//*                                                                            *
//* A programozói felület:                                                     *
//*                                                                            *
//* Cím         Típus   Bitek                                                  *
//* BASEADDR+0          VGA kontroll/státusz regiszter                         *
//*             WR      -     -     -     -     -     INC   MODE  EN           *
//*             RD      VBL   IRQ   0     0     0     INC   MODE  EN           *
//* BASEADDR+1          Megszakítás engedélyezõ regiszter                      *
//*             WR      -     -     -     -     -     -     -     VBIE         *
//*             RD      0     0     0     0     0     0     0     VBIE         *
//* BASEADDR+2          Megszakítás flag regiszter                             *
//*             W1C     -     -     -     -     -     -     -     VBIF         *
//*             RD      0     0     0     0     0     0     0     VBIF         *
//* BASEADDR+3  RD/WR   Adatregiszter                                          *
//* BASEADDR+4  RD/WR   X-koordináta regiszter                                 *
//* BASEADDR+5  RD/WR   Y-koordináta regiszter                                 *
//*                                                                            *
//* A grafikus üzemmód (MODE=0) felbontása 256x192 pixel, a karakteres üzemmód *
//* (MODE=1) felbontása pedig 32x24 karakter. A koordináta regiszterekbe ennek *
//* megfelelõ értékek írandók. A (0, 0) a bal felsõ sarok koordinátája.        *
//*                                                                            *
//* Grafikus üzemmód esetén egy adatregiszter írással egy pixel vezérelhetõ.   *
//* A pixel színét a beírt bájt alsó három bitje határozza meg.                *
//*                                                                            *
//* Karakteres mód esetén egy karakterhez két adatregiszter elérés tartozik:   *
//*                  D7    | D6 | D5  D4  D3 | D2   D1   D0                    *
//* 1. írás/olvasás: a megjelenítendõ karakter ASCII kódja                     *
//* 2. írás/olvasás: BLINK | -  | háttérszín | karakterszín                    *
//*                                                                            *
//* Az adatregiszter elérés során az INC bit értékének megfelelõen változnak a *
//* koordináták:                                                               *
//* INC=0: vízszintes írás/olvasás, az X-koordináta növekszik elõször          *
//* INC=1: függõleges írás/olvasás, az Y-koordináta növekszik elõször          *
//******************************************************************************
module vga_display #(
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
   output wire       irq,
   
   //A VGA interfész jelei.
   output wire       vga_enabled,      //A VGA interfész engedélyezett
   output reg  [5:0] rgb_out,          //Szín adatok
   output wire       hsync_out,        //Horizontális szinkronjel
   output wire       vsync_out         //Vertikális szinkronjel
);

//******************************************************************************
//* Címdekódolás.                                                              *
//******************************************************************************
//A periféria kiválasztó jele.
wire psel = ((s_mst2slv_addr >> 3) == (BASEADDR >> 3));

//A kontroll/státusz regiszter írásának és olvasásának jelzése.
wire ctrl_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b000);
wire stat_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b000);

//A megszakítás engedélyezõ regiszter írásának és olvasásának jelzése.
wire ie_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b001);
wire ie_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b001);

//A megszakítás flag regiszter írásának és olvasásának jelzése.
wire if_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b010);
wire if_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b010);

//Az adatregiszter írásának és olvasásának jelzése.
wire data_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b011);
wire data_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b011);

//A címszámláló írásának és olvasásának jelzése.
wire xcnt_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b100);
wire xcnt_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b100);
wire ycnt_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[2:0] == 3'b101);
wire ycnt_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[2:0] == 3'b101);


//******************************************************************************
//* Kontroll/státusz regiszter.                                                *
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

//A státusz regiszter bitjei.
wire [7:0] stat_reg;
wire       v_blank;

assign stat_reg[2:0] = ctrl_reg;
assign stat_reg[5:3] = 3'b000;
assign stat_reg[6]   = irq;
assign stat_reg[7]   = v_blank;


//******************************************************************************
//* Megszakítás engedélyezõ regiszter.                                         *
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
//* Megszakítás flag regiszter.                                                *
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

//A megszakításkérõ kimenet meghajtása.
assign irq = ie_reg & if_reg;


//******************************************************************************
//* Adatregiszter (video memória).                                             *
//******************************************************************************
reg  [15:0] vram_cpu_addr;
wire [7:0]  vram_cpu_dout;

reg  [15:0] vram_vga_addr;
wire [2:0]  vram_rgb_data;
wire [15:0] vram_chr_data;

video_memory video_memory(
   //Órajel.
   .clk(clk),
   
   //Üzemmód kiválasztó jel (0: grafikus, 1: karakteres).
   .mode(disp_mode),
   
   //Írási/olvasási port a CPU felé.
   .cpu_addr(vram_cpu_addr),           //Címbusz
   .cpu_write(data_reg_wr),            //Írás engedélyezõ jel
   .cpu_din(s_mst2slv_data),           //Írási adatbusz
   .cpu_dout(vram_cpu_dout),           //Olvasási adatbusz
   
   //Olvasási port a VGA modul felé.
   .vga_addr(vram_vga_addr),           //Olvasási cím
   .vga_rgb_data(vram_rgb_data),       //Adat (grafikus mód)
   .vga_char_data(vram_chr_data)       //Adat (karakteres mód)
);


//******************************************************************************
//* Címszámláló.                                                               *
//******************************************************************************
//Számláló az X-koordinátához.
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

//Számláló az X-koordinátához.
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

//Karakteres üzemmód esetén a cím LSb-je.
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

//Az X számláló engedélyezõ jelének elõállítása.
always @(*)
begin
   if (disp_mode)
      if (adr_inc_sel)
         //Karakteres üzemmód, függõleges írás/olvasás.
         x_cnt_en <= data_reg_rdwr & chr_addr_lsb & y_cnt_max;
      else
         //Karakteres üzemmód, vízszintes írás/olvasás.
         x_cnt_en <= data_reg_rdwr & chr_addr_lsb;
   else
      if (adr_inc_sel)
         //Grafikus üzemmód, függõleges írás/olvasás.
         x_cnt_en <= data_reg_rdwr & y_cnt_max;
      else
         //Grafikus üzemmód, vízszintes írás/olvasás.
         x_cnt_en <= data_reg_rdwr;
end

//Az Y számláló engedélyezõ jelének elõállítása.
always @(*)
begin
   if (disp_mode)
      if (adr_inc_sel)
         //Karakteres üzemmód, függõleges írás/olvasás.
         y_cnt_en <= data_reg_rdwr & chr_addr_lsb;
      else
         //Karakteres üzemmód, vízszintes írás/olvasás.
         y_cnt_en <= data_reg_rdwr & chr_addr_lsb & x_cnt_max;
   else
      if (adr_inc_sel)
         //Grafikus üzemmód, függõleges írás/olvasás.
         y_cnt_en <= data_reg_rdwr;
      else
         //Grafikus üzemmód, vízszintes írás/olvasás.
         y_cnt_en <= data_reg_rdwr & x_cnt_max;
end

//A CPU oldali video memória cím elõállítása.
always @(*)
begin
   if (disp_mode)
      vram_cpu_addr <= {5'd0, y_cnt[4:0], x_cnt[4:0], chr_addr_lsb};
   else
      vram_cpu_addr <= {y_cnt, x_cnt};
end


//******************************************************************************
//* A processzor olvasási adatbuszának meghajtása. Az olvasási adatbuszra csak *
//* az olvasás ideje alatt kapcsoljuk rá a kért értéket, egyébként egy inaktív *
//* nulla érték jelenik meg rajta (elosztott busz multiplexer funkció).        *
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
//* VGA idõzítés generátor.                                                    *
//******************************************************************************
wire [8:0] h_cnt;
wire [9:0] v_cnt;
wire       h_blank;
wire       h_sync;
wire       v_sync;

vga_timing vga_timing(
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //Horizontális és vertikális számlálók.
   .h_cnt(h_cnt),                      //Horizontális számláló
   .v_cnt(v_cnt),                      //Vertikális számláló
   
   //Szinkron- és kioltójelek. 
   .h_blank(h_blank),                  //Horizontális kioltójel
   .v_blank(v_blank),                  //Vertikális kioltójel
   .v_blank_begin(v_blank_begin),      //A vertikális visszafutás kezdete
   .v_blank_end(v_blank_end),          //A vertikális visszafutás vége
   .h_sync(h_sync),                    //Horizontális szinkronjel
   .v_sync(v_sync)                     //Vertikális szinkronjel
);

//A kioltó jel elõállítása.
wire blank = h_blank | v_blank;

//A videomemória VGA oldali címének elõállítása.
always @(*)
begin
   if (disp_mode)
      //Karakteres üzemmód.
      vram_vga_addr <= {5'd0, v_cnt[9:5], h_cnt[7:3], 1'd0};
   else
      //Grafikus üzemmód.
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
   $readmemh("src/Peripherals/VGA/font_data.txt", chr_rom, 0, 16383);
end

//A karakter ROM cím alsó 6 bitjének késleltetése. Ez azért szükséges, mert
//a video memória blokk-RAM-mal van megvalósítva, így olvasás esetén 1 órajel
//ütemnyit késleltet.
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
//* A VGA interfész kimeneteinek meghajtása.                                   *
//******************************************************************************
//A szükséges jelek késleltetése a blokk-RAM-ok számának megfelelõen.
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

//Órajel osztó a karakterek villogtatásához.
reg [5:0] blink_cnt;

always @(posedge clk)
begin
   if (rst)
      blink_cnt <= 6'd0;
   else
      if (v_blank_begin)
         blink_cnt <= blink_cnt + 6'd1;
end

//Az RGB kimenet meghajtása.
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

//A szinkronjelek meghajtása.
assign hsync_out = h_sync_reg[2];
assign vsync_out = v_sync_reg[2];

endmodule
