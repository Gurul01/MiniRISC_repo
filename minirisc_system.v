//******************************************************************************
//* MiniRISC rendszer top-level modul.                                         *
//******************************************************************************
module minirisc_system(
   //�rajel �s reset.
   input  wire         clk16M,      //16 MHz �rajel
   input  wire         rstbt,       //Reset nyom�gomb
   
   //Perif�ri�k.
   input  wire [7:0]   sw,          //DIP kapcsol�
   input  wire [3:0]   bt,          //Nyom�gombok
   output wire [7:0]   ld,          //LED-ek
   output wire [7:0]   seg_n,       //Szegmens vez�rl� jelek (akt�v alacsony)
   output wire [3:0]   dig_n,       //Digit kiv�laszt� jelek (akt�v alacsony)
   output wire [4:0]   col_n,       //Oszlop kiv�laszt� jelek (akt�v alacsony)
   
   //USRT.
   input  wire         dev_clk,     //USRT �rajel
   input  wire         dev_mosi,    //Soros adatbemenet
   output wire         dev_miso,    //Soros adatkimenet
   
   //GPIO (A b�v�t�csatlakoz�).
   inout  wire [14:4]  aio,         //K�tir�ny� I/O vonalak
   input  wire [16:15] ai,          //Csak bemeneti vonalak
   
   //GPIO (B b�v�t�csatlakoz�).
   inout  wire [14:4]  bio,         //K�tir�ny� I/O vonalak
   input  wire [16:15] bi           //Csak bemeneti vonalak
);

//******************************************************************************
//* �rajel �s reset.                                                           *
//******************************************************************************
wire clk = clk16M;
wire rst;


//******************************************************************************
//* Az adatmem�ria busz interf�szhez tartoz� jelek.                            *
//******************************************************************************
//A processzor master adatmem�ria interf�sz�nek kimenetei.
wire [7:0] cpu2slv_addr;
wire       cpu2slv_wr;
wire       cpu2slv_rd;
wire [7:0] cpu2slv_data;

//A DMA vez�rl� master adatmem�ria interf�sz�nek kimenetei.
wire [7:0] dma2slv_addr;
wire       dma2slv_wr;
wire       dma2slv_rd;
wire [7:0] dma2slv_data;

//Olvas�si adatbusz a slave egys�gekt�l a master egys�gek fel�.
wire [7:0] slv2mst_data;

//Jelek a slave egys�gek fel�.
wire [7:0] mst2slv_addr = cpu2slv_addr | dma2slv_addr;
wire       mst2slv_wr   = cpu2slv_wr   | dma2slv_wr;
wire       mst2slv_rd   = cpu2slv_rd   | dma2slv_rd;
wire [7:0] mst2slv_data = cpu2slv_data | dma2slv_data;

wire [7:0] SP;
wire [7:0] dbg_stack_top;


//******************************************************************************
//* Adatmem�ria busz arbiter.                                                  *
//******************************************************************************
wire cpu_bus_req;
wire cpu_bus_grant;
wire dma_bus_req;
wire dma_bus_grant;

bus_arbiter_2m_fixed bus_arbiter(  
   //A master 0 egys�ghez tartoz� jelek.
   .mst0_req(cpu_bus_req),             //Busz hozz�f�r�s k�r�se
   .mst0_grant(cpu_bus_grant),         //Busz hozz�f�r�s megad�sa
   
   //A master 1 egys�ghez tartoz� jelek.
   .mst1_req(dma_bus_req),             //Busz hozz�f�r�s k�r�se
   .mst1_grant(dma_bus_grant)          //Busz hozz�f�r�s megad�sa
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
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Aszinkron reset
   
   //Busz interf�sz a programmem�ria el�r�s�hez.
   .cpu2pmem_addr(cpu2prgmem_addr),    //C�mbusz
   .pmem2cpu_data(prgmem2cpu_data),    //Olvas�si adatbusz
   
   //Master busz interf�sz az adatmem�ria el�r�s�hez.
   .m_bus_req(cpu_bus_req),            //Busz hozz�f�r�s k�r�se
   .m_bus_grant(cpu_bus_grant),        //Busz hozz�f�r�s megad�sa
   .m_mst2slv_addr(cpu2slv_addr),      //C�mbusz
   .m_mst2slv_wr(cpu2slv_wr),          //�r�s enged�lyez� jel
   .m_mst2slv_rd(cpu2slv_rd),          //Olvas�s enged�lyez� jel
   .m_mst2slv_data(cpu2slv_data),      //�r�si adatbusz
   .m_slv2mst_data(slv2mst_data),      //Olvas�si adatbusz
   
   //Megszak�t�sk�r� bemenet (akt�v magas szint�rz�keny).
   .irq(irq),

   .SP(SP),
   .dbg_stack_top(dbg_stack_top),
   
   //Debug interf�sz.
   .dbg2cpu_data(dbg2cpu_data),        //Jelek a debug modult�l a CPU fel�
   .cpu2dbg_data(cpu2dbg_data)         //Jelek a CPU-t�l a debug modul fel�
);


