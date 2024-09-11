`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//******************************************************************************
module minirisc_cpu(
   //Órajel és reset.
   input  wire        clk,             //Órajel
   input  wire        rst,             //Aszinkron reset
   
   //Busz interfész a programmemória eléréséhez.
   output wire [7:0]  cpu2pmem_addr,   //Címbusz
   input  wire [15:0] pmem2cpu_data,   //Olvasási adatbusz
   
   //Master busz interfész az adatmemória eléréséhez.
   output wire        m_bus_req,       //Busz hozzáférés kérése
   input  wire        m_bus_grant,     //Busz hozzáférés megadása
   output wire [7:0]  m_mst2slv_addr,  //Címbusz
   output wire        m_mst2slv_wr,    //Írás engedélyezõ jel
   output wire        m_mst2slv_rd,    //Olvasás engedélyezõ jel
   output wire [7:0]  m_mst2slv_data,  //Írási adatbusz
   input  wire [7:0]  m_slv2mst_data,  //Olvasási adatbusz
   
   //Megszakításkérõ bemenet (aktív magas szintérzékeny).
   input  wire        irq,
   
   //Debug interfész.
   input  wire [22:0] dbg2cpu_data,    //Jelek a debug modultól a CPU felé
   output wire [47:0] cpu2dbg_data     //Jelek a CPU-tól a debug modul felé
);

//******************************************************************************
//* Debug interfész jelek.                                                     *
//******************************************************************************
wire [7:0]  dbg_data_in;               //Adat a debug modultól
wire [7:0]  dbg_addr_in;               //Cím a debug modultól
wire        dbg_break;                 //Az utasítás végrehajtás felfüggesztése
wire        dbg_continue;              //Az utasítás végrehajtás folytatása
wire        dbg_pc_wr;                 //A PC írás engedélyezõ jele (debug)
wire        dbg_flag_wr;               //A flag-ek írás engedélyezõ jele
wire        dbg_reg_wr;                //A regisztertömb írás engedélyezõ jele
wire        dbg_mem_wr;                //Az adatmemória írás engedélyezõ jele
wire        dbg_mem_rd;                //Az adatmemória olvasás engedélyezõ jele
wire        dbg_instr_dec;             //Az utasítás dekódolás jelzése
wire        dbg_int_req;               //A megszakítás kiszolgálásának jelzése
wire [7:0]  dbg_reg_dout;              //A regisztertömbbõl beolvasott adat
wire        dbg_flag_ie;               //Megyszakítás engedélyezõ flag (IE)
wire        dbg_flag_if;               //Megyszakítás flag (IF)
wire        dbg_is_brk;                //A töréspont állapot jelzése
wire [13:0] dbg_stack_top;             //A verem tetején lévõ adat


//******************************************************************************
//* A processzor adatstruktúráját vezérlõ egység.                              *
//******************************************************************************
wire       data_mem_wr;                //Adatmemória írás engedélyezõ jel
wire       data_mem_rd;                //Adatmemória olvasás engedélyezõ jel
wire [7:0] const_data;                 //Az utasításban lévõ konstans adat
wire       wr_data_sel;                //A regiszterbe írandó adat kiválasztása
wire       addr_op2_sel;               //Az ALU 2. operandusának kiválasztása
wire       reg_wr_en;                  //A regisztertömb írás engedélyezõ jele
wire [3:0] reg_addr_x;                 //Regiszter címe (X port)
wire [3:0] reg_addr_y;                 //Regiszter címe (Y port)
wire [1:0] alu_op_type;                //ALU mûvelet kiválasztó jel
wire [1:0] alu_arith_sel;              //Aritmetikai mûvelet kiválasztó jel
wire [1:0] alu_logic_sel;              //Logikai mûvelet kiválasztó jel
wire [3:0] alu_shift_sel;              //Shiftelési mûvelet kiválasztó jel
wire [3:0] alu_flag_din;               //A flag-ekbe írandó érték
wire       alu_flag_wr;                //A flag-ek írás engedélyezõ jele
wire       alu_flag_z;                 //Zero flag
wire       alu_flag_c;                 //Carry flag
wire       alu_flag_n;                 //Negative flag
wire       alu_flag_v;                 //Overflow flag
wire [7:0] jump_addr;                  //Ugrási cím

control_unit control_unit(
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Aszinkron reset
   
   //A programmemóriával kapcsolatos jelek.
   .prg_mem_addr(cpu2pmem_addr),       //Címbusz
   .prg_mem_din(pmem2cpu_data),        //Olvasási adatbusz
   
   //Az adatmemóriával kapcsolatos jelek.
   .bus_req(m_bus_req),                //Busz hozzáférés kérése
   .bus_grant(m_bus_grant),            //Busz hozzáférés megadása
   .data_mem_wr(data_mem_wr),          //Írás engedélyezõ jel
   .data_mem_rd(data_mem_rd),          //Olvasás engedélyezõ jel
   
   //Az utasításban lévõ konstans adat.
   .const_data(const_data),
   
   //Az adatstruktúra multiplexereinek vezérlõ jelei.
   .wr_data_sel(wr_data_sel),          //A regiszterbe írandó adat kiválasztása
   .addr_op2_sel(addr_op2_sel),        //Az ALU 2. operandusának kiválasztása
   
   //A regisztertömbbel kapcsolatos jelek.
   .reg_wr_en(reg_wr_en),              //Írás engedélyezõ jel
   .reg_addr_x(reg_addr_x),            //Regiszter címe (X port)
   .reg_addr_y(reg_addr_y),            //Regiszter címe (Y port)
   
   //Az ALU-val kapcsolatos jelek.
   .alu_op_type(alu_op_type),          //ALU mûvelet kiválasztó jel
   .alu_arith_sel(alu_arith_sel),      //Aritmetikai mûvelet kiválasztó jel
   .alu_logic_sel(alu_logic_sel),      //Logikai mûvelet kiválasztó jel
   .alu_shift_sel(alu_shift_sel),      //Shiftelési mûvelet kiválasztó jel
   .alu_flag_din(alu_flag_din),        //A flag-ekbe írandó érték
   .alu_flag_wr(alu_flag_wr),          //A flag-ek írás engedélyezõ jele
   .alu_flag_z(alu_flag_z),            //Zero flag
   .alu_flag_c(alu_flag_c),            //Carry flag
   .alu_flag_n(alu_flag_n),            //Negative flag
   .alu_flag_v(alu_flag_v),            //Overflow flag
   
   //Ugrási cím az adatstruktúrától.
   .jump_addr(jump_addr),
   
   //Megszakításkérõ bemenet (aktív magas szintérzékeny).
   .irq(irq),
   
   //A debug interfész jelei.
   .dbg_data_in(dbg_data_in),          //Adatbemenet
   .dbg_break(dbg_break),              //Program végrehajtásának felfüggesztése
   .dbg_continue(dbg_continue),        //Program végrehajtásának folytatása
   .dbg_pc_wr(dbg_pc_wr),              //A programszámláló írás engedélyezõ jele
   .dbg_flag_wr(dbg_flag_wr),          //A flag-ek írás engedélyezõ jele
   .dbg_reg_wr(dbg_reg_wr),            //A regisztertömb írás engedélyezõ jele
   .dbg_mem_wr(dbg_mem_wr),            //Az adatmemória írás engedélyezõ jele
   .dbg_mem_rd(dbg_mem_rd),            //Az adatmemória olvasás engedélyezõ jele
   .dbg_instr_dec(dbg_instr_dec),      //Az utasítás dekódolás jelzése
   .dbg_int_req(dbg_int_req),          //A megszakítás kiszolgálásának jelzése
   .dbg_is_brk(dbg_is_brk),            //A töréspont állapot jelzése
   .dbg_flag_ie(dbg_flag_ie),          //Megyszakítás engedélyezõ flag (IE)
   .dbg_flag_if(dbg_flag_if),          //Megyszakítás flag (IF)
   .dbg_stack_top(dbg_stack_top)       //A verem tetején lévõ adat
);


//******************************************************************************
//* A mûveleteket végrehajtó adatstruktúra.                                    *
//******************************************************************************
wire [7:0] data_mem_addr;
wire [7:0] data_mem_dout;

datapath datapath(
   //Órajel.
   .clk(clk),
   
   //Az adatmemóriával kapcsolatos jelek.
   .data_mem_addr(data_mem_addr),      //Címbusz
   .data_mem_din(m_slv2mst_data),      //Olvasási adatbusz
   .data_mem_dout(data_mem_dout),      //Írási adatbusz
   
   //Az utasításban lévõ konstans adat.
   .const_data(const_data),
   
   //A multiplexerek vezérlõ jelei.
   .wr_data_sel(wr_data_sel),          //A regiszterbe írandó adat kiválasztása
   .addr_op2_sel(addr_op2_sel),        //Az ALU 2. operandusának kiválasztása
   
   //A regisztertömbbel kapcsolatos jelek.
   .reg_addr_x(reg_addr_x),            //Regiszter címe (X port)
   .reg_addr_y(reg_addr_y),            //Regiszter címe (Y port)
   .reg_wr_en(reg_wr_en),              //Írás engedélyezõ jel
   
   //Az ALU-val kapcsolatos jelek.
   .alu_op_type(alu_op_type),          //ALU mûvelet kiválasztó jel
   .alu_arith_sel(alu_arith_sel),      //Aritmetikai mûvelet kiválasztó jel
   .alu_logic_sel(alu_logic_sel),      //Logikai mûvelet kiválasztó jel
   .alu_shift_sel(alu_shift_sel),      //Shiftelési mûvelet kiválasztó jel
   .alu_flag_din(alu_flag_din),        //A flag-ekbe írandó érték
   .alu_flag_wr(alu_flag_wr),          //A flag-ek írás engedélyezõ jele
   .alu_flag_z(alu_flag_z),            //Zero flag
   .alu_flag_c(alu_flag_c),            //Carry flag
   .alu_flag_n(alu_flag_n),            //Negative flag
   .alu_flag_v(alu_flag_v),            //Overflow flag
   
   //A programszámláló új értéke ugrás esetén.
   .jump_address(jump_addr),
   
   //A debug interfész jelei.
   .dbg_addr_in(dbg_addr_in),          //Cím bemenet
   .dbg_data_in(dbg_data_in),          //Adatbemenet
   .dbg_is_brk(dbg_is_brk),            //A töréspont állapot jelzése
   .dbg_reg_dout(dbg_reg_dout)         //A regisztertömbbõl beolvasott adat
);


//******************************************************************************
//* Az adatmemória interfész kimeneteinek meghajtása. Ha a processzor nem kap  *
//* busz hozzáférést, akkor ezek értéke inaktív nulla kell, hogy legyen.       *
//******************************************************************************
assign m_mst2slv_addr = (m_bus_grant) ? data_mem_addr : 8'd0;
assign m_mst2slv_wr   = (m_bus_grant) ? data_mem_wr   : 1'b0;
assign m_mst2slv_rd   = (m_bus_grant) ? data_mem_rd   : 1'b0;
assign m_mst2slv_data = (m_bus_grant) ? data_mem_dout : 8'd0;


//******************************************************************************
//* A debug interfész jeleinek meghajtása.                                     *
//******************************************************************************
assign dbg_data_in         = dbg2cpu_data[7:0];
assign dbg_addr_in         = dbg2cpu_data[15:8];
assign dbg_break           = dbg2cpu_data[16];
assign dbg_continue        = dbg2cpu_data[17];
assign dbg_pc_wr           = dbg2cpu_data[18];
assign dbg_flag_wr         = dbg2cpu_data[19];
assign dbg_reg_wr          = dbg2cpu_data[20];
assign dbg_mem_wr          = dbg2cpu_data[21];
assign dbg_mem_rd          = dbg2cpu_data[22];

assign cpu2dbg_data[7:0]   = cpu2pmem_addr;
assign cpu2dbg_data[15:8]  = dbg_reg_dout;
assign cpu2dbg_data[23:16] = m_slv2mst_data;
assign cpu2dbg_data[37:24] = dbg_stack_top;
assign cpu2dbg_data[38]    = alu_flag_z;
assign cpu2dbg_data[39]    = alu_flag_c;
assign cpu2dbg_data[40]    = alu_flag_n;
assign cpu2dbg_data[41]    = alu_flag_v;
assign cpu2dbg_data[42]    = dbg_flag_ie;
assign cpu2dbg_data[43]    = dbg_flag_if;
assign cpu2dbg_data[44]    = dbg_is_brk;
assign cpu2dbg_data[45]    = m_bus_grant;
assign cpu2dbg_data[46]    = dbg_instr_dec;
assign cpu2dbg_data[47]    = dbg_int_req;

endmodule
