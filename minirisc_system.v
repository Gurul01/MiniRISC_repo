//******************************************************************************
//* MiniRISC rendszer top-level modul.                                         *
//******************************************************************************
module minirisc_system(
   //Órajel és reset.
   input  wire         clk16M,      //16 MHz órajel
   input  wire         rstbt,       //Reset nyomógomb
   
   //Perifériák.
   input  wire [7:0]   sw,          //DIP kapcsoló
   input  wire [3:0]   bt,          //Nyomógombok
   output wire [7:0]   ld,          //LED-ek
   output wire [7:0]   seg_n,       //Szegmens vezérlõ jelek (aktív alacsony)
   output wire [3:0]   dig_n,       //Digit kiválasztó jelek (aktív alacsony)
   output wire [4:0]   col_n,       //Oszlop kiválasztó jelek (aktív alacsony)
   
   //USRT.
   input  wire         dev_clk,     //USRT órajel
   input  wire         dev_mosi,    //Soros adatbemenet
   output wire         dev_miso,    //Soros adatkimenet
   
   //GPIO (A bõvítõcsatlakozó).
   inout  wire [14:4]  aio,         //Kétirányú I/O vonalak
   input  wire [16:15] ai,          //Csak bemeneti vonalak
   
   //GPIO (B bõvítõcsatlakozó).
   inout  wire [14:4]  bio,         //Kétirányú I/O vonalak
   input  wire [16:15] bi           //Csak bemeneti vonalak
);

//******************************************************************************
//* Órajel és reset.                                                           *
//******************************************************************************
wire clk = clk16M;
wire rst;


//******************************************************************************
//* Az adatmemória busz interfészhez tartozó jelek.                            *
//******************************************************************************
//A processzor master adatmemória interfészének kimenetei.
wire [7:0] cpu2slv_addr;
wire       cpu2slv_wr;
wire       cpu2slv_rd;
wire [7:0] cpu2slv_data;

//A DMA vezérlõ master adatmemória interfészének kimenetei.
wire [7:0] dma2slv_addr;
wire       dma2slv_wr;
wire       dma2slv_rd;
wire [7:0] dma2slv_data;

//Olvasási adatbusz a slave egységektõl a master egységek felé.
wire [7:0] slv2mst_data;

//Jelek a slave egységek felé.
wire [7:0] mst2slv_addr = cpu2slv_addr | dma2slv_addr;
wire       mst2slv_wr   = cpu2slv_wr   | dma2slv_wr;
wire       mst2slv_rd   = cpu2slv_rd   | dma2slv_rd;
wire [7:0] mst2slv_data = cpu2slv_data | dma2slv_data;


//******************************************************************************
//* Adatmemória busz arbiter.                                                  *
//******************************************************************************
wire cpu_bus_req;
wire cpu_bus_grant;
wire dma_bus_req;
wire dma_bus_grant;

bus_arbiter_2m_fixed bus_arbiter(  
   //A master 0 egységhez tartozó jelek.
   .mst0_req(cpu_bus_req),             //Busz hozzáférés kérése
   .mst0_grant(cpu_bus_grant),         //Busz hozzáférés megadása
   
   //A master 1 egységhez tartozó jelek.
   .mst1_req(dma_bus_req),             //Busz hozzáférés kérése
   .mst1_grant(dma_bus_grant)          //Busz hozzáférés megadása
);


//******************************************************************************
//* MiniRISC CPU v2.0.                                                         *
//******************************************************************************
wire [7:0]  cpu2prgmem_addr;
wire [15:0] prgmem2cpu_data;
wire        irq;
wire [22:0] dbg2cpu_data;
wire [47:0] cpu2dbg_data;

