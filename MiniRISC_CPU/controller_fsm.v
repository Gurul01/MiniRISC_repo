`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* A processzort vez�rl� �llapotg�p.                                          *
//******************************************************************************
module controller_fsm(
   //�rajel �s reset.
   input  wire       clk,              //�rajel
   input  wire       rst,              //Aszinkron reset
   
   //A leh�vott utas�t�ssal kapcsolatos jelek.
   input  wire       addr_op2_sel,     //Az ALU 2. operandus�nak kiv�laszt�sa
   input  wire [3:0] opcode,           //Az utas�t�sban l�v� m�veleti k�d
   input  wire [3:0] ctrl_op,          //A programvez�rl�si m�velet k�dja
   
   //A processzor �llapot�val kapcsolatos jelek.
   output wire       initialize,       //Inicializ�l�s
   output reg        fetch,            //Utas�t�s leh�v�s
   output wire       decode,           //Utas�t�s dek�dol�s
   output wire       interrupt,        //Megszak�t�s kiszolg�l�s
   
   //A programvez�rl� utas�t�sok v�grehajt�s�val kapcsolatos jelek.
   output reg        ex_jump,          //Ugr�s v�grehajt�sa
   output wire       ex_call,          //Szubrutinh�v�s v�grehajt�sa
   output wire       ex_ret_sub,       //Visszat�r�s szubrutinb�l
   output wire       ex_ret_int,       //Visszat�r�s megszak�t�sb�l

   output wire       stack_op_ongoing,
   input  wire       stack_op_end,
   output wire       push_or_pop,
   
   //Az adatstrukt�r�val kapcsolatos jelek.
   output wire       wr_data_sel,      //A regiszterbe �rand� adat kiv�laszt�sa
   output reg        reg_wr_en,        //A regisztert�mb �r�s enged�lyez� jele
   output reg  [1:0] alu_op_type,      //ALU m�velet kiv�laszt� jel
   input  wire       alu_flag_z,       //Zero flag
   input  wire       alu_flag_c,       //Carry flag
   input  wire       alu_flag_n,       //Negative flag
   input  wire       alu_flag_v,       //Overflow flag
   
   //Az adatmem�ri�val kapcsolatos jelek.
   output wire       bus_req,          //Busz hozz�f�r�s k�r�se
   input  wire       bus_grant,        //Busz hozz�f�r�s megad�sa
   output wire       data_mem_wr,      //�r�s enged�lyez� jel
   output wire       data_mem_rd,      //Olvas�s enged�lyez� jel
   
   //A megszak�t�ssal kapcsolatos jelek.
   input  wire       irq,              //Megszak�t�sk�r� bemenet
   input  wire       flag_ie_din,      //Az IE flag-ba �rand� �rt�k
   output reg        flag_ie,          //Megyszak�t�s enged�lyez� flag (IE)
   input  wire       flag_if_din,      //Az IF flag-ba �rand� �rt�k
   output reg        flag_if,          //Megyszak�t�s flag (IF)
   
   //A debug interf�sz jelei.
   input  wire       dbg_break,        //Program v�grehajt�s�nak felf�ggeszt�se
   input  wire       dbg_continue,     //Program v�grehajt�s�nak folytat�sa
   input  wire       dbg_ie_wr,        //Az IE flag �r�s enged�lyez� jele
   input  wire       dbg_ie_din,       //Az IE bitbe �rand� adat
   input  wire       dbg_reg_wr,       //A regisztert�mb �r�s enged�lyez� jele
   input  wire       dbg_mem_wr,       //Az adatmem�ria �r�s enged�lyez� jele
   input  wire       dbg_mem_rd,       //Az adatmem�ria olvas�s enged�lyez� jele
   output wire       dbg_is_brk        //A t�r�spont �llapot jelz�se
);

`include "src\MiniRISC_CPU\control_defs.vh"
`include "src\MiniRISC_CPU\opcode_defs.vh"

//******************************************************************************
//* Megyszak�t�s enged�lyez� flag (IE).                                        *
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
//* Megyszak�t�s flag (IF). A megszak�t�s kiszolg�l�s�t jelzi.                 *
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
//* A vez�rl� �llapotg�p.                                                      *
//******************************************************************************
localparam STATE_INIT     = 4'd0;   //Inicializ�l�s
localparam STATE_FETCH    = 4'd1;   //Utas�t�s leh�v�s
localparam STATE_DECODE   = 4'd2;   //Utas�t�s dek�dol�s
localparam STATE_EX_LD    = 4'd3;   //Utas�t�s v�grehajt�s (mem�ria olvas�s)
localparam STATE_EX_ST    = 4'd4;   //Utas�t�s v�grehajt�s (mem�ria �r�s)
localparam STATE_EX_MOV   = 4'd5;   //Utas�t�s v�grehajt�s (adatmozgat�s)
localparam STATE_EX_ARITH = 4'd6;   //Utas�t�s v�grehajt�s (aritmetikai)
localparam STATE_EX_LOGIC = 4'd7;   //Utas�t�s v�grehajt�s (logikai/csere)
localparam STATE_EX_SHIFT = 4'd8;   //Utas�t�s v�grehajt�s (shiftel�s/forgat�s)
localparam STATE_EX_CTRL  = 4'd9;   //Utas�t�s v�grehajt�s (programvez�rl�s)
localparam STATE_EX_NOP   = 4'd10;  //Utas�t�s v�grehajt�s (nincs m�veletv�gz�s)
localparam STATE_INT_REQ  = 4'd11;  //Megszak�t�sk�r�s kezel�se
localparam STATE_BREAK    = 4'd12;  //T�r�spont
localparam STATE_STACK_OP = 4'd14;

//Az aktu�lis �llapotot t�rol� regiszter.
reg [3:0] state;

always @(posedge clk or posedge rst)
begin
   if (rst)
      state <= STATE_INIT;
   else
      case (state)
         //Inicializ�l�s.
         STATE_INIT    : state <= STATE_FETCH;
         
         //Utas�t�s leh�v�s.
         STATE_FETCH   : if (dbg_break)
                            state <= STATE_BREAK;
                         else
                            state <= STATE_DECODE;
         
         //Utas�t�s dek�dol�s.
         STATE_DECODE  : case (opcode)
                            //Adatmem�ria olvas�s.
                            OPCODE_LD   : state <= STATE_EX_LD;
                            
                            //Adatmem�ria �r�s.
                            OPCODE_ST   : state <= STATE_EX_ST;
                            
                            //Adatmozgat�s vagy konstans bet�lt�s.
                            OPCODE_MOV  : state <= STATE_EX_MOV;
                            
                            //Aritmetikai m�veletek.
                            OPCODE_ADD  : state <= STATE_EX_ARITH;
                            OPCODE_ADC  : state <= STATE_EX_ARITH;
                            OPCODE_SUB  : state <= STATE_EX_ARITH;
                            OPCODE_SBC  : state <= STATE_EX_ARITH;
                            OPCODE_CMP  : state <= STATE_EX_ARITH;
                            
                            //Logikai m�veletek.
                            OPCODE_AND  : state <= STATE_EX_LOGIC;
                            OPCODE_OR   : state <= STATE_EX_LOGIC;
                            OPCODE_XOR  : state <= STATE_EX_LOGIC;
                            OPCODE_TST  : state <= STATE_EX_LOGIC;
                            
                            //Shiftel�s/forgat�s vagy csere.
                            OPCODE_SHIFT: if (addr_op2_sel)
                                             state <= STATE_EX_SHIFT;
                                          else
                                             state <= STATE_EX_LOGIC;
                            
                            //Programvez�rl�s.
                            OPCODE_CTRL : if((ctrl_op == CTRL_JSR) || (ctrl_op == CTRL_RTS) || (ctrl_op == CTRL_RTI))
                                             state         <= STATE_STACK_OP;
                                          else
                                             state         <= STATE_EX_CTRL;
                            
                            //Nincs m�veletv�gz�s.
                            default     : state <= STATE_EX_NOP;
                         endcase
         
         //Utas�t�s v�grehajt�s.
         STATE_EX_LD   : if (bus_grant)
                            if (flag_ie && irq)
                               state <= STATE_STACK_OP;
                            else
                               state <= STATE_FETCH;
                         else
                            state <= STATE_EX_LD;
                            
         STATE_EX_ST   : if (bus_grant)
                            if (flag_ie && irq)
                               state <= STATE_STACK_OP;
                            else
                               state <= STATE_FETCH;
                         else
                            state <= STATE_EX_ST;
         
         STATE_EX_MOV  : if (flag_ie && irq)
                            state <= STATE_STACK_OP;
                         else
                            state <= STATE_FETCH;
         
         STATE_EX_ARITH: if (flag_ie && irq)
                            state <= STATE_STACK_OP;
                         else
                            state <= STATE_FETCH;
         
         STATE_EX_LOGIC: if (flag_ie && irq)
                            state <= STATE_STACK_OP;
                         else
                            state <= STATE_FETCH;
         
         STATE_EX_SHIFT: if (flag_ie && irq)
                            state <= STATE_STACK_OP;
                         else
                            state <= STATE_FETCH;
         
         STATE_EX_CTRL : if (flag_ie && irq)
                            state <= STATE_STACK_OP;
                        else
                            state <= STATE_FETCH;
         
         STATE_EX_NOP  : if (flag_ie && irq)
                            state <= STATE_STACK_OP;
                         else
                            state <= STATE_FETCH;
                            
         //Megszak�t�sk�r�s kezel�se.
         STATE_INT_REQ : state <= STATE_FETCH;


         STATE_STACK_OP: if(stack_op_end)
                           if(flag_ie && irq)
                              state <= STATE_INT_REQ;
                            else
                              state <= STATE_EX_CTRL;
                         else
                              state <= STATE_STACK_OP;
                            
         
         //T�r�spont.
         STATE_BREAK   : if (dbg_continue)
                            state <= STATE_DECODE;
                         else
                            state <= STATE_BREAK;
                            
         //�rv�nytelen �llapotok.
         default       : state <= STATE_INIT;
      endcase
end


//******************************************************************************
//* A processzor �llapot�val kapcsolatos jelek.                                *
//******************************************************************************
//Inicializ�l�s.
assign initialize = (state == STATE_INIT);

//Utas�t�s leh�v�s.
always @(*)
begin
   case (state)
      STATE_FETCH: fetch <= ~dbg_break;
      STATE_BREAK: fetch <= dbg_continue;
      default    : fetch <= 1'b0;
   endcase
end

//Utas�t�s dek�dol�s.
assign decode     = (state == STATE_DECODE);

//Megszak�t�s kiszolg�l�sa.
assign interrupt  = (state == STATE_INT_REQ);

//T�r�spont.
assign dbg_is_brk = (state == STATE_BREAK);


//******************************************************************************
//* A programvez�rl� utas�t�sokkal kapcsolatos jelek.                          *
//******************************************************************************
//Felt�tel n�lk�li �s felt�teles ugr�s jelz�se.
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

assign stack_op_ongoing = (state == STATE_STACK_OP);

assign push_or_pop = ((flag_ie && irq) || (ctrl_op == CTRL_JSR)) ? (PUSH) : (POP);

//Szubrutinh�v�s jelz�se.
assign ex_call    = (state == STATE_EX_CTRL) & (ctrl_op == CTRL_JSR);

//Visszat�r�s szubrutinb�l.
assign ex_ret_sub = (state == STATE_EX_CTRL) & (ctrl_op == CTRL_RTS);

//Visszat�r�s megszak�t�sb�l.
assign ex_ret_int = (state == STATE_EX_CTRL) & (ctrl_op == CTRL_RTI);

//A megszak�t�s enged�lyez� flag vez�rl� jelei.
assign ie_set     = (state == STATE_EX_CTRL) & (ctrl_op == CTRL_STI);
assign ie_clr     = (state == STATE_EX_CTRL) & (ctrl_op == CTRL_CLI);


//******************************************************************************
//* Az adatstrukt�ra vez�rl� jelei.                                            *
//******************************************************************************
//A regiszert�mbbe �rand� adat kiv�laszt� jele:
//0: ALU m�velet eredm�nye
//1: az adatmem�ri�b�l olvasott adat
assign wr_data_sel = (state == STATE_EX_LD);

//Regisztert�mb �r�s enged�lyez� jel.
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
   
//ALU m�velet kiv�lasz� jel.
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
//* Az adatmem�ri�val kapcsolatos jelek.                                       *
//******************************************************************************
//Az adatmem�ria �r�s enged�lyez� jele.
assign data_mem_wr = (dbg_is_brk) ? dbg_mem_wr : ((state == STATE_EX_ST) || (stack_op_ongoing && (push_or_pop == PUSH)));

//Az adatmem�ria olvas�s enged�lyez� jele.
assign data_mem_rd = (dbg_is_brk) ? dbg_mem_rd : ((state == STATE_EX_LD) || (stack_op_ongoing && (push_or_pop == POP)));

//Busz hozz�f�r�s k�r�se.
assign bus_req     = data_mem_wr | data_mem_rd;

   
endmodule
