`timescale 1ns / 1ps

//******************************************************************************
//* Debug modul a MiniRISC v2.0 processzort tartalmaz� rendszerek sz�m�ra.     *
//* Lehet�v� teszi a debug funkci�k haszn�lat�t a JTAG interf�szen kereszt�l.  *
//******************************************************************************
module debug_module(
   //�rajel �s reset.
   input  wire        clk,             //�rajel
   input  wire        rst_in,          //Reset bemenet
   output wire        rst_out,         //Reset jel a rendszer sz�m�ra
   
   //A programmem�ria �r�s�hoz sz�ks�ges jelek.
   output wire [7:0]  dbg2pmem_addr,   //�r�si c�m
   output wire [15:0] dbg2pmem_data,   //A mem�ri�ba �rand� adat
   output wire        dbg2pmem_wr,     //�r�s enged�lyez� jel
   
   //Debug interf�sz a CPU fel�.
   output wire [22:0] dbg2cpu_data,    //Jelek a debug modult�l a CPU fel�
   input  wire [47:0] cpu2dbg_data     //Jelek a CPU-t�l a debug modul fel�
);

//******************************************************************************
//* A kiadhat� parancsok. A fel nem sorolt �rt�kek v�tele eset�n nincs         *
//* m�veletv�gz�s.                                                             *
//******************************************************************************
localparam CMD_RD_SEL    = 4'd1;       //A beolvasand� adat kiv�laszt�sa
localparam CMD_RESET     = 4'd2;       //A reset vonal �llapot�nak be�ll�t�sa
localparam CMD_BREAK     = 4'd3;       //A break bit �llapot�nak be�ll�t�sa
localparam CMD_BRKPT_EN  = 4'd4;       //T�r�spontok enged�yez�se vagy tilt�sa
localparam CMD_SET_BRKPT = 4'd5;       //T�r�spont be�ll�t�sa vagy t�rl�se
localparam CMD_CONTINUE  = 4'd6;       //Az utas�t�s v�grehajt�s folytat�sa
localparam CMD_WR_PC     = 4'd7;       //A programsz�ml�l� �r�sa
localparam CMD_WR_FLAG   = 4'd8;       //A flag-ek �llapot�nak be�ll�t�sa
localparam CMD_WR_REG    = 4'd9;       //Regiszter �r�sa
localparam CMD_RD_REG    = 4'd10;      //Regiszter olvas�sa
localparam CMD_WR_DMEM   = 4'd11;      //Adatmem�ria �r�sa
localparam CMD_RD_DMEM   = 4'd12;      //Adatmem�ria olvas�sa
localparam CMD_WR_PRGMEM = 4'd13;      //Programmem�ria �r�sa
localparam CMD_CLR_CNT   = 4'd14;      //A sz�ml�l�k t�rl�se


//******************************************************************************
//* Adatok a processzor fel�l.                                                 *
//******************************************************************************
//A programsz�ml�l� �rt�ke.
wire [7:0]  dbg_pc_value  = cpu2dbg_data[7:0];
//A regisztert�mbb�l beolvasott adat.
wire [7:0]  dbg_reg_data  = cpu2dbg_data[15:8];
//Az adatmem�ri�b�l beolvasott adat.
wire [7:0]  dbg_mem_data  = cpu2dbg_data[23:16];
//A verem tetej�nek tartalma.
wire [13:0] dbg_stack_top = cpu2dbg_data[37:24];
//Flag-ek: |  6  |5 |4 |3|2|1|0|
//         |break|IF|IE|V|N|C|Z|
wire [6:0]  dbg_flag_data = cpu2dbg_data[44:38];
//Busz hozz�f�r�s megad�sa.
wire        dbg_bus_grant = cpu2dbg_data[45];
//Az utas�t�s dek�dol�s jelz�se.
wire        dbg_instr_dec = cpu2dbg_data[46];
//A megszak�t�sk�r�s kiszolg�l�s�nak jelz�se.
wire        dbg_int_req   = cpu2dbg_data[47];


//******************************************************************************
//* A boundary scan (JTAG) interf�sz.                                          *
//******************************************************************************
wire jtag_capture;
wire jtag_drck;
wire jtag_sel1;
wire jtag_shift;
wire jtag_tdi;
wire jtag_update;
wire jtag_tdo;

BSCAN_SPARTAN3 bscan_interface(
   .CAPTURE(jtag_capture),             //'CAPTURE DR' �llapot jelz�se
   .DRCK1(jtag_drck),                  //�rajel az adatregiszternek (USER1)
   .DRCK2(),                           //�rajel az adatregiszternek (USER2)
   .RESET(),                           //'TEST LOGIC RESET' �llapot jelz�se
   .SEL1(jtag_sel1),                   //USER1 utas�t�s bet�ltve
   .SEL2(),                            //USER2 utas�t�s bet�ltve
   .SHIFT(jtag_shift),                 //'SHIFT DR' �llapot jelz�se
   .TDI(jtag_tdi),                     //Soros adat az el�z� eszk�zt�l
   .UPDATE(jtag_update),               //'UPDATE DR' �llapot jelz�se
   .TDO1(jtag_tdo),                    //Soros adat a k�v. eszk�znek (USER1)
   .TDO2(1'b0)                         //Soros adat a k�v. eszk�znek (USER2)
);


//******************************************************************************
//* �ldetekt�l�s a boundary scan interf�sz kimenetein.                         *
//******************************************************************************
(* shreg_extract = "no" *)
(* register_balancing = "no" *)
(* register_duplication = "no" *)
(* equivalent_register_removal = "no" *)
reg  [2:0] capture_samples;
wire       capture_rising = (capture_samples[2:1] == 2'b01);

(* shreg_extract = "no" *)
(* register_balancing = "no" *)
(* register_duplication = "no" *)
(* equivalent_register_removal = "no" *)
reg  [2:0] drck_samples;
wire       drck_rising = (drck_samples[2:1] == 2'b01);

(* shreg_extract = "no" *)
(* register_balancing = "no" *)
(* register_duplication = "no" *)
(* equivalent_register_removal = "no" *)
reg  [2:0] update_samples;
wire       update_falling = (update_samples[2:1] == 2'b10);

always @(posedge clk)
begin
   capture_samples <= {capture_samples[1:0], jtag_capture & jtag_sel1};
   drck_samples    <= {drck_samples[1:0], jtag_drck & jtag_shift};
   update_samples  <= {update_samples[1:0], jtag_update & jtag_sel1};
end


//******************************************************************************
//* A shiftregiszter �s a vett adatot t�rol� regiszter.                        *
//******************************************************************************
reg [27:0] jtag_shr;
reg [22:0] jtag_shr_din;
reg [27:0] data_reg;

always @(posedge clk)
begin
   if (capture_rising)
      jtag_shr <= {5'd0, jtag_shr_din};
   else
      if (drck_rising)
         jtag_shr <= {jtag_tdi, jtag_shr[27:1]};
end

always @(posedge clk)
begin
   if (update_falling)
      data_reg <= jtag_shr[27:0];
end

//Soros adat a JTAG l�ncban l�v� k�vetkez� eszk�znek.
assign jtag_tdo = jtag_shr[0];


//******************************************************************************
//* A vez�rl� �llapotg�p.                                                      *
//******************************************************************************
localparam STATE_IDLE         = 4'd0;
localparam STATE_DECODE       = 4'd1;
localparam STATE_EX_RD_SEL    = 4'd2;
localparam STATE_EX_RESET     = 4'd3;
localparam STATE_EX_BREAK     = 4'd4;
localparam STATE_EX_BRKPT_EN  = 4'd5;
localparam STATE_EX_SET_BRKPT = 4'd6;
localparam STATE_EX_CONTINUE  = 4'd7;
localparam STATE_EX_WR_PC     = 4'd8;
localparam STATE_EX_WR_FLAG   = 4'd9;
localparam STATE_EX_WR_REG    = 4'd10;
localparam STATE_EX_RD_REG    = 4'd11;
localparam STATE_EX_WR_DMEM   = 4'd12;
localparam STATE_EX_RD_DMEM   = 4'd13;
localparam STATE_EX_WR_PRGMEM = 4'd14;
localparam STATE_EX_CLR_CNT   = 4'd15;

reg [3:0] state;

always @(posedge clk or posedge rst_in)
begin
   if (rst_in)
      state <= STATE_IDLE;
   else
      case (state)
         //V�rakoz�s a parancsra.
         STATE_IDLE        : if (update_falling)
                                state <= STATE_DECODE;
                             else
                                state <= STATE_IDLE;
                                
         //A vett parancs dek�dol�sa.
         STATE_DECODE      : case (data_reg[27:24])
                                CMD_RD_SEL   : state <= STATE_EX_RD_SEL;
                                CMD_RESET    : state <= STATE_EX_RESET;
                                CMD_BREAK    : state <= STATE_EX_BREAK;
                                CMD_BRKPT_EN : state <= STATE_EX_BRKPT_EN;
                                CMD_SET_BRKPT: state <= STATE_EX_SET_BRKPT;
                                CMD_CONTINUE : state <= STATE_EX_CONTINUE;
                                CMD_WR_PC    : state <= STATE_EX_WR_PC;
                                CMD_WR_FLAG  : state <= STATE_EX_WR_FLAG;
                                CMD_WR_REG   : state <= STATE_EX_WR_REG;
                                CMD_RD_REG   : state <= STATE_EX_RD_REG;
                                CMD_WR_DMEM  : state <= STATE_EX_WR_DMEM;
                                CMD_RD_DMEM  : state <= STATE_EX_RD_DMEM;
                                CMD_WR_PRGMEM: state <= STATE_EX_WR_PRGMEM;
                                CMD_CLR_CNT  : state <= STATE_EX_CLR_CNT;
                                
                                //�rv�nytelen parancs: nincs m�velet.
                                default      : state <= STATE_IDLE;
                             endcase
         
         //A vett parancs v�grehajt�sa.
         STATE_EX_RD_SEL   : state <= STATE_IDLE;
         STATE_EX_RESET    : state <= STATE_IDLE;
         STATE_EX_BREAK    : state <= STATE_IDLE;
         STATE_EX_BRKPT_EN : state <= STATE_IDLE;
         STATE_EX_SET_BRKPT: state <= STATE_IDLE;
         STATE_EX_CONTINUE : state <= STATE_IDLE;
         STATE_EX_WR_PC    : state <= STATE_IDLE;
         STATE_EX_WR_FLAG  : state <= STATE_IDLE;
         STATE_EX_WR_REG   : state <= STATE_IDLE;
         STATE_EX_RD_REG   : state <= STATE_IDLE;
         STATE_EX_WR_DMEM  : state <= (dbg_bus_grant) ? STATE_IDLE : STATE_EX_WR_DMEM;
         STATE_EX_RD_DMEM  : state <= (dbg_bus_grant) ? STATE_IDLE : STATE_EX_RD_DMEM;
         STATE_EX_WR_PRGMEM: state <= STATE_IDLE;
         STATE_EX_CLR_CNT  : state <= STATE_IDLE;
         
         //�rv�nytelen �llapotok.
         default           : state <= STATE_IDLE;
      endcase
end


//******************************************************************************
//* A regisztert�mbb�l beolvasott adat t�rol�sa.                               *
//******************************************************************************
reg [7:0] reg_data;

always @(posedge clk)
begin
   if (state == STATE_EX_RD_REG)
      reg_data <= dbg_reg_data;
end


//******************************************************************************
//* Az adatmem�ri�b�l beolvasott adat t�rol�sa.                                *
//******************************************************************************
reg [7:0] mem_data;

always @(posedge clk)
begin
   if ((state == STATE_EX_RD_DMEM) && dbg_bus_grant)
      mem_data <= dbg_mem_data;
end


//******************************************************************************
//* A v�grehajtott utas�t�sok sz�ml�l�ja.                                      *
//******************************************************************************
reg  [31:0] instr_cnt;
wire        instr_cnt_clr = (state == STATE_EX_CLR_CNT) & data_reg[0];

always @(posedge clk)
begin
   if (rst_out || instr_cnt_clr)
      instr_cnt <= 32'd0;
   else
      if (dbg_instr_dec)
         instr_cnt <= instr_cnt + 32'd1;
end


//******************************************************************************
//* Az elfogadott megszak�t�sk�r�sek sz�ml�l�ja.                               *
//******************************************************************************
reg  [31:0] irq_cnt;
wire        irq_cnt_clr = (state == STATE_EX_CLR_CNT) & data_reg[1];

always @(posedge clk)
begin
   if (rst_out || irq_cnt_clr)
      irq_cnt <= 32'd0;
   else
      if (dbg_int_req)
         irq_cnt <= irq_cnt + 32'd1;
end


//******************************************************************************
//* A beolvashat� adatot kiv�laszt� regiszter.                                 *
//******************************************************************************
reg [2:0] rd_data_sel_reg;

always @(posedge clk)
begin
   if (state == STATE_EX_RD_SEL)
      rd_data_sel_reg <= data_reg[2:0];
end

//A shiftregiszter p�rhuzamos adatbemenete.
always @(*)
begin
   case (rd_data_sel_reg)
      3'b000: jtag_shr_din <= {dbg_flag_data, 8'd0, dbg_pc_value};
      3'b001: jtag_shr_din <= {dbg_flag_data, 8'd0, mem_data};
      3'b010: jtag_shr_din <= {dbg_flag_data, 8'd0, reg_data};
      3'b011: jtag_shr_din <= {dbg_flag_data, 2'd0, dbg_stack_top}; 
      3'b100: jtag_shr_din <= {dbg_flag_data, instr_cnt[15:0]};
      3'b101: jtag_shr_din <= {dbg_flag_data, instr_cnt[31:16]};
      3'b110: jtag_shr_din <= {dbg_flag_data, irq_cnt[15:0]};
      3'b111: jtag_shr_din <= {dbg_flag_data, irq_cnt[31:16]};
   endcase
end


//******************************************************************************
//* Reset regiszter.                                                           *
//******************************************************************************
reg rst_reg;

always @(posedge clk or posedge rst_in)
begin
   if (rst_in)
      rst_reg <= 1'b0;
   else
      if (state == STATE_EX_RESET)
         rst_reg <= data_reg[0];
end

//A kimen� reset vonal meghajt�sa.
assign rst_out = rst_in | rst_reg;


//******************************************************************************
//* Break regiszter. Ha �rt�ke 1, akkor a program fut�sa le�ll a k�vetkez�     *
//* utas�t�sn�l a be�ll�tott t�r�spontokt�l f�ggetlen�l.                       *
//******************************************************************************
reg break_set_en;
reg break_reg;

always @(posedge clk or posedge rst_in)
begin
   if (rst_in)
      break_reg <= 1'b0;
   else
      if (break_set_en && dbg_flag_data[6])
         break_reg <= 1'b1;
      else
         if (state == STATE_EX_BREAK)
            break_reg <= data_reg[0];
end

always @(posedge clk or posedge rst_in)
begin
   if (rst_in)
      break_set_en <= 1'b1;
   else
      if (break_set_en && dbg_flag_data[6])
         break_set_en <= 1'b0;
      else
         if (state == STATE_EX_CONTINUE)
            break_set_en <= 1'b1;
end


//******************************************************************************
//* T�r�spont enged�lyez� regiszter. Ha �rt�ke 1, akkor a program fut�sa le�ll *
//* a be�ll�tott t�r�spontokn�l.                                               *
//******************************************************************************
reg brkpt_en_reg;

always @(posedge clk or posedge rst_in)
begin
   if (rst_in)
      brkpt_en_reg <= 1'b0;
   else
      if (state == STATE_EX_BRKPT_EN)
         brkpt_en_reg <= data_reg[0];
end


//******************************************************************************
//* T�r�spont be�ll�t�sa.                                                      *
//******************************************************************************
(* ram_style = "distributed" *)
reg  brkpt_ram [255:0];
wire brkpt_ram_dout = brkpt_ram[dbg_pc_value];

always @(posedge clk)
begin
   if (state == STATE_EX_SET_BRKPT)
      brkpt_ram[data_reg[23:16]] <= data_reg[0];
end


//******************************************************************************
//* A programmem�ria �r�s�val kapcsolatos jelek meghajt�sa.                    *
//******************************************************************************
assign dbg2pmem_data = data_reg[15:0];
assign dbg2pmem_addr = data_reg[23:16];
assign dbg2pmem_wr   = (state == STATE_EX_WR_PRGMEM);


//******************************************************************************
//* Debug interf�sz jelek a processzor fel�.                                   *
//******************************************************************************
//C�m �s adat.
assign dbg2cpu_data[7:0]  = data_reg[7:0];
assign dbg2cpu_data[15:8] = data_reg[23:16];

//Az utas�t�s v�grehajt�s le�ll�t�s�nak jelz�se.
assign dbg2cpu_data[16] = break_reg | (brkpt_en_reg & brkpt_ram_dout);

//Az utas�t�s v�grehajt�s folytat�s�nak jelz�se.
assign dbg2cpu_data[17] = (state == STATE_EX_CONTINUE);

//A programsz�ml�l� �r�s�nak jelz�se.
assign dbg2cpu_data[18] = (state == STATE_EX_WR_PC);

//A flag-ek �r�s�nak jelz�se.
assign dbg2cpu_data[19] = (state == STATE_EX_WR_FLAG);

//A regisztert�mb �r�s�nak jelz�se.
assign dbg2cpu_data[20] = (state == STATE_EX_WR_REG);

//Az adatmem�ria �r�s�nak jelz�se.
assign dbg2cpu_data[21] = (state == STATE_EX_WR_DMEM);

//Az adatmem�ria olvas�s�nak jelz�se.
assign dbg2cpu_data[22] = (state == STATE_EX_RD_DMEM);

endmodule
