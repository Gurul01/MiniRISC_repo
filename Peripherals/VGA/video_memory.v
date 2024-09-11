`timescale 1ns / 1ps

//******************************************************************************
//* Video memória modul.                                                       *
//******************************************************************************
module video_memory(
   //Órajel.
   input  wire        clk,
   
   //Üzemmód kiválasztó jel (0: grafikus, 1: karakteres).
   input  wire        mode,
   
   //Írási/olvasási port a CPU felé.
   input  wire [15:0] cpu_addr,        //Címbusz
   input  wire        cpu_write,       //Írás engedélyezõ jel
   input  wire [7:0]  cpu_din,         //Írási adatbusz
   output reg  [7:0]  cpu_dout,        //Olvasási adatbusz
   
   //Olvasási port a VGA modul felé.
   input  wire [15:0] vga_addr,        //Olvasási cím
   output reg  [2:0]  vga_rgb_data,    //Adat (grafikus mód)
   output wire [15:0] vga_char_data    //Adat (karakteres mód)
);

//******************************************************************************
//* A címek késleltetése az olvasáshoz.                                        *
//******************************************************************************
reg [15:0] cpu_addr_reg;
reg [15:0] vga_addr_reg;

always @(posedge clk)
begin
   cpu_addr_reg <= cpu_addr;
   vga_addr_reg <= vga_addr;
end


//******************************************************************************
//* 8k x 18 bit dual-port blokk-RAM. A paritás bitek kihasználása érdekében    *
//* a memóriát primitívek megpéldányosításával valósítjuk meg.                 *
//******************************************************************************
reg  [8:0]  din_al;
reg  [8:0]  din_ah;
wire [35:0] mem_do_al;
wire [35:0] mem_do_ah;
wire [35:0] mem_do_bl;
wire [35:0] mem_do_bh;

genvar i;

generate
   for (i = 0; i < 4; i = i + 1)
   begin: mem_loop 
      //A memória írás engedélyezõ jelei.
      wire mem_wr_l = cpu_write & (cpu_addr[0] == 0) & (cpu_addr[13:12] == i);
      wire mem_wr_h = cpu_write & (cpu_addr[0] == 1) & (cpu_addr[13:12] == i);

      //A memória alsó 9 bitje.
      RAMB16_S9_S9 #(
         .WRITE_MODE_A("WRITE_FIRST"),
         .WRITE_MODE_B("WRITE_FIRST")
      ) video_mem_l (
         .DOA(mem_do_al[9*i+7:9*i]),   // Port A 8-bit Data Output
         .DOB(mem_do_bl[9*i+7:9*i]),   // Port B 8-bit Data Output
         .DOPA(mem_do_al[9*i+8]),      // Port A 1-bit Parity Output
         .DOPB(mem_do_bl[9*i+8]),      // Port B 1-bit Parity Output
         .ADDRA(cpu_addr[11:1]),       // Port A 11-bit Address Input
         .ADDRB(vga_addr[11:1]),       // Port B 11-bit Address Input
         .CLKA(clk),                   // Port A Clock
         .CLKB(clk),                   // Port B Clock
         .DIA(din_al[7:0]),            // Port A 8-bit Data Input
         .DIB(8'd0),                   // Port B 8-bit Data Input
         .DIPA(din_al[8]),             // Port A 1-bit parity Input
         .DIPB(1'b0),                  // Port-B 1-bit parity Input
         .ENA(1'b1),                   // Port A RAM Enable Input
         .ENB(1'b1),                   // Port B RAM Enable Input
         .SSRA(1'b0),                  // Port A Synchronous Set/Reset Input
         .SSRB(1'b0),                  // Port B Synchronous Set/Reset Input
         .WEA(mem_wr_l),               // Port A Write Enable Input
         .WEB(1'b0)                    // Port B Write Enable Input
      );

      //A memória felsõ 9 bitje.
      RAMB16_S9_S9 #(
         .WRITE_MODE_A("WRITE_FIRST"),
         .WRITE_MODE_B("WRITE_FIRST")
      ) video_mem_h (
         .DOA(mem_do_ah[9*i+7:9*i]),   // Port A 8-bit Data Output
         .DOB(mem_do_bh[9*i+7:9*i]),   // Port B 8-bit Data Output
         .DOPA(mem_do_ah[9*i+8]),      // Port A 1-bit Parity Output
         .DOPB(mem_do_bh[9*i+8]),      // Port B 1-bit Parity Output
         .ADDRA(cpu_addr[11:1]),       // Port A 11-bit Address Input
         .ADDRB(vga_addr[11:1]),       // Port B 11-bit Address Input
         .CLKA(clk),                   // Port A Clock
         .CLKB(clk),                   // Port B Clock
         .DIA(din_ah[7:0]),            // Port A 8-bit Data Input
         .DIB(8'd0),                   // Port B 8-bit Data Input
         .DIPA(din_ah[8]),             // Port A 1-bit parity Input
         .DIPB(1'b0),                  // Port-B 1-bit parity Input
         .ENA(1'b1),                   // Port A RAM Enable Input
         .ENB(1'b1),                   // Port B RAM Enable Input
         .SSRA(1'b0),                  // Port A Synchronous Set/Reset Input
         .SSRB(1'b0),                  // Port B Synchronous Set/Reset Input
         .WEA(mem_wr_h),               // Port A Write Enable Input
         .WEB(1'b0)                    // Port B Write Enable Input
      );
   end
endgenerate

//A memória adatkimenetei.
reg [8:0] dout_al;
reg [8:0] dout_ah;
reg [8:0] dout_bl;
reg [8:0] dout_bh;

always @(*)
begin
   case (cpu_addr_reg[13:12])
      2'b00: dout_al <= mem_do_al[8:0];
      2'b01: dout_al <= mem_do_al[17:9];
      2'b10: dout_al <= mem_do_al[26:18];
      2'b11: dout_al <= mem_do_al[35:27];
   endcase
end

always @(*)
begin
   case (cpu_addr_reg[13:12])
      2'b00: dout_ah <= mem_do_ah[8:0];
      2'b01: dout_ah <= mem_do_ah[17:9];
      2'b10: dout_ah <= mem_do_ah[26:18];
      2'b11: dout_ah <= mem_do_ah[35:27];
   endcase
end

always @(*)
begin
   case (vga_addr_reg[13:12])
      2'b00: dout_bl <= mem_do_bl[8:0];
      2'b01: dout_bl <= mem_do_bl[17:9];
      2'b10: dout_bl <= mem_do_bl[26:18];
      2'b11: dout_bl <= mem_do_bl[35:27];
   endcase
end

always @(*)
begin
   case (vga_addr_reg[13:12])
      2'b00: dout_bh <= mem_do_bh[8:0];
      2'b01: dout_bh <= mem_do_bh[17:9];
      2'b10: dout_bh <= mem_do_bh[26:18];
      2'b11: dout_bh <= mem_do_bh[35:27];
   endcase
end


//******************************************************************************
//* A CPU oldali jelek elõállítása ("A" port).                                 *
//******************************************************************************
//Írási adatbusz. Karakteres üzemmódban a memória írása és olvasása bájtosan
//történik, grafikus üzemmódban pedig 3 bites egységekben. Utóbbi esetben az
//adott 3 bitet a CPU cím felsõ 2 bitje választja ki. Grafikus üzemmódban az
//írás csak minden második órajel periódusban történhet!
always @(*)
begin
   if (mode)
      din_al <= {1'b0, cpu_din};
   else
      case (cpu_addr[15:14])
         2'b00: din_al <= {dout_al[8:6], dout_al[5:3], cpu_din[2:0]};
         2'b01: din_al <= {dout_al[8:6], cpu_din[2:0], dout_al[2:0]};
         2'b10: din_al <= {cpu_din[2:0], dout_al[5:3], dout_al[2:0]};
         2'b11: din_al <= {dout_al[8:6], dout_al[5:3], cpu_din[2:0]};
      endcase
end

always @(*)
begin
   if (mode)
      din_ah <= {1'b0, cpu_din};
   else
      case (cpu_addr[15:14])
         2'b00: din_ah <= {dout_ah[8:6], dout_ah[5:3], cpu_din[2:0]};
         2'b01: din_ah <= {dout_ah[8:6], cpu_din[2:0], dout_ah[2:0]};
         2'b10: din_ah <= {cpu_din[2:0], dout_ah[5:3], dout_ah[2:0]};
         2'b11: din_ah <= {dout_ah[8:6], dout_ah[5:3], cpu_din[2:0]};
      endcase
end

//Olvasási adatbusz.
always @(*)
begin
   if (cpu_addr_reg[0])
      if (mode)
         cpu_dout <= dout_ah[7:0];
      else
         case (cpu_addr_reg[15:14])
            2'b00: cpu_dout <= {5'd0, dout_ah[2:0]};
            2'b01: cpu_dout <= {5'd0, dout_ah[5:3]};
            2'b10: cpu_dout <= {5'd0, dout_ah[8:6]};
            2'b11: cpu_dout <= {5'd0, dout_ah[2:0]};
         endcase
   else
      if (mode)
         cpu_dout <= dout_al[7:0];
      else
         case (cpu_addr_reg[15:14])
            2'b00: cpu_dout <= {5'd0, dout_al[2:0]};
            2'b01: cpu_dout <= {5'd0, dout_al[5:3]};
            2'b10: cpu_dout <= {5'd0, dout_al[8:6]};
            2'b11: cpu_dout <= {5'd0, dout_al[2:0]};
         endcase
end


//******************************************************************************
//* A VGA oldali jelek elõállítása ("B" port).                                 *
//******************************************************************************
//Az adat karakteres üzemmód esetén.
assign vga_char_data = {dout_bh[7:0], dout_bl[7:0]};

//Az adat grafikus üzemmód esetén.
always @(*)
begin
   if (vga_addr_reg[0])
      case (vga_addr_reg[15:14])
         2'b00: vga_rgb_data <= dout_bh[2:0];
         2'b01: vga_rgb_data <= dout_bh[5:3];
         2'b10: vga_rgb_data <= dout_bh[8:6];
         2'b11: vga_rgb_data <= dout_bh[2:0];
      endcase
   else
      case (vga_addr_reg[15:14])
         2'b00: vga_rgb_data <= dout_bl[2:0];
         2'b01: vga_rgb_data <= dout_bl[5:3];
         2'b10: vga_rgb_data <= dout_bl[8:6];
         2'b11: vga_rgb_data <= dout_bl[2:0];
      endcase
end

endmodule