//******************************************************************************
//* Debug modul.                                                               *
//******************************************************************************
wire [7:0]  dbg2prgmem_addr;
wire [15:0] dbg2prgmem_data;
wire        dbg2prgmem_wr;

debug_module debug_module(
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst_in(rstbt),                     //Reset bemenet
   .rst_out(rst),                      //Reset jel a rendszer sz�m�ra
   
   //A programmem�ria �r�s�hoz sz�ks�ges jelek.
   .dbg2pmem_addr(dbg2prgmem_addr),    //�r�si c�m
   .dbg2pmem_data(dbg2prgmem_data),    //A mem�ri�ba �rand� adat
   .dbg2pmem_wr(dbg2prgmem_wr),        //�r�s enged�lyez� jel
   
   //Debug interf�sz a CPU fel�.
   .dbg2cpu_data(dbg2cpu_data),        //Jelek a debug modult�l a CPU fel�
   .cpu2dbg_data(cpu2dbg_data)         //Jelek a CPU-t�l a debug modul fel�
);


//******************************************************************************
//* 256 x 16 bites programmem�ria (elosztott RAM).                             *
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
//* DMA vez�rl�.                                                               *
//* C�mtartom�ny: 0x8C - 0x8F (�rhat�/olvashat�)                               *
//******************************************************************************
wire [7:0] s_dma2mst_data;
wire       dma_irq;

dma_controller #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'h8c)
) dma_controller (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei (regiszter el�r�s).
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_dma2mst_data),    //Olvas�si adatbusz
   
   //A master busz interf�sz jelei (DMA �tvitel).
   .m_bus_req(dma_bus_req),            //Busz hozz�f�r�s k�r�se
   .m_bus_grant(dma_bus_grant),        //Busz hozz�f�r�s megad�sa
   .m_mst2slv_addr(dma2slv_addr),      //C�mbusz
   .m_mst2slv_wr(dma2slv_wr),          //�r�s enged�lyez� jel
   .m_mst2slv_rd(dma2slv_rd),          //Olvas�s enged�lyez� jel
   .m_mst2slv_data(dma2slv_data),      //�r�si adatbusz
   .m_slv2mst_data(slv2mst_data),      //Olvas�si adatbusz
   
   //Megszak�t�sk�r� kimenet.
   .irq(dma_irq)
);


//******************************************************************************
//* 128 x 8 bites adatmem�ria.                                                 *
//* C�mtartom�ny: 0x00 - 0x7F (�rhat�/olvashat�)                               *
//******************************************************************************
(* ram_style = "distributed" *)
reg  [7:0] data_mem [127:0];

wire [6:0] data_mem_addr  = mst2slv_addr[6:0];
wire       data_mem_wr    = mst2slv_wr & ~mst2slv_addr[7];
wire       data_mem_rd    = mst2slv_rd & ~mst2slv_addr[7];
wire [7:0] data_mem_din   = mst2slv_data;
wire [7:0] s_mem2mst_data = (data_mem_rd) ? data_mem[data_mem_addr] : 8'd0;

assign dbg_stack_top = data_mem[SP];

always @(posedge clk)
begin
   if (data_mem_wr)
      data_mem[data_mem_addr] <= data_mem_din;
end


//******************************************************************************
//* LED perif�ria.                                                             *
//* C�mtartom�ny: 0x80 (�rhat�/olvashat�)                                      *
//******************************************************************************
wire [7:0] s_led2mst_data;

basic_owr #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'h80)
) leds (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_led2mst_data),    //Olvas�si adatbusz
   
   //A GPIO interf�sz jelei.
   .gpio_out(ld)                       //Az IO l�bakra ki�rand� adat
);


