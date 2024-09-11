`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* A processzort vezérlõ állapotgép.                                          *
//******************************************************************************
module controller_fsm(
   //Órajel és reset.
   input  wire       clk,              //Órajel
   input  wire       rst,              //Aszinkron reset
   
   //A lehívott utasítással kapcsolatos jelek.
   input  wire       addr_op2_sel,     //Az ALU 2. operandusának kiválasztása
   input  wire [3:0] opcode,           //Az utasításban lévõ mûveleti kód
   input  wire [3:0] ctrl_op,          //A programvezérlési mûvelet kódja
   
   //A processzor állapotával kapcsolatos jelek.
   output wire       initialize,       //Inicializálás
   output reg        fetch,            //Utasítás lehívás
   output wire       decode,           //Utasítás dekódolás
   output wire       interrupt,        //Megszakítás kiszolgálás
   
   //A programvezérlõ utasítások végrehajtásával kapcsolatos jelek.
   output reg        ex_jump,          //Ugrás végrehajtása
   output wire       ex_call,          //Szubrutinhívás végrehajtása
   output wire       ex_ret_sub,       //Visszatérés szubrutinból
   output wire       ex_ret_int,       //Visszatérés megszakításból
   
   //Az adatstruktúrával kapcsolatos jelek.
   output wire       wr_data_sel,      //A regiszterbe írandó adat kiválasztása
   output reg        reg_wr_en,        //A regisztertömb írás engedélyezõ jele
   output reg  [1:0] alu_op_type,      //ALU mûvelet kiválasztó jel
   input  wire       alu_flag_z,       //Zero flag
   input  wire       alu_flag_c,       //Carry flag
   input  wire       alu_flag_n,       //Negative flag
   input  wire       alu_flag_v,       //Overflow flag
   
   //Az adatmemóriával kapcsolatos jelek.
   output wire       bus_req,          //Busz hozzáférés kérése
   input  wire       bus_grant,        //Busz hozzáférés megadása
   output wire       data_mem_wr,      //Írás engedélyezõ jel
   output wire       data_mem_rd,      //Olvasás engedélyezõ jel
   
   //A megszakítással kapcsolatos jelek.
   input  wire       irq,              //Megszakításkérõ bemenet
   input  wire       flag_ie_din,      //Az IE flag-ba írandó érték
   output reg        flag_ie,          //Megyszakítás engedélyezõ flag (IE)
   input  wire       flag_if_din,      //Az IF flag-ba írandó érték
   output reg        flag_if,          //Megyszakítás flag (IF)
   
   //A debug interfész jelei.
   input  wire       dbg_break,        //Program végrehajtásának felfüggesztése
   input  wire       dbg_continue,     //Program végrehajtásának folytatása
   input  wire       dbg_ie_wr,        //Az IE flag írás engedélyezõ jele
   input  wire       dbg_ie_din,       //Az IE bitbe írandó adat
   input  wire       dbg_reg_wr,       //A regisztertömb írás engedélyezõ jele
   input  wire       dbg_mem_wr,       //Az adatmemória írás engedélyezõ jele
   input  wire       dbg_mem_rd,       //Az adatmemória olvasás engedélyezõ jele
   output wire       dbg_is_brk        //A töréspont állapot jelzése
);

`include "src\MiniRISC_CPU\control_defs.vh"
`include "src\MiniRISC_CPU\opcode_defs.vh"

//******************************************************************************
//* Megyszakítás engedélyezõ flag (IE).                                        *
//******************************************************************************
wire ie_clr;
wire ie_set;

always @(posedge clk)
begin
   if (initialize || interrupt || ie_clr)
      flag_ie <= 1'b0;
   else
      if (ie_set)
         flag_ie <= 1'b1;
      else
         if (ex_ret_int)
            flag_ie <= flag_ie_din;
         else
            if (dbg_is_brk && dbg_ie_wr)
               flag_ie <= dbg_ie_din;
end


//******************************************************************************
//* Megyszakítás flag (IF). A megszakítás kiszolgálását jelzi.                 *
//******************************************************************************
always @(posedge clk)
begin
   if (initialize)
      flag_if <= 1'b0;
   else
      if (interrupt)
         flag_if <= 1'b1;
      else
         if (ex_ret_int)
            flag_if <= flag_if_din;
end


//******************************************************************************
//* A vezérlõ állapotgép.                                                      *
//******************************************************************************
localparam STATE_INIT     = 4'd0;   //Inicializálás
localparam STATE_FETCH    = 4'd1;   //Utasítás lehívás
localparam STATE_DECODE   = 4'd2;   //Utasítás dekódolás
localparam STATE_EX_LD    = 4'd3;   //Utasítás végrehajtás (memória olvasás)
localparam STATE_EX_ST    = 4'd4;   //Utasítás végrehajtás (memória írás)
localparam STATE_EX_MOV   = 4'd5;   //Utasítás végrehajtás (adatmozgatás)
localparam STATE_EX_ARITH = 4'd6;   //Utasítás végrehajtás (aritmetikai)
localparam STATE_EX_LOGIC = 4'd7;   //Utasítás végrehajtás (logikai/csere)
localparam STATE_EX_SHIFT = 4'd8;   //Utasítás végrehajtás (shiftelés/forgatás)
localparam STATE_EX_CTRL  = 4'd9;   //Utasítás végrehajtás (programvezérlés)
localparam STATE_EX_NOP   = 4'd10;  //Utasítás végrehajtás (nincs mûveletvégzés)
localparam STATE_INT_REQ  = 4'd11;  //Megszakításkérés kezelése
localparam STATE_BREAK    = 4'd12;  //Töréspont

//Az aktuális állapotot tároló regiszter.
reg [3:0] state;

always @(posedge clk or posedge rst)
begin
   if (rst)
      state <= STATE_INIT;
   else
      case (state)
         //Inicializálás.
         STATE_INIT    : state <= STATE_FETCH;
         
         //Utasítás lehívás.
         STATE_FETCH   : if (dbg_break)
                            state <= STATE_BREAK;
                         else
                            state <= STATE_DECODE;
         
         //Utasítás dekódolás.
         STATE_DECODE  : case (opcode)
                            //Adatmemória olvasás.
                            OPCODE_LD   : state <= STATE_EX_LD;
                            
                            //Adatmemória írás.
                            OPCODE_ST   : state <= STATE_EX_ST;
                            
                            //Adatmozgatás vagy konstans betöltés.
                            OPCODE_MOV  : state <= STATE_EX_MOV;
                            
                            //Aritmetikai mûveletek.
                            OPCODE_ADD  : state <= STATE_EX_ARITH;
                            OPCODE_ADC  : state <= STATE_EX_ARITH;
                            OPCODE_SUB  : state <= STATE_EX_ARITH;
                            OPCODE_SBC  : state <= STATE_EX_ARITH;
                            OPCODE_CMP  : state <= STATE_EX_ARITH;
                            
                            //Logikai mûveletek.
                            OPCODE_AND  : state <= STATE_EX_LOGIC;
                            OPCODE_OR   : state <= STATE_EX_LOGIC;
                            OPCODE_XOR  : state <= STATE_EX_LOGIC;
                            OPCODE_TST  : state <= STATE_EX_LOGIC;
                            
                            //Shiftelés/forgatás vagy csere.
                            OPCODE_SHIFT: if (addr_op2_sel)
                                             state <= STATE_EX_SHIFT;
                                          else
                                             state <= STATE_EX_LOGIC;
                            
                            //Programvezérlés.
                            OPCODE_CTRL : state <= STATE_EX_CTRL;
                            
                            //Nincs mûveletvégzés.
                            default     : state <= STATE_EX_NOP;
                         endcase
         
         //Utasítás végrehajtás.
         STATE_EX_LD   : if (bus_grant)
                            if (flag_ie && irq)
                               state <= STATE_INT_REQ;
                            else
                               state <= STATE_FETCH;
                         else
                            state <= STATE_EX_LD;
                            
         STATE_EX_ST   : if (bus_grant)
                            if (flag_ie && irq)
                               state <= STATE_INT_REQ;
                            else
                               state <= STATE_FETCH;
                         else
                            state <= STATE_EX_ST;
         
         STATE_EX_MOV  : if (flag_ie && irq)
                            state <= STATE_INT_REQ;
                         else
                            state <= STATE_FETCH;
         
         STATE_EX_ARITH: if (flag_ie && irq)
                            state <= STATE_INT_REQ;
                         else
                            state <= STATE_FETCH;
         
         STATE_EX_LOGIC: if (flag_ie && irq)
                            state <= STATE_INT_REQ;
                         else
                            state <= STATE_FETCH;
         
         STATE_EX_SHIFT: if (flag_ie && irq)
                            state <= STATE_INT_REQ;
                         else
                            state <= STATE_FETCH;
         
         STATE_EX_CTRL : if (flag_ie && irq)
                            state <= STATE_INT_REQ;
                         else
                            state <= STATE_FETCH;
         
         STATE_EX_NOP  : if (flag_ie && irq)
                            state <= STATE_INT_REQ;
                         else
                            state <= STATE_FETCH;
                            
         //Megszakításkérés kezelése.
         STATE_INT_REQ : state <= STATE_FETCH;
         
         //Töréspont.
         STATE_BREAK   : if (dbg_continue)
                            state <= STATE_DECODE;
                         else
                            state <= STATE_BREAK;
                            
         //Érvénytelen állapotok.
         default       : state <= STATE_INIT;
      endcase
end


//******************************************************************************
//* A processzor állapotával kapcsolatos jelek.                                *
//******************************************************************************
//Inicializálás.
assign initialize = (state == STATE_INIT);

//Utasítás lehívás.
always @(*)
begin
   case (state)
      STATE_FETCH: fetch <= ~dbg_break;
      STATE_BREAK: fetch <= dbg_continue;
      default    : fetch <= 1'b0;
   endcase
end

//Utasítás dekódolás.
assign decode     = (state == STATE_DECODE);

//Megszakítás kiszolgálása.
assign interrupt  = (state == STATE_INT_REQ);

//Töréspont.
assign dbg_is_brk = (state == STATE_BREAK);


//******************************************************************************
//* A programvezérlõ utasításokkal kapcsolatos jelek.                          *
//******************************************************************************
//Feltétel nélküli és feltételes ugrás jelzése.
always @(*)
begin
   if (state == STATE_EX_CTRL)
      case (ctrl_op)
         CTRL_JMP: ex_jump <= 1'b1;
         CTRL_JZ : ex_jump <= alu_flag_z;
         CTRL_JNZ: ex_jump <= ~alu_flag_z;
         CTRL_JC : ex_jump <= alu_flag_c;
         CTRL_JNC: ex_jump <= ~alu_flag_c;
         CTRL_JN : ex_jump <= alu_flag_n;
         CTRL_JNN: ex_jump <= ~alu_flag_n;
         CTRL_JV : ex_jump <= alu_flag_v;
         CTRL_JNV: ex_jump <= ~alu_flag_v;
         default : ex_jump <= 1'b0;
      endcase
   else
      ex_jump <= 1'b0;
end

//Szubrutinhívás jelzése.
assign ex_call    = (state == STATE_EX_CTRL) & (ctrl_op == CTRL_JSR);

//Visszatérés szubrutinból.
assign ex_ret_sub = (state == STATE_EX_CTRL) & (ctrl_op == CTRL_RTS);

//Visszatérés megszakításból.
assign ex_ret_int = (state == STATE_EX_CTRL) & (ctrl_op == CTRL_RTI);

//A megszakítás engedélyezõ flag vezérlõ jelei.
assign ie_set     = (state == STATE_EX_CTRL) & (ctrl_op == CTRL_STI);
assign ie_clr     = (state == STATE_EX_CTRL) & (ctrl_op == CTRL_CLI);


//******************************************************************************
//* Az adatstruktúra vezérlõ jelei.                                            *
//******************************************************************************
//A regiszertömbbe írandó adat kiválasztó jele:
//0: ALU mûvelet eredménye
//1: az adatmemóriából olvasott adat
assign wr_data_sel = (state == STATE_EX_LD);

//Regisztertömb írás engedélyezõ jel.
always @(*)
begin
   case (state)
      STATE_EX_LD   : reg_wr_en <= bus_grant;
      STATE_EX_MOV  : reg_wr_en <= 1'b1;
      STATE_EX_ARITH: reg_wr_en <= ~opcode[3];
      STATE_EX_LOGIC: reg_wr_en <= ~opcode[3];
      STATE_EX_SHIFT: reg_wr_en <= 1'b1;
      STATE_BREAK   : reg_wr_en <= dbg_reg_wr;
      default       : reg_wr_en <= 1'b0;
   endcase
end
   
//ALU mûvelet kiválaszó jel.
always @(*)
begin
   case (state)
      STATE_EX_ARITH: alu_op_type <= ALU_ARITH;
      STATE_EX_LOGIC: alu_op_type <= ALU_LOGIC;
      STATE_EX_SHIFT: alu_op_type <= ALU_SHIFT;
      default       : alu_op_type <= ALU_MOVE;
   endcase
end


//******************************************************************************
//* Az adatmemóriával kapcsolatos jelek.                                       *
//******************************************************************************
//Az adatmemória írás engedélyezõ jele.
assign data_mem_wr = (dbg_is_brk) ? dbg_mem_wr : (state == STATE_EX_ST);

//Az adatmemória olvasás engedélyezõ jele.
assign data_mem_rd = (dbg_is_brk) ? dbg_mem_rd : (state == STATE_EX_LD);

//Busz hozzáférés kérése.
assign bus_req     = data_mem_wr | data_mem_rd;

   
endmodule
