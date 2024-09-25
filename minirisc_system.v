//******************************************************************************
//* MiniRISC rendszer top-level modul.                                         *
//******************************************************************************
module minirisc_system(
   //�rajel �s reset.
   input  wire         clk16M,      //16 MHz �rajel
   input  wire         rst,         //Reset nyom�gomb
   input  wire         irq
);

//******************************************************************************
//* �rajel �s reset.                                                           *
//******************************************************************************
wire clk = clk16M;


//******************************************************************************
//* Az adatmem�ria busz interf�szhez tartoz� jelek.                            *
//******************************************************************************
//A processzor master adatmem�ria interf�sz�nek kimenetei.
wire [7:0] cpu2slv_addr;
wire       cpu2slv_wr;
wire       cpu2slv_rd;
wire [7:0] cpu2slv_data;

//Olvas�si adatbusz a slave egys�gekt�l a master egys�gek fel�.
wire [7:0] slv2mst_data;

//Jelek a slave egys�gek fel�.
wire [7:0] mst2slv_addr = cpu2slv_addr;
wire       mst2slv_wr   = cpu2slv_wr  ;
wire       mst2slv_rd   = cpu2slv_rd  ;
wire [7:0] mst2slv_data = cpu2slv_data;

wire [7:0] SP;
wire [7:0] dbg_stack_top;


//******************************************************************************
//* Adatmem�ria busz arbiter.                                                  *
//******************************************************************************
wire cpu_bus_req;
wire cpu_bus_grant;
wire dma_bus_grant;

bus_arbiter_2m_fixed bus_arbiter(  
   //A master 0 egys�ghez tartoz� jelek.
   .mst0_req(cpu_bus_req),             //Busz hozz�f�r�s k�r�se
   .mst0_grant(cpu_bus_grant),         //Busz hozz�f�r�s megad�sa
   
   //A master 1 egys�ghez tartoz� jelek.
   .mst1_req(1'b0),             //Busz hozz�f�r�s k�r�se
   .mst1_grant(dma_bus_grant)          //Busz hozz�f�r�s megad�sa
);


//******************************************************************************
//* MiniRISC CPU v2.0.                                                         *
//******************************************************************************
wire [7:0]  cpu2prgmem_addr;
wire [15:0] prgmem2cpu_data;

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
   .dbg2cpu_data(23'b0),        //Jelek a debug modult�l a CPU fel�
   .cpu2dbg_data(cpu2dbg_data)         //Jelek a CPU-t�l a debug modul fel�
);


//******************************************************************************
//* 256 x 16 bites programmem�ria (elosztott RAM).                             *
//******************************************************************************
(* ram_style = "distributed" *)
reg [15:0] prg_mem [255:0];

initial begin
   prg_mem[0] = 16'hCB01; // MOV R11 1
   prg_mem[1] = 16'hF1DB; // LD  R1  R11
   prg_mem[2] = 16'hCC02; // MOV R12 2

      prg_mem[3] = 16'h2001;
      prg_mem[4] = 16'hCEFA;
      prg_mem[5] = 16'h9E00;

prg_mem[6] = 16'hCC91;
prg_mem[7] = 16'hACEF;
prg_mem[8] = 16'hEC0D;
prg_mem[9] = 16'hED0D;
prg_mem[10] = 16'hEA0D;

prg_mem[13] = 16'hCD6F;
prg_mem[14] = 16'hAD6F;
prg_mem[15] = 16'hEF13;
prg_mem[16] = 16'hEE13;

   prg_mem[3 +16] = 16'hF2DC; // LD  R2  R12
   prg_mem[4 +16] = 16'hCD03; // MOV R13 3
   prg_mem[5 +16] = 16'hF3DD; // LD  R3  R133
   
   prg_mem[6 +16] = 16'hA1D3;
   prg_mem[7 +16] = 16'hA100;
   prg_mem[8 +16] = 16'hF3A1;
   
   prg_mem[9 +16]  = 16'hF2A1;
   prg_mem[10+16] = 16'hF1B3;
   prg_mem[11+16] = 16'hB3D3;
      prg_mem[12+16] = 16'hE932; // JSR 50
      prg_mem[13+16] = 16'hE935; // JSR 52
   prg_mem[12+16+2] = 16'hB178;
   
   prg_mem[13+16+2] = 16'hF1A3;
   prg_mem[14+16+2] = 16'hF3B1;
   prg_mem[15+16+2] = 16'hB1D3;
   prg_mem[16+16+2] = 16'hB3D3;
   prg_mem[17+16+2] = 16'hF2B1;
   
   prg_mem[18+16 +16] = 16'hCA05;
   prg_mem[19+16 +16] = 16'h0A05;
   prg_mem[20+16 +16] = 16'hFBF0; // RTI  doesn't change flages
   prg_mem[21+16 +16] = 16'hC904;
   prg_mem[22+16 +16] = 16'h0909;
   prg_mem[23+16 +16] = 16'hFAF0; // RTS changes flags
   prg_mem[24+16 +16] = 16'h0000;
   prg_mem[25+16 +16] = 16'h0000;
   
end

/* always @(posedge clk)
begin
   if (dbg2prgmem_wr)
      prg_mem[dbg2prgmem_addr] <= dbg2prgmem_data;
end */

assign prgmem2cpu_data = prg_mem[cpu2prgmem_addr];


//******************************************************************************
//* 128 x 8 bites adatmem�ria.                                                 *
//* C�mtartom�ny: 0x00 - 0x7F (�rhat�/olvashat�)                               *
//******************************************************************************
(* ram_style = "distributed" *)
reg  [7:0] data_mem [127:0];

initial begin
   data_mem[1] = 8'hD3;
   data_mem[2] = 8'h78;
   data_mem[3] = 8'hD3;
   data_mem[127] = 8'hCC;
end

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
//* Az olvas�si adatbusz �s a megszak�t�sk�r� bemenet meghajt�sa.              *
//******************************************************************************
assign slv2mst_data = s_mem2mst_data;


endmodule