//******************************************************************************
//* DIP kapcsol� perif�ria.                                                    *
//* C�mtartom�ny: 0x81 (csak olvashat�)                                        *
//******************************************************************************
wire [7:0] s_dip2mst_data;

basic_in #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'h81)
) dip_switch (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_slv2mst_data(s_dip2mst_data),    //Olvas�si adatbusz
   
   //A GPIO interf�sz jelei.
   .gpio_in(sw)                        //Az IO l�bak aktu�lis �rt�ke
);


//******************************************************************************
//* Id�z�t� perif�ria.                                                         *
//* C�mtartom�ny: 0x82 - 0x83 (�rhat�/olvashat�)                               *
//******************************************************************************
wire [7:0] s_tmr2mst_data;
wire       tmr_irq;

basic_timer #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'h82)
) timer (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_tmr2mst_data),    //Olvas�si adatbusz
   
   //Megszak�t�sk�r� kimenet.
   .irq(tmr_irq)
);


//******************************************************************************
//* Nyom�gomb perif�ria.                                                       *
//* C�mtartom�ny: 0x84 - 0x87 (�rhat�/olvashat�)                               *
//******************************************************************************
wire [7:0] s_btn2mst_data;
wire       btn_irq;

basic_in_irq #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'h84)
) buttons (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_btn2mst_data),    //Olvas�si adatbusz
   
   //Megszak�t�sk�r� kimenet.
   .irq(btn_irq),
   
   //A GPIO interf�sz jelei.
   .gpio_in({4'd0, bt})                //Az IO l�bak aktu�lis �rt�ke
);


//******************************************************************************
//* Slave USRT perif�ria.                                                      *
//* C�mtartom�ny: 0x88 - 0x8B (�rhat�/olvashat�)                               *
//******************************************************************************
wire [7:0] s_usrt2mst_data;
wire       usrt_irq;

slave_usrt #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'h88)
) usrt (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A soros interf�sz jelei.
   .usrt_clk(dev_clk),                 //USRT �rajel
   .usrt_rxd(dev_mosi),                //Soros adatbemenet
   .usrt_txd(dev_miso),                //Soros adatkimenet
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_usrt2mst_data),   //Olvas�si adatbusz
   
   //Megszak�t�sk�r� kimenet.
   .irq(usrt_irq)
);


//******************************************************************************
//* Kijelz� perif�ria.                                                         *
//* C�mtartom�ny: 0x90 - 0x9F (�rhat�/olvashat�)                               *
//******************************************************************************
wire [7:0] s_disp2mst_data;

basic_display #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'h90)
) display (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_disp2mst_data),   //Olvas�si adatbusz
   
   //A kijelz�k vez�rl�s�hez sz�ks�ges jelek.
   .seg_n(seg_n),                      //Szegmens vez�rl� jelek (akt�v alacsony)
   .dig_n(dig_n),                      //Digit kiv�laszt� jelek (akt�v alacsony)
   .col_n(col_n)                       //Oszlop kiv�laszt� jelek (akt�v alacsony)
);


//******************************************************************************
//* GPIO (A b�v�t�csatlakoz�).                                                 *
//* C�mtartom�ny: 0xA0 - 0xA3 (�rhat�/olvashat�) -> 7-14 kivezet�sek           *
//* C�mtartom�ny: 0xA4 - 0xA7 (�rhat�/olvashat�) -> 4-6, 15-16 kivezet�sek     *
//******************************************************************************
wire [7:0]  s_ioa2mst_data;
wire [7:0]  gpio_a_out;
wire [7:0]  gpio_a_dir;

wire [7:0]  s_ioae2mst_data;
wire [7:0]  gpio_a_ext_out;
wire [7:0]  gpio_a_ext_dir;

basic_io #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'ha0)
) gpio_a (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_ioa2mst_data),    //Olvas�si adatbusz
   
   //A GPIO interf�sz jelei.
   .gpio_out(gpio_a_out),              //Az IO l�bakra ki�rand� adat
   .gpio_in(aio[14:7]),                //Az IO l�bak aktu�lis �rt�ke
   .gpio_dir(gpio_a_dir)               //A kimeneti meghajt� enged�lyez� jele
);