minirisc_cpu minirisc_cpu(
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Aszinkron reset
   
   //Busz interfész a programmemória eléréséhez.
   .cpu2pmem_addr(cpu2prgmem_addr),    //Címbusz
   .pmem2cpu_data(prgmem2cpu_data),    //Olvasási adatbusz
   
   //Master busz interfész az adatmemória eléréséhez.
   .m_bus_req(cpu_bus_req),            //Busz hozzáférés kérése
   .m_bus_grant(cpu_bus_grant),        //Busz hozzáférés megadása
   .m_mst2slv_addr(cpu2slv_addr),      //Címbusz
   .m_mst2slv_wr(cpu2slv_wr),          //Írás engedélyezõ jel
   .m_mst2slv_rd(cpu2slv_rd),          //Olvasás engedélyezõ jel
   .m_mst2slv_data(cpu2slv_data),      //Írási adatbusz
   .m_slv2mst_data(slv2mst_data),      //Olvasási adatbusz
   
   //Megszakításkérõ bemenet (aktív magas szintérzékeny).
   .irq(irq),
   
   //Debug interfész.
   .dbg2cpu_data(dbg2cpu_data),        //Jelek a debug modultól a CPU felé
   .cpu2dbg_data(cpu2dbg_data)         //Jelek a CPU-tól a debug modul felé
);


//******************************************************************************
//* Debug modul.                                                               *
//******************************************************************************
wire [7:0]  dbg2prgmem_addr;
wire [15:0] dbg2prgmem_data;
wire        dbg2prgmem_wr;

debug_module debug_module(
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst_in(rstbt),                     //Reset bemenet
   .rst_out(rst),                      //Reset jel a rendszer számára
   
   //A programmemória írásához szükséges jelek.
   .dbg2pmem_addr(dbg2prgmem_addr),    //Írási cím
   .dbg2pmem_data(dbg2prgmem_data),    //A memóriába írandó adat
   .dbg2pmem_wr(dbg2prgmem_wr),        //Írás engedélyezõ jel
   
   //Debug interfész a CPU felé.
   .dbg2cpu_data(dbg2cpu_data),        //Jelek a debug modultól a CPU felé
   .cpu2dbg_data(cpu2dbg_data)         //Jelek a CPU-tól a debug modul felé
);


//******************************************************************************
//* 256 x 16 bites programmemória (elosztott RAM).                             *
//******************************************************************************
(* ram_style = "distributed" *)
reg [15:0] prg_mem [255:0];

always @(posedge clk)
begin
   if (dbg2prgmem_wr)
      prg_mem[dbg2prgmem_addr] <= dbg2prgmem_data;
end

assign prgmem2cpu_data = prg_mem[cpu2prgmem_addr];


//******************************************************************************
//* DMA vezérlõ.                                                               *
//* Címtartomány: 0x8C - 0x8F (írható/olvasható)                               *
//******************************************************************************
wire [7:0] s_dma2mst_data;
wire       dma_irq;

dma_controller #(
   //A periféria báziscíme.
   .BASEADDR(8'h8c)
) dma_controller (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei (regiszter elérés).
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_dma2mst_data),    //Olvasási adatbusz
   
   //A master busz interfész jelei (DMA átvitel).
   .m_bus_req(dma_bus_req),            //Busz hozzáférés kérése
   .m_bus_grant(dma_bus_grant),        //Busz hozzáférés megadása
   .m_mst2slv_addr(dma2slv_addr),      //Címbusz
   .m_mst2slv_wr(dma2slv_wr),          //Írás engedélyezõ jel
   .m_mst2slv_rd(dma2slv_rd),          //Olvasás engedélyezõ jel
   .m_mst2slv_data(dma2slv_data),      //Írási adatbusz
   .m_slv2mst_data(slv2mst_data),      //Olvasási adatbusz
   
   //Megszakításkérõ kimenet.
   .irq(dma_irq)
);


//******************************************************************************
//* 128 x 8 bites adatmemória.                                                 *
//* Címtartomány: 0x00 - 0x7F (írható/olvasható)                               *
//******************************************************************************
(* ram_style = "distributed" *)
reg  [7:0] data_mem [127:0];

