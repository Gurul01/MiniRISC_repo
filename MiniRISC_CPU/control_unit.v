`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* A processzor adatstruktúráját vezérlõ egység.                              *
//******************************************************************************
module control_unit(
   //Órajel és reset.
   input  wire        clk,             //Órajel
   input  wire        rst,             //Aszinkron reset
   
   //A programmemóriával kapcsolatos jelek.
   output wire [7:0]  prg_mem_addr,    //Címbusz
   input  wire [15:0] prg_mem_din,     //Olvasási adatbusz
   
   //Az adatmemóriával kapcsolatos jelek.
   output wire        bus_req,         //Busz hozzáférés kérése
   input  wire        bus_grant,       //Busz hozzáférés megadása
   output wire        data_mem_wr,     //Írás engedélyezõ jel
   output wire        data_mem_rd,     //Olvasás engedélyezõ jel
   
   //Az utasításban lévõ konstans adat.
   output wire [7:0]  const_data,
   
   //Az adatstruktúra multiplexereinek vezérlõ jelei.
   output wire        wr_data_sel,     //A regiszterbe írandó adat kiválasztása
   output wire        addr_op2_sel,    //Az ALU 2. operandusának kiválasztása
   
   //A regisztertömbbel kapcsolatos jelek.
   output wire        reg_wr_en,       //Írás engedélyezõ jel
   output wire [3:0]  reg_addr_x,      //Regiszter címe (X port)
   output wire [3:0]  reg_addr_y,      //Regiszter címe (Y port)
   
   //Az ALU-val kapcsolatos jelek.
   output wire [1:0]  alu_op_type,     //ALU mûvelet kiválasztó jel
   output wire [1:0]  alu_arith_sel,   //Aritmetikai mûvelet kiválasztó jel
   output wire [1:0]  alu_logic_sel,   //Logikai mûvelet kiválasztó jel
   output wire [3:0]  alu_shift_sel,   //Shiftelési mûvelet kiválasztó jel
   output wire [3:0]  alu_flag_din,    //A flag-ekbe írandó érték
   output wire        alu_flag_wr,     //A flag-ek írás engedélyezõ jele
   input  wire        alu_flag_z,      //Zero flag
   input  wire        alu_flag_c,      //Carry flag
   input  wire        alu_flag_n,      //Negative flag
   input  wire        alu_flag_v,      //Overflow flag
   
   //Ugrási cím az adatstruktúrától.
   input  wire [7:0]  jump_addr,
   
   //Megszakításkérõ bemenet (aktív magas szintérzékeny).
   input  wire        irq,
   
   //A debug interfész jelei.
   input  wire [7:0]  dbg_data_in,     //Adatbemenet
   input  wire        dbg_break,       //Program végrehajtásának felfüggesztése
   input  wire        dbg_continue,    //Program végrehajtásának folytatása
   input  wire        dbg_pc_wr,       //A programszámláló írás engedélyezõ jele
   input  wire        dbg_flag_wr,     //A flag-ek írás engedélyezõ jele
   input  wire        dbg_reg_wr,      //A regisztertömb írás engedélyezõ jele
   input  wire        dbg_mem_wr,      //Az adatmemória írás engedélyezõ jele
   input  wire        dbg_mem_rd,      //Az adatmemória olvasás engedélyezõ jele
   output wire        dbg_instr_dec,   //Az utasítás dekódolás jelzése
   output wire        dbg_int_req,     //A megszakítás kiszolgálásának jelzése
   output wire        dbg_is_brk,      //A töréspont állapot jelzése
   output wire        dbg_flag_ie,     //Megyszakítás engedélyezõ flag (IE)
   output wire        dbg_flag_if,     //Megyszakítás flag (IF)
   output wire [13:0] dbg_stack_top    //A verem tetején lévõ adat
);

`include "src\MiniRISC_CPU\control_defs.vh"
`include "src\MiniRISC_CPU\opcode_defs.vh"

//******************************************************************************
//* Vezérlõ jelek.                                                             *
//******************************************************************************
wire initialize;                       //Inicializálás
wire fetch;                            //Utasítás lehívás
wire ex_jump;                          //Ugrás végrehajtása
wire ex_call;                          //Szubrutinhívás végrehajtása
wire ex_ret_sub;                       //Visszatérés szubrutinból
wire ex_ret_int;                       //Visszatérés megszakításból


//******************************************************************************
//* Programszámláló (PC). A lehívandó utasítás címét tárolja.                  *
//******************************************************************************
reg  [7:0] pc;                         //Programszámláló regiszter
wire [7:0] return_addr;                //Visszatérési cím

always @(posedge clk)
begin
   if (initialize)
      pc <= RST_VECTOR;                //A reset vektor betöltése
   else
      if (dbg_int_req)
         pc <= INT_VECTOR;             //A megszakítás vektor betöltése
      else
         if (dbg_is_brk && dbg_pc_wr)
            pc <= dbg_data_in;         //A debug modul írja a programszámlálót
         else
            if (ex_jump || ex_call)
               pc <= jump_addr;        //Az ugrási cím betöltése
            else
               if (ex_ret_sub || ex_ret_int)
                  pc <= return_addr;   //A visszatérési cím betöltése
               else
                  if (fetch)
                     pc <= pc + 8'd1;  //A programszámláló növelése
end

//A programmemória címbuszának meghajtása.
assign prg_mem_addr = pc;


//******************************************************************************
//* Verem. Szubrutinhívás és megszakításkérés esetén ide mentõdik el a         *
//* programszámláló, valamint a flag-ek értéke.                                *
//******************************************************************************
wire [13:0] stack_din;                 //A verembe írandó adat
wire [13:0] stack_dout;                //A verem tetején lévõ adat

stack #(
   //Az adat szélessége bitekben.
   .DATA_WIDTH(14)
) stack (
   //Órajel.
   .clk(clk),
   
   //Adatvonalak.
   .data_in(stack_din),                //A verembe írandó adat
   .data_out(stack_dout),              //A verem tetején lévõ adat
   
   //Vezérlõ bemenetek.
   .push(dbg_int_req | ex_call),       //Adat írása a verembe
   .pop(ex_ret_sub | ex_ret_int)       //Adat olvasása a verembõl
);

//A verembe elmentjük a programszámlálót és az ALU flag-eket.
assign stack_din[7:0] = pc;
assign stack_din[8]   = alu_flag_z;
assign stack_din[9]   = alu_flag_c;
assign stack_din[10]  = alu_flag_n;
assign stack_din[11]  = alu_flag_v;
assign stack_din[12]  = dbg_flag_ie;
assign stack_din[13]  = dbg_flag_if;

//A visszatérési cím.
assign return_addr    = stack_dout[7:0];

//Az ALU flag-ekkel kapcsolatos jelek. Break állapotban a debug
//modul írhatja a flag-eket, egyébként pedig a verembe elmentett
//értékek állíthatók vissza.
assign alu_flag_wr    = (dbg_is_brk) ? dbg_flag_wr      : ex_ret_int;
assign alu_flag_din   = (dbg_is_brk) ? dbg_data_in[3:0] : stack_dout[11:8];

//A verem tetején lévõ adat.
assign dbg_stack_top  = stack_dout;


//******************************************************************************
//* Utasításregiszter. A programmemóriából lehívott utasítást tárolja.         *
//* Az utasítások formátumát lásd az 'opcode_defs.vh' fájlban.                 *
//******************************************************************************
reg [15:0] ir;

always @(posedge clk)
begin
   if (fetch)
      ir <= prg_mem_din;
end

//Az ALU második operandusának kiválaszó jele:
//0: konstans  / abszolút címzés
//1: regiszter / indirekt címzés
assign addr_op2_sel  = (ir[15:12] == REG_OP_PREFIX);

//Az utasításban tárolt mûveleti kód.
wire [3:0] opcode    = (addr_op2_sel) ? ir[7:4] : ir[15:12];

//A regiszterek címei.
assign reg_addr_x    = ir[11:8];
assign reg_addr_y    = ir[3:0];

//Az utasításban lévõ konstans adat.
assign const_data    = ir[7:0];

//Az ALU mûveletek kiválasztó jelei.
assign alu_arith_sel = opcode[1:0];
assign alu_logic_sel = opcode[1:0];
assign alu_shift_sel = ir[3:0];

//A programvezérlési mûvelet kódja.
wire [3:0] ctrl_op   = ir[11:8];


//******************************************************************************
//* A processzort vezérlõ állapotgép.                                          *
//******************************************************************************
controller_fsm controller_fsm(
   //Órajel és reset.
   .clk(clk),                          //Órajel
   .rst(rst),                          //Aszinkron reset
   
   //A lehívott utasítással kapcsolatos jelek.
   .addr_op2_sel(addr_op2_sel),        //Az ALU 2. operandusának kiválasztása
   .opcode(opcode),                    //Az utasításban lévõ mûveleti kód
   .ctrl_op(ctrl_op),                  //A programvezérlési mûvelet kódja
   
   //A processzor állapotával kapcsolatos jelek.
   .initialize(initialize),            //Inicializálás
   .fetch(fetch),                      //Utasítás lehívás
   .decode(dbg_instr_dec),             //Utasítás dekódolás
   .interrupt(dbg_int_req),            //Megszakítás kiszolgálás
   
   //A programvezérlõ utasítások végrehajtásával kapcsolatos jelek.
   .ex_jump(ex_jump),                  //Ugrás végrehajtása
   .ex_call(ex_call),                  //Szubrutinhívás végrehajtása
   .ex_ret_sub(ex_ret_sub),            //Visszatérés szubrutinból
   .ex_ret_int(ex_ret_int),            //Visszatérés megszakításból
   
   //Az adatstruktúrával kapcsolatos jelek.
   .wr_data_sel(wr_data_sel),          //A regiszterbe írandó adat kiválasztása
   .reg_wr_en(reg_wr_en),              //A regisztertömb írás engedélyezõ jele
   .alu_op_type(alu_op_type),          //ALU mûvelet kiválasztó jel
   .alu_flag_z(alu_flag_z),            //Zero flag
   .alu_flag_c(alu_flag_c),            //Carry flag
   .alu_flag_n(alu_flag_n),            //Negative flag
   .alu_flag_v(alu_flag_v),            //Overflow flag
   
   //Az adatmemóriával kapcsolatos jelek.
   .bus_req(bus_req),                  //Busz hozzáférés kérése
   .bus_grant(bus_grant),              //Busz hozzáférés megadása
   .data_mem_wr(data_mem_wr),          //Írás engedélyezõ jel
   .data_mem_rd(data_mem_rd),          //Olvasás engedélyezõ jel
   
   //A megszakítással kapcsolatos jelek.
   .irq(irq),                          //Megszakításkérõ bemenet
   .flag_ie_din(stack_dout[12]),       //Az IE flag-ba írandó érték
   .flag_ie(dbg_flag_ie),              //Megyszakítás engedélyezõ flag (IE)
   .flag_if_din(stack_dout[13]),       //Az IE flag-ba írandó érték
   .flag_if(dbg_flag_if),              //Megyszakítás flag (IF)
   
   //A debug interfész jelei.
   .dbg_break(dbg_break),              //Program végrehajtásának felfüggesztése
   .dbg_continue(dbg_continue),        //Program végrehajtásának folytatása
   .dbg_ie_wr(dbg_flag_wr),            //Az IE flag írás engedélyezõ jele
   .dbg_ie_din(dbg_data_in[4]),        //Az IE bitbe írandó adat
   .dbg_reg_wr(dbg_reg_wr),            //A regisztertömb írás engedélyezõ jele
   .dbg_mem_wr(dbg_mem_wr),            //Az adatmemória írás engedélyezõ jele
   .dbg_mem_rd(dbg_mem_rd),            //Az adatmemória olvasás engedélyezõ jele
   .dbg_is_brk(dbg_is_brk)             //A töréspont állapot jelzése
);


endmodule
