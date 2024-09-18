`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* A processzor adatstrukt�r�j�t vez�rl� egys�g.                              *
//******************************************************************************
module control_unit(
   //�rajel �s reset.
   input  wire        clk,             //�rajel
   input  wire        rst,             //Aszinkron reset
   
   //A programmem�ri�val kapcsolatos jelek.
   output wire [7:0]  prg_mem_addr,    //C�mbusz
   input  wire [15:0] prg_mem_din,     //Olvas�si adatbusz
   
   //Az adatmem�ri�val kapcsolatos jelek.
   output wire        bus_req,         //Busz hozz�f�r�s k�r�se
   input  wire        bus_grant,       //Busz hozz�f�r�s megad�sa
   output wire        data_mem_wr,     //�r�s enged�lyez� jel
   output wire        data_mem_rd,     //Olvas�s enged�lyez� jel
   
   //Az utas�t�sban l�v� konstans adat.
   output wire [7:0]  const_data,
   
   //Az adatstrukt�ra multiplexereinek vez�rl� jelei.
   output wire        wr_data_sel,     //A regiszterbe �rand� adat kiv�laszt�sa
   output wire        addr_op2_sel,    //Az ALU 2. operandus�nak kiv�laszt�sa
   
   //A regisztert�mbbel kapcsolatos jelek.
   output wire        reg_wr_en,       //�r�s enged�lyez� jel
   output wire [3:0]  reg_addr_x,      //Regiszter c�me (X port)
   output wire [3:0]  reg_addr_y,      //Regiszter c�me (Y port)
   
   //Az ALU-val kapcsolatos jelek.
   output wire [1:0]  alu_op_type,     //ALU m�velet kiv�laszt� jel
   output wire [1:0]  alu_arith_sel,   //Aritmetikai m�velet kiv�laszt� jel
   output wire [1:0]  alu_logic_sel,   //Logikai m�velet kiv�laszt� jel
   output wire [3:0]  alu_shift_sel,   //Shiftel�si m�velet kiv�laszt� jel
   output wire [3:0]  alu_flag_din,    //A flag-ekbe �rand� �rt�k
   output wire        alu_flag_wr,     //A flag-ek �r�s enged�lyez� jele
   input  wire        alu_flag_z,      //Zero flag
   input  wire        alu_flag_c,      //Carry flag
   input  wire        alu_flag_n,      //Negative flag
   input  wire        alu_flag_v,      //Overflow flag
   
   //Ugr�si c�m az adatstrukt�r�t�l.
   input  wire [7:0]  jump_addr,

   input  wire [7:0]  SP;
   
   //Megszak�t�sk�r� bemenet (akt�v magas szint�rz�keny).
   input  wire        irq,
   
   //A debug interf�sz jelei.
   input  wire [7:0]  dbg_data_in,     //Adatbemenet
   input  wire        dbg_break,       //Program v�grehajt�s�nak felf�ggeszt�se
   input  wire        dbg_continue,    //Program v�grehajt�s�nak folytat�sa
   input  wire        dbg_pc_wr,       //A programsz�ml�l� �r�s enged�lyez� jele
   input  wire        dbg_flag_wr,     //A flag-ek �r�s enged�lyez� jele
   input  wire        dbg_reg_wr,      //A regisztert�mb �r�s enged�lyez� jele
   input  wire        dbg_mem_wr,      //Az adatmem�ria �r�s enged�lyez� jele
   input  wire        dbg_mem_rd,      //Az adatmem�ria olvas�s enged�lyez� jele
   output wire        dbg_instr_dec,   //Az utas�t�s dek�dol�s jelz�se
   output wire        dbg_int_req,     //A megszak�t�s kiszolg�l�s�nak jelz�se
   output wire        dbg_is_brk,      //A t�r�spont �llapot jelz�se
   output wire        dbg_flag_ie,     //Megyszak�t�s enged�lyez� flag (IE)
   output wire        dbg_flag_if,     //Megyszak�t�s flag (IF)
   output wire [13:0] dbg_stack_top    //A verem tetej�n l�v� adat
);

`include "src\MiniRISC_CPU\control_defs.vh"
`include "src\MiniRISC_CPU\opcode_defs.vh"

//******************************************************************************
//* Vez�rl� jelek.                                                             *
//******************************************************************************
wire initialize;                       //Inicializ�l�s
wire fetch;                            //Utas�t�s leh�v�s
wire ex_jump;                          //Ugr�s v�grehajt�sa
wire ex_call;                          //Szubrutinh�v�s v�grehajt�sa
wire ex_ret_sub;                       //Visszat�r�s szubrutinb�l
wire ex_ret_int;                       //Visszat�r�s megszak�t�sb�l


//******************************************************************************
//* Programsz�ml�l� (PC). A leh�vand� utas�t�s c�m�t t�rolja.                  *
//******************************************************************************
reg  [7:0] pc;                         //Programsz�ml�l� regiszter
wire [7:0] return_addr;                //Visszat�r�si c�m

always @(posedge clk)
begin
   if (initialize)
      pc <= RST_VECTOR;                //A reset vektor bet�lt�se
   else
      if (dbg_int_req)
         pc <= INT_VECTOR;             //A megszak�t�s vektor bet�lt�se
      else
         if (dbg_is_brk && dbg_pc_wr)
            pc <= dbg_data_in;         //A debug modul �rja a programsz�ml�l�t
         else
            if (ex_jump || ex_call)
               pc <= jump_addr;        //Az ugr�si c�m bet�lt�se
            else
               if (ex_ret_sub || ex_ret_int)
                  pc <= return_addr;   //A visszat�r�si c�m bet�lt�se
               else
                  if (fetch)
                     pc <= pc + 8'd1;  //A programsz�ml�l� n�vel�se
end

//A programmem�ria c�mbusz�nak meghajt�sa.
assign prg_mem_addr = pc;


//******************************************************************************
//* Verem. Szubrutinh�v�s �s megszak�t�sk�r�s eset�n ide ment�dik el a         *
//* programsz�ml�l�, valamint a flag-ek �rt�ke.                                *
//******************************************************************************
wire [13:0] stack_din;                 //A verembe �rand� adat
wire [13:0] stack_dout;                //A verem tetej�n l�v� adat

stack #(
   //Az adat sz�less�ge bitekben.
   .DATA_WIDTH(14)
) stack (
   //�rajel.
   .clk(clk),
   
   //Adatvonalak.
   .data_in(stack_din),                //A verembe �rand� adat
   .data_out(stack_dout),              //A verem tetej�n l�v� adat
   
   //Vez�rl� bemenetek.
   .push(dbg_int_req | ex_call),       //Adat �r�sa a verembe
   .pop(ex_ret_sub | ex_ret_int)       //Adat olvas�sa a veremb�l
);

//A verembe elmentj�k a programsz�ml�l�t �s az ALU flag-eket.
assign stack_din[7:0] = pc;
assign stack_din[8]   = alu_flag_z;
assign stack_din[9]   = alu_flag_c;
assign stack_din[10]  = alu_flag_n;
assign stack_din[11]  = alu_flag_v;
assign stack_din[12]  = dbg_flag_ie;
assign stack_din[13]  = dbg_flag_if;

//A visszat�r�si c�m.
assign return_addr    = stack_dout[7:0];

//Az ALU flag-ekkel kapcsolatos jelek. Break �llapotban a debug
//modul �rhatja a flag-eket, egy�bk�nt pedig a verembe elmentett
//�rt�kek �ll�that�k vissza.
assign alu_flag_wr    = (dbg_is_brk) ? dbg_flag_wr      : ex_ret_int;
assign alu_flag_din   = (dbg_is_brk) ? dbg_data_in[3:0] : stack_dout[11:8];

//A verem tetej�n l�v� adat.
assign dbg_stack_top  = stack_dout;


//******************************************************************************
//* Utas�t�sregiszter. A programmem�ri�b�l leh�vott utas�t�st t�rolja.         *
//* Az utas�t�sok form�tum�t l�sd az 'opcode_defs.vh' f�jlban.                 *
//******************************************************************************
reg [15:0] ir;

always @(posedge clk)
begin
   if (fetch)
      ir <= prg_mem_din;
end

//Az ALU m�sodik operandus�nak kiv�lasz� jele:
//0: konstans  / abszol�t c�mz�s
//1: regiszter / indirekt c�mz�s
assign addr_op2_sel  = (ir[15:12] == REG_OP_PREFIX);

//Az utas�t�sban t�rolt m�veleti k�d.
wire [3:0] opcode    = (addr_op2_sel) ? ir[7:4] : ir[15:12];

//A regiszterek c�mei.
assign reg_addr_x    = ir[11:8];
assign reg_addr_y    = ir[3:0];

//Az utas�t�sban l�v� konstans adat.
//Ha adatmemoriat irunk vagy olvasunk akkor SP relativen cimzunk.
//0: data_mem_wr || data_mem_rd -> Az utolso 8 bit a konstans adat
//1: data_mem_wr || data_mem_rd -> SP relativ cimzes
assign const_data    = (data_mem_wr || data_mem_rd) ? (ir[7:0] + SP) : (ir[7:0]);

//Az ALU m�veletek kiv�laszt� jelei.
assign alu_arith_sel = opcode[1:0];
assign alu_logic_sel = opcode[1:0];
assign alu_shift_sel = ir[3:0];

//A programvez�rl�si m�velet k�dja.
wire [3:0] ctrl_op   = ir[11:8];


//******************************************************************************
//* A processzort vez�rl� �llapotg�p.                                          *
//******************************************************************************
controller_fsm controller_fsm(
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Aszinkron reset
   
   //A leh�vott utas�t�ssal kapcsolatos jelek.
   .addr_op2_sel(addr_op2_sel),        //Az ALU 2. operandus�nak kiv�laszt�sa
   .opcode(opcode),                    //Az utas�t�sban l�v� m�veleti k�d
   .ctrl_op(ctrl_op),                  //A programvez�rl�si m�velet k�dja
   
   //A processzor �llapot�val kapcsolatos jelek.
   .initialize(initialize),            //Inicializ�l�s
   .fetch(fetch),                      //Utas�t�s leh�v�s
   .decode(dbg_instr_dec),             //Utas�t�s dek�dol�s
   .interrupt(dbg_int_req),            //Megszak�t�s kiszolg�l�s
   
   //A programvez�rl� utas�t�sok v�grehajt�s�val kapcsolatos jelek.
   .ex_jump(ex_jump),                  //Ugr�s v�grehajt�sa
   .ex_call(ex_call),                  //Szubrutinh�v�s v�grehajt�sa
   .ex_ret_sub(ex_ret_sub),            //Visszat�r�s szubrutinb�l
   .ex_ret_int(ex_ret_int),            //Visszat�r�s megszak�t�sb�l
   
   //Az adatstrukt�r�val kapcsolatos jelek.
   .wr_data_sel(wr_data_sel),          //A regiszterbe �rand� adat kiv�laszt�sa
   .reg_wr_en(reg_wr_en),              //A regisztert�mb �r�s enged�lyez� jele
   .alu_op_type(alu_op_type),          //ALU m�velet kiv�laszt� jel
   .alu_flag_z(alu_flag_z),            //Zero flag
   .alu_flag_c(alu_flag_c),            //Carry flag
   .alu_flag_n(alu_flag_n),            //Negative flag
   .alu_flag_v(alu_flag_v),            //Overflow flag
   
   //Az adatmem�ri�val kapcsolatos jelek.
   .bus_req(bus_req),                  //Busz hozz�f�r�s k�r�se
   .bus_grant(bus_grant),              //Busz hozz�f�r�s megad�sa
   .data_mem_wr(data_mem_wr),          //�r�s enged�lyez� jel
   .data_mem_rd(data_mem_rd),          //Olvas�s enged�lyez� jel
   
   //A megszak�t�ssal kapcsolatos jelek.
   .irq(irq),                          //Megszak�t�sk�r� bemenet
   .flag_ie_din(stack_dout[12]),       //Az IE flag-ba �rand� �rt�k
   .flag_ie(dbg_flag_ie),              //Megyszak�t�s enged�lyez� flag (IE)
   .flag_if_din(stack_dout[13]),       //Az IE flag-ba �rand� �rt�k
   .flag_if(dbg_flag_if),              //Megyszak�t�s flag (IF)
   
   //A debug interf�sz jelei.
   .dbg_break(dbg_break),              //Program v�grehajt�s�nak felf�ggeszt�se
   .dbg_continue(dbg_continue),        //Program v�grehajt�s�nak folytat�sa
   .dbg_ie_wr(dbg_flag_wr),            //Az IE flag �r�s enged�lyez� jele
   .dbg_ie_din(dbg_data_in[4]),        //Az IE bitbe �rand� adat
   .dbg_reg_wr(dbg_reg_wr),            //A regisztert�mb �r�s enged�lyez� jele
   .dbg_mem_wr(dbg_mem_wr),            //Az adatmem�ria �r�s enged�lyez� jele
   .dbg_mem_rd(dbg_mem_rd),            //Az adatmem�ria olvas�s enged�lyez� jele
   .dbg_is_brk(dbg_is_brk)             //A t�r�spont �llapot jelz�se
);


endmodule