wire [6:0] data_mem_addr  = mst2slv_addr[6:0];
wire       data_mem_wr    = mst2slv_wr & ~mst2slv_addr[7];
wire       data_mem_rd    = mst2slv_rd & ~mst2slv_addr[7];
wire [7:0] data_mem_din   = mst2slv_data;
wire [7:0] s_mem2mst_data = (data_mem_rd) ? data_mem[data_mem_addr] : 8'd0;

always @(posedge clk)
begin
   if (data_mem_wr)
      data_mem[data_mem_addr] <= data_mem_din;
end


//******************************************************************************
//* LED periféria.                                                             *
//* Címtartomány: 0x80 (írható/olvasható)                                      *
//******************************************************************************
wire [7:0] s_led2mst_data;

basic_owr #(
   //A periféria báziscíme.
   .BASEADDR(8'h80)
) leds (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_led2mst_data),    //Olvasási adatbusz
   
   //A GPIO interfész jelei.
   .gpio_out(ld)                       //Az IO lábakra kiírandó adat
);


//******************************************************************************
//* DIP kapcsoló periféria.                                                    *
//* Címtartomány: 0x81 (csak olvasható)                                        *
//******************************************************************************
wire [7:0] s_dip2mst_data;

basic_in #(
   //A periféria báziscíme.
   .BASEADDR(8'h81)
) dip_switch (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_slv2mst_data(s_dip2mst_data),    //Olvasási adatbusz
   
   //A GPIO interfész jelei.
   .gpio_in(sw)                        //Az IO lábak aktuális értéke
);


//******************************************************************************
//* Idõzítõ periféria.                                                         *
//* Címtartomány: 0x82 - 0x83 (írható/olvasható)                               *
//******************************************************************************
wire [7:0] s_tmr2mst_data;
wire       tmr_irq;

basic_timer #(
   //A periféria báziscíme.
   .BASEADDR(8'h82)
) timer (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_tmr2mst_data),    //Olvasási adatbusz
   
   //Megszakításkérõ kimenet.
   .irq(tmr_irq)
);


//******************************************************************************
//* Nyomógomb periféria.                                                       *
//* Címtartomány: 0x84 - 0x87 (írható/olvasható)                               *
//******************************************************************************
wire [7:0] s_btn2mst_data;
wire       btn_irq;

basic_in_irq #(
   //A periféria báziscíme.
   .BASEADDR(8'h84)
) buttons (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_btn2mst_data),    //Olvasási adatbusz
   
   //Megszakításkérõ kimenet.
   .irq(btn_irq),
   
   //A GPIO interfész jelei.
   .gpio_in({4'd0, bt})                //Az IO lábak aktuális értéke
);


//******************************************************************************
//* Slave USRT periféria.                                                      *
//* Címtartomány: 0x88 - 0x8B (írható/olvasható)                               *
//******************************************************************************
wire [7:0] s_usrt2mst_data;
wire       usrt_irq;

slave_usrt #(
   //A periféria báziscíme.
   .BASEADDR(8'h88)
) usrt (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A soros interfész jelei.
   .usrt_clk(dev_clk),                 //USRT órajel
   .usrt_rxd(dev_mosi),                //Soros adatbemenet
   .usrt_txd(dev_miso),                //Soros adatkimenet
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_usrt2mst_data),   //Olvasási adatbusz
   
   //Megszakításkérõ kimenet.
   .irq(usrt_irq)
);


//******************************************************************************
//* Kijelzõ periféria.                                                         *
//* Címtartomány: 0x90 - 0x9F (írható/olvasható)                               *
//******************************************************************************
wire [7:0] s_disp2mst_data;

