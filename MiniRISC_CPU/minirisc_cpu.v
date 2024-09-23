`timescale 1ns / 1ps

//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//******************************************************************************
module minirisc_cpu(
   //�rajel �s reset.
   input  wire        clk,             //�rajel
   input  wire        rst,             //Aszinkron reset
   
   //Busz interf�sz a programmem�ria el�r�s�hez.
   output wire [7:0]  cpu2pmem_addr,   //C�mbusz
   input  wire [15:0] pmem2cpu_data,   //Olvas�si adatbusz
   
   //Master busz interf�sz az adatmem�ria el�r�s�hez.
   output wire        m_bus_req,       //Busz hozz�f�r�s k�r�se
   input  wire        m_bus_grant,     //Busz hozz�f�r�s megad�sa
   output wire [7:0]  m_mst2slv_addr,  //C�mbusz
   output wire        m_mst2slv_wr,    //�r�s enged�lyez� jel
   output wire        m_mst2slv_rd,    //Olvas�s enged�lyez� jel
   output wire [7:0]  m_mst2slv_data,  //�r�si adatbusz
   input  wire [7:0]  m_slv2mst_data,  //Olvas�si adatbusz
   
   //Megszak�t�sk�r� bemenet (akt�v magas szint�rz�keny).
   input  wire        irq,

   output wire [7:0] SP,
   input  wire [7:0] dbg_stack_top,
   
   //Debug interf�sz.
   input  wire [22:0] dbg2cpu_data,    //Jelek a debug modult�l a CPU fel�
   output wire [47:0] cpu2dbg_data     //Jelek a CPU-t�l a debug modul fel�
);

`include "src\MiniRISC_CPU\control_defs.vh"

//******************************************************************************
//* Debug interf�sz jelek.                                                     *
//******************************************************************************
wire [7:0]  dbg_data_in;               //Adat a debug modult�l
wire [7:0]  dbg_addr_in;               //C�m a debug modult�l
wire        dbg_break;                 //Az utas�t�s v�grehajt�s felf�ggeszt�se
wire        dbg_continue;              //Az utas�t�s v�grehajt�s folytat�sa
wire        dbg_pc_wr;                 //A PC �r�s enged�lyez� jele (debug)
wire        dbg_flag_wr;               //A flag-ek �r�s enged�lyez� jele
wire        dbg_reg_wr;                //A regisztert�mb �r�s enged�lyez� jele
wire        dbg_mem_wr;                //Az adatmem�ria �r�s enged�lyez� jele
wire        dbg_mem_rd;                //Az adatmem�ria olvas�s enged�lyez� jele
wire        dbg_instr_dec;             //Az utas�t�s dek�dol�s jelz�se
wire        dbg_int_req;               //A megszak�t�s kiszolg�l�s�nak jelz�se
wire [7:0]  dbg_reg_dout;              //A regisztert�mbb�l beolvasott adat
wire        dbg_flag_ie;               //Megyszak�t�s enged�lyez� flag (IE)
wire        dbg_flag_if;               //Megyszak�t�s flag (IF)
wire        dbg_is_brk;                //A t�r�spont �llapot jelz�se
wire [13:0] dbg_stack_top;             //A verem tetej�n l�v� adat