basic_io #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'ha4)
) gpio_a_ext (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_ioae2mst_data),   //Olvas�si adatbusz
   
   //A GPIO interf�sz jelei.
   .gpio_out(gpio_a_ext_out),          //Az IO l�bakra ki�rand� adat
   .gpio_in({3'd0, ai, aio[6:4]}),     //Az IO l�bak aktu�lis �rt�ke
   .gpio_dir(gpio_a_ext_dir)           //A kimeneti meghajt� enged�lyez� jele
);

//Az A b�v�t�csatlakoz� k�tir�ny� vonalainak meghajt�sa.
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
//* GPIO (B b�v�t�csatlakoz�).                                                 *
//* C�mtartom�ny: 0xA8 - 0xAB (�rhat�/olvashat�) -> 7-14 kivezet�sek           *
//* C�mtartom�ny: 0xAC - 0xAF (�rhat�/olvashat�) -> 4-6, 15-16 kivezet�sek     *
//******************************************************************************
wire [7:0]  s_iob2mst_data;
wire [7:0]  gpio_b_out;
wire [7:0]  gpio_b_dir;

wire [7:0]  s_iobe2mst_data;
wire [7:0]  gpio_b_ext_out;
wire [7:0]  gpio_b_ext_dir;

basic_io #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'ha8)
) gpio_b (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_iob2mst_data),    //Olvas�si adatbusz
   
   //A GPIO interf�sz jelei.
   .gpio_out(gpio_b_out),              //Az IO l�bakra ki�rand� adat
   .gpio_in(bio[14:7]),                //Az IO l�bak aktu�lis �rt�ke
   .gpio_dir(gpio_b_dir)               //A kimeneti meghajt� enged�lyez� jele
);

basic_io #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'hac)
) gpio_b_ext (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_iobe2mst_data),   //Olvas�si adatbusz
   
   //A GPIO interf�sz jelei.
   .gpio_out(gpio_b_ext_out),          //Az IO l�bakra ki�rand� adat
   .gpio_in({3'd0, bi, bio[6:4]}),     //Az IO l�bak aktu�lis �rt�ke
   .gpio_dir(gpio_b_ext_dir)           //A kimeneti meghajt� enged�lyez� jele
);

//A B b�v�t�csatlakoz� jeleinek meghajt�sa.
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
//* VGA interf�sz (A b�v�t�csatlakoz�).                                        *
//* C�mtartom�ny: 0xB0 - 0xB7 (�rhat�/olvashat�)                               *
//******************************************************************************
wire [7:0] s_vga2mst_data;
wire       vga_irq;

vga_display #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'hb0)
) vga_display (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_vga2mst_data),    //Olvas�si adatbusz
   
   //Megszak�t�sk�r� kimenet.
   .irq(vga_irq),
   
   //A VGA interf�sz jelei.
   .vga_enabled(vga_en),               //A VGA interf�sz enged�lyezett
   .rgb_out(aio_vga_out[5:0]),         //Sz�n adatok
   .hsync_out(aio_vga_out[7]),         //Horizont�lis szinkronjel
   .vsync_out(aio_vga_out[6])          //Vertik�lis szinkronjel
);


//******************************************************************************
//* PS/2 billenty�zet interf�sz (A b�v�t�csatlakoz�).                          *
//* C�mtartom�ny: 0xB8 - 0xB9 (�rhat�/olvashat�)                               *
//******************************************************************************
wire [7:0] s_kb2mst_data;
wire       kb_irq;

ps2_keyboard #(
   //A perif�ria b�zisc�me.
   .BASEADDR(8'hb8)
) ps2_keyboard (
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Reset jel
   
   //A PS/2 interf�sz jelei.
   .ps2_clk(aio[13]),                  //�rajel bemenet
   .ps2_data(aio[14]),                 //Soros adatbemenet
   .ps2_enable(ps2_en),                //A PS/2 interf�sz enged�lyez� jele
   
   //A slave busz interf�sz jelei.
   .s_mst2slv_addr(mst2slv_addr),      //C�mbusz
   .s_mst2slv_wr(mst2slv_wr),          //�r�s enged�lyez� jel
   .s_mst2slv_rd(mst2slv_rd),          //Olvas�s enged�lyez� jel
   .s_mst2slv_data(mst2slv_data),      //�r�si adatbusz
   .s_slv2mst_data(s_kb2mst_data),     //Olvas�si adatbusz
   
   //Megszak�t�sk�r� kimenet.
   .irq(kb_irq)
);


//******************************************************************************
//* Az olvas�si adatbusz �s a megszak�t�sk�r� bemenet meghajt�sa.              *
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