basic_display #(
   //A periféria báziscíme.
   .BASEADDR(8'h90)
) display (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_disp2mst_data),   //Olvasási adatbusz
   
   //A kijelzõk vezérléséhez szükséges jelek.
   .seg_n(seg_n),                      //Szegmens vezérlõ jelek (aktív alacsony)
   .dig_n(dig_n),                      //Digit kiválasztó jelek (aktív alacsony)
   .col_n(col_n)                       //Oszlop kiválasztó jelek (aktív alacsony)
);


//******************************************************************************
//* GPIO (A bõvítõcsatlakozó).                                                 *
//* Címtartomány: 0xA0 - 0xA3 (írható/olvasható) -> 7-14 kivezetések           *
//* Címtartomány: 0xA4 - 0xA7 (írható/olvasható) -> 4-6, 15-16 kivezetések     *
//******************************************************************************
wire [7:0]  s_ioa2mst_data;
wire [7:0]  gpio_a_out;
wire [7:0]  gpio_a_dir;

wire [7:0]  s_ioae2mst_data;
wire [7:0]  gpio_a_ext_out;
wire [7:0]  gpio_a_ext_dir;

basic_io #(
   //A periféria báziscíme.
   .BASEADDR(8'ha0)
) gpio_a (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_ioa2mst_data),    //Olvasási adatbusz
   
   //A GPIO interfész jelei.
   .gpio_out(gpio_a_out),              //Az IO lábakra kiírandó adat
   .gpio_in(aio[14:7]),                //Az IO lábak aktuális értéke
   .gpio_dir(gpio_a_dir)               //A kimeneti meghajtó engedélyezõ jele
);

basic_io #(
   //A periféria báziscíme.
   .BASEADDR(8'ha4)
) gpio_a_ext (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_ioae2mst_data),   //Olvasási adatbusz
   
   //A GPIO interfész jelei.
   .gpio_out(gpio_a_ext_out),          //Az IO lábakra kiírandó adat
   .gpio_in({3'd0, ai, aio[6:4]}),     //Az IO lábak aktuális értéke
   .gpio_dir(gpio_a_ext_dir)           //A kimeneti meghajtó engedélyezõ jele
);

//Az A bõvítõcsatlakozó kétirányú vonalainak meghajtása.
wire [14:4] aio_gpio_out = {gpio_a_out, gpio_a_ext_out[2:0]};
wire [14:4] aio_gpio_dir = {gpio_a_dir, gpio_a_ext_dir[2:0]};

wire [7:0]  aio_vga_out;
wire        vga_en;
wire        ps2_en;

wire [14:4] aio_out = (vga_en | ps2_en) ? {2'b00, aio_vga_out, 1'b0} : aio_gpio_out;
wire [14:4] aio_dir = (vga_en | ps2_en) ? 11'b001_1111_1111          : aio_gpio_dir;

genvar i;

generate
   for (i = 4; i < 15; i = i + 1)
   begin: aio_loop
      assign aio[i] = (aio_dir[i]) ? aio_out[i] : 1'bz; 
   end
endgenerate


//******************************************************************************
//* GPIO (B bõvítõcsatlakozó).                                                 *
//* Címtartomány: 0xA8 - 0xAB (írható/olvasható) -> 7-14 kivezetések           *
//* Címtartomány: 0xAC - 0xAF (írható/olvasható) -> 4-6, 15-16 kivezetések     *
//******************************************************************************
wire [7:0]  s_iob2mst_data;
wire [7:0]  gpio_b_out;
wire [7:0]  gpio_b_dir;

wire [7:0]  s_iobe2mst_data;
wire [7:0]  gpio_b_ext_out;
wire [7:0]  gpio_b_ext_dir;

basic_io #(
   //A periféria báziscíme.
   .BASEADDR(8'ha8)
) gpio_b (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_iob2mst_data),    //Olvasási adatbusz
   
   //A GPIO interfész jelei.
   .gpio_out(gpio_b_out),              //Az IO lábakra kiírandó adat
   .gpio_in(bio[14:7]),                //Az IO lábak aktuális értéke
   .gpio_dir(gpio_b_dir)               //A kimeneti meghajtó engedélyezõ jele
);