//******************************************************************************
//* A processzor adatstrukt�r�j�t vez�rl� egys�g.                              *
//******************************************************************************
wire       data_mem_wr;                //Adatmem�ria �r�s enged�lyez� jel
wire       data_mem_rd;                //Adatmem�ria olvas�s enged�lyez� jel
wire [7:0] const_data;                 //Az utas�t�sban l�v� konstans adat
wire       wr_data_sel_cntrl;                //A regiszterbe �rand� adat kiv�laszt�sa
wire       addr_op2_sel;               //Az ALU 2. operandus�nak kiv�laszt�sa
wire       reg_wr_en_cntrl;                  //A regisztert�mb �r�s enged�lyez� jele
wire [3:0] reg_addr_x_cntrl;                 //Regiszter c�me (X port)
wire [3:0] reg_addr_y;                 //Regiszter c�me (Y port)
wire [1:0] alu_op_type;                //ALU m�velet kiv�laszt� jel
wire [1:0] alu_arith_sel;              //Aritmetikai m�velet kiv�laszt� jel
wire [1:0] alu_logic_sel;              //Logikai m�velet kiv�laszt� jel
wire [3:0] alu_shift_sel;              //Shiftel�si m�velet kiv�laszt� jel
wire [3:0] alu_flag_din;               //A flag-ekbe �rand� �rt�k
wire       alu_flag_wr;                //A flag-ek �r�s enged�lyez� jele
wire       alu_flag_z;                 //Zero flag
wire       alu_flag_c;                 //Carry flag
wire       alu_flag_n;                 //Negative flag
wire       alu_flag_v;                 //Overflow flag
wire [7:0] jump_addr;                  //Ugr�si c�m
//wire [7:0] SP;                         //Stack pointer regiszter
wire [7:0] SP_out;
wire [7:0] reg_wr_data;
wire [7:0] PC;
wire [7:0] return_pc;
wire stack_op_ongoing;
wire stack_op_end;
wire push_or_pop;
wire [5:0] stack_dout_flags;

control_unit control_unit(
   //�rajel �s reset.
   .clk(clk),                          //�rajel
   .rst(rst),                          //Aszinkron reset
   
   //A programmem�ri�val kapcsolatos jelek.
   .prg_mem_addr(cpu2pmem_addr),       //C�mbusz
   .prg_mem_din(pmem2cpu_data),        //Olvas�si adatbusz
   
   //Az adatmem�ri�val kapcsolatos jelek.
   .bus_req(m_bus_req),                //Busz hozz�f�r�s k�r�se
   .bus_grant(m_bus_grant),            //Busz hozz�f�r�s megad�sa
   .data_mem_wr(data_mem_wr),          //�r�s enged�lyez� jel
   .data_mem_rd(data_mem_rd),          //Olvas�s enged�lyez� jel
   
   //Az utas�t�sban l�v� konstans adat.
   .const_data(const_data),
   
   //Az adatstrukt�ra multiplexereinek vez�rl� jelei.
   .wr_data_sel(wr_data_sel_cntrl),          //A regiszterbe �rand� adat kiv�laszt�sa
   .addr_op2_sel(addr_op2_sel),        //Az ALU 2. operandus�nak kiv�laszt�sa
   
   //A regisztert�mbbel kapcsolatos jelek.
   .reg_wr_en(reg_wr_en_cntrl),              //�r�s enged�lyez� jel
   .reg_addr_x(reg_addr_x_cntrl),            //Regiszter c�me (X port)
   .reg_addr_y(reg_addr_y),            //Regiszter c�me (Y port)
   
   //Az ALU-val kapcsolatos jelek.
   .alu_op_type(alu_op_type),          //ALU m�velet kiv�laszt� jel
   .alu_arith_sel(alu_arith_sel),      //Aritmetikai m�velet kiv�laszt� jel
   .alu_logic_sel(alu_logic_sel),      //Logikai m�velet kiv�laszt� jel
   .alu_shift_sel(alu_shift_sel),      //Shiftel�si m�velet kiv�laszt� jel
   .alu_flag_wr(alu_flag_wr),          //A flag-ek �r�s enged�lyez� jele
   .alu_flag_z(alu_flag_z),            //Zero flag
   .alu_flag_c(alu_flag_c),            //Carry flag
   .alu_flag_n(alu_flag_n),            //Negative flag
   .alu_flag_v(alu_flag_v),            //Overflow flag
   
   //Ugr�si c�m az adatstrukt�r�t�l.
   .jump_addr(jump_addr),

   .pc(PC),
   .return_addr(return_pc),
   
   //Megszak�t�sk�r� bemenet (akt�v magas szint�rz�keny).
   .irq(irq),

   .flag_ie_din(stack_dout_flags[4]),
   .flag_if_din(stack_dout_flags[5]),

   .stack_op_ongoing(stack_op_ongoing),
   .stack_op_end(stack_op_end),
   .push_or_pop(push_or_pop),

   .SP(SP),
   
   //A debug interf�sz jelei.
   .dbg_data_in(dbg_data_in),          //Adatbemenet
   .dbg_break(dbg_break),              //Program v�grehajt�s�nak felf�ggeszt�se
   .dbg_continue(dbg_continue),        //Program v�grehajt�s�nak folytat�sa
   .dbg_pc_wr(dbg_pc_wr),              //A programsz�ml�l� �r�s enged�lyez� jele
   .dbg_flag_wr(dbg_flag_wr),          //A flag-ek �r�s enged�lyez� jele
   .dbg_reg_wr(dbg_reg_wr),            //A regisztert�mb �r�s enged�lyez� jele
   .dbg_mem_wr(dbg_mem_wr),            //Az adatmem�ria �r�s enged�lyez� jele
   .dbg_mem_rd(dbg_mem_rd),            //Az adatmem�ria olvas�s enged�lyez� jele
   .dbg_instr_dec(dbg_instr_dec),      //Az utas�t�s dek�dol�s jelz�se
   .dbg_int_req(dbg_int_req),          //A megszak�t�s kiszolg�l�s�nak jelz�se
   .dbg_is_brk(dbg_is_brk),            //A t�r�spont �llapot jelz�se
   .dbg_flag_ie(dbg_flag_ie),          //Megyszak�t�s enged�lyez� flag (IE)
   .dbg_flag_if(dbg_flag_if)           //Megyszak�t�s flag (IF)
);