basic_io #(
   //A periféria báziscíme.
   .BASEADDR(8'hac)
) gpio_b_ext (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_iobe2mst_data),   //Olvasási adatbusz
   
   //A GPIO interfész jelei.
   .gpio_out(gpio_b_ext_out),          //Az IO lábakra kiírandó adat
   .gpio_in({3'd0, bi, bio[6:4]}),     //Az IO lábak aktuális értéke
   .gpio_dir(gpio_b_ext_dir)           //A kimeneti meghajtó engedélyezõ jele
);

//A B bõvítõcsatlakozó jeleinek meghajtása.
wire [14:4] bio_out = {gpio_b_out, gpio_b_ext_out[2:0]};
wire [14:4] bio_dir = {gpio_b_dir, gpio_b_ext_dir[2:0]};

genvar j;

generate
   for (j = 4; j < 15; j = j + 1)
   begin: bio_loop
      assign bio[j] = (bio_dir[j]) ? bio_out[j] : 1'bz; 
   end
endgenerate


//******************************************************************************
//* VGA interfész (A bõvítõcsatlakozó).                                        *
//* Címtartomány: 0xB0 - 0xB7 (írható/olvasható)                               *
//******************************************************************************
wire [7:0] s_vga2mst_data;
wire       vga_irq;

vga_display #(
   //A periféria báziscíme.
   .BASEADDR(8'hb0)
) vga_display (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_vga2mst_data),    //Olvasási adatbusz
   
   //Megszakításkérõ kimenet.
   .irq(vga_irq),
   
   //A VGA interfész jelei.
   .vga_enabled(vga_en),               //A VGA interfész engedélyezett
   .rgb_out(aio_vga_out[5:0]),         //Szín adatok
   .hsync_out(aio_vga_out[7]),         //Horizontális szinkronjel
   .vsync_out(aio_vga_out[6])          //Vertikális szinkronjel
);


//******************************************************************************
//* PS/2 billentyûzet interfész (A bõvítõcsatlakozó).                          *
//* Címtartomány: 0xB8 - 0xB9 (írható/olvasható)                               *
//******************************************************************************
wire [7:0] s_kb2mst_data;
wire       kb_irq;

ps2_keyboard #(
   //A periféria báziscíme.
   .BASEADDR(8'hb8)
) ps2_keyboard (
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Reset jel
   
   //A PS/2 interfész jelei.
   .ps2_clk(aio[13]),                  //Órajel bemenet
   .ps2_data(aio[14]),                 //Soros adatbemenet
   .ps2_enable(ps2_en),                //A PS/2 interfész engedélyezõ jele
   
   //A slave busz interfész jelei.
   .s_mst2slv_addr(mst2slv_addr),      //Címbusz
   .s_mst2slv_wr(mst2slv_wr),          //Írás engedélyezõ jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvasás engedélyezõ jel
   .s_mst2slv_data(mst2slv_data),      //Írási adatbusz
   .s_slv2mst_data(s_kb2mst_data),     //Olvasási adatbusz
   
   //Megszakításkérõ kimenet.
   .irq(kb_irq)
);


//******************************************************************************
//* Az olvasási adatbusz és a megszakításkérõ bemenet meghajtása.              *
//******************************************************************************
assign slv2mst_data = s_mem2mst_data  |
                      s_led2mst_data  |
                      s_dip2mst_data  |
                      s_tmr2mst_data  |
                      s_btn2mst_data  |
                      s_usrt2mst_data |
                      s_dma2mst_data  |
                      s_disp2mst_data |
                      s_ioa2mst_data  |
                      s_ioae2mst_data |
                      s_iob2mst_data  |
                      s_iobe2mst_data |
                      s_vga2mst_data  |
                      s_kb2mst_data;
                          
assign irq = tmr_irq | btn_irq | usrt_irq | dma_irq | vga_irq | kb_irq;


endmodule