//******************************************************************************
//* A m�veleteket v�grehajt� adatstrukt�ra.                                    *
//******************************************************************************
wire [7:0] data_mem_addr;
wire [7:0] data_mem_dout;

assign reg_wr_en   = (stack_op_ongoing) ? (stack_op_end) : (reg_wr_en_cntrl);
assign reg_addr_x  = (stack_op_ongoing) ? (SP_address)   : (reg_addr_x_cntrl);
assign wr_data_sel = (stack_op_ongoing) ? (1'b1)         : (wr_data_sel_cntrl);
assign reg_wr_data = (stack_op_ongoing) ? (SP_out)       : (m_slv2mst_data);

datapath datapath(
   //�rajel.
   .clk(clk),
   .rst(rst),
   
   //Az adatmem�ri�val kapcsolatos jelek.
   .data_mem_addr(data_mem_addr),      //C�mbusz
   .data_mem_din(reg_wr_data),      //Olvas�si adatbusz
   .data_mem_dout(data_mem_dout),      //�r�si adatbusz
   
   //Az utas�t�sban l�v� konstans adat.
   .const_data(const_data),
   
   //A multiplexerek vez�rl� jelei.
   .wr_data_sel(wr_data_sel),          //A regiszterbe �rand� adat kiv�laszt�sa
   .addr_op2_sel(addr_op2_sel),        //Az ALU 2. operandus�nak kiv�laszt�sa
   
   //A regisztert�mbbel kapcsolatos jelek.
   .reg_addr_x(reg_addr_x),            //Regiszter c�me (X port)
   .reg_addr_y(reg_addr_y),            //Regiszter c�me (Y port)
   .reg_wr_en(reg_wr_en),              //�r�s enged�lyez� jel
   
   //Az ALU-val kapcsolatos jelek.
   .alu_op_type(alu_op_type),          //ALU m�velet kiv�laszt� jel
   .alu_arith_sel(alu_arith_sel),      //Aritmetikai m�velet kiv�laszt� jel
   .alu_logic_sel(alu_logic_sel),      //Logikai m�velet kiv�laszt� jel
   .alu_shift_sel(alu_shift_sel),      //Shiftel�si m�velet kiv�laszt� jel
   .alu_flag_din(alu_flag_din),        //A flag-ekbe �rand� �rt�k
   .alu_flag_wr(alu_flag_wr),          //A flag-ek �r�s enged�lyez� jele
   .alu_flag_z(alu_flag_z),            //Zero flag
   .alu_flag_c(alu_flag_c),            //Carry flag
   .alu_flag_n(alu_flag_n),            //Negative flag
   .alu_flag_v(alu_flag_v),            //Overflow flag
   
   //A programsz�ml�l� �j �rt�ke ugr�s eset�n.
   .jump_address(jump_addr),

   .SP(SP),
   
   //A debug interf�sz jelei.
   .dbg_addr_in(dbg_addr_in),          //C�m bemenet
   .dbg_data_in(dbg_data_in),          //Adatbemenet
   .dbg_is_brk(dbg_is_brk),            //A t�r�spont �llapot jelz�se
   .dbg_reg_dout(dbg_reg_dout)         //A regisztert�mbb�l beolvasott adat
);


//******************************************************************************
//* Verem. Szubrutinh�v�s �s megszak�t�sk�r�s eset�n ide ment�dik el a         *
//* programsz�ml�l�, valamint a flag-ek �rt�ke.                                *
//******************************************************************************
wire [5:0] stack_din_flags;

wire [7:0] stack_mem_addr;
wire [7:0] stack_mem_din;
wire [7:0] stack_mem_dout;

// Ha stack_op_onging == 1 es megjon a bus_grant, akkor kezodik a stack muvelet a push_or_pop-nak megfeleloen.
// Amint vege a muveletnek, az utolso ciklus utan egy orajelig az stack_op_end magas erteku.
stack stack(
   .clk(clk),
   .rst(rst),

   .stack_op_ongoing(stack_op_ongoing),
   .push_or_pop(push_or_pop),
   .stack_op_end(stack_op_end),

   .bus_grant(m_bus_grant),

   .data_mem_addr(stack_mem_addr),    //C�mbusz
   .data_mem_din(stack_mem_din),     //Olvas�si adatbusz
   .data_mem_dout(stack_mem_dout),    //�r�si adatbusz

   .SP(SP),
   .SP_out(SP_out),
   
   .data_in_PC(PC),                //A verembe �rand� adat
   .data_in_flags(stack_din_flags), 

   .data_out_flags(stack_dout_flags),  
   .data_out_PC(return_pc)
);

//A verembe elmentj�k a programsz�ml�l�t �s az ALU flag-eket.
assign stack_din_flags[0]  = alu_flag_z;
assign stack_din_flags[1]  = alu_flag_c;
assign stack_din_flags[2]  = alu_flag_n;
assign stack_din_flags[3]  = alu_flag_v;
assign stack_din_flags[4]  = dbg_flag_ie;
assign stack_din_flags[5]  = dbg_flag_if;

//Az ALU flag-ekkel kapcsolatos jelek. Break �llapotban a debug
//modul �rhatja a flag-eket, egy�bk�nt pedig a verembe elmentett
//�rt�kek �ll�that�k vissza.

assign alu_flag_din   = (dbg_is_brk) ? dbg_data_in[3:0] : stack_dout_flags[3:0];


//******************************************************************************
//* Az adatmem�ria interf�sz kimeneteinek meghajt�sa. Ha a processzor nem kap  *
//* busz hozz�f�r�st, akkor ezek �rt�ke inakt�v nulla kell, hogy legyen.       *
//******************************************************************************
assign m_mst2slv_addr = (m_bus_grant) ? ((stack_op_ongoing) ? stack_mem_addr : data_mem_addr) : 8'd0;
assign m_mst2slv_wr   = (m_bus_grant) ? data_mem_wr                                           : 1'b0;
assign m_mst2slv_rd   = (m_bus_grant) ? data_mem_rd                                           : 1'b0;
assign m_mst2slv_data = (m_bus_grant) ? ((stack_op_ongoing) ? stack_mem_dout : data_mem_dout) : 8'd0;


//******************************************************************************
//* A debug interf�sz jeleinek meghajt�sa.                                     *
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
assign cpu2dbg_data[23:16] = reg_wr_data;
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
