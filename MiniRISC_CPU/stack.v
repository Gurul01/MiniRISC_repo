`timescale 1ns / 1ps

module stack(
  input  wire clk,
  input  wire rst,

  input  wire stack_op_ongoing, //Jelzes a CPU FSM-tol, hogy egy JSR/RTS van folyamatban
  input  wire push_or_pop,      //Jelzes a CPU FSM-tol, hogy JSR es RTS kozul melyiket hajtjuk vegre
  output wire stack_op_end,

  input  wire bus_grant,

  output reg  [7:0] data_mem_addr,
  input  wire [7:0] data_mem_din,
  output reg  [7:0] data_mem_dout,

  input  wire [7:0] SP_in,        //SP regiszter a stack muvelet elott
  output reg  [7:0] SP_out,    //SP regiszter a stack muvelet utan
    
  input  wire [7:0] PC_in,
  output reg  [7:0] PC_out,

  input  wire [5:0] Flags_in, 
  output reg  [5:0] Flags_out
  
);

`include "control_defs.vh"

// Allapotok
localparam state_NOP_after_PUSH = 4'd0;
localparam state_NOP_after_POP  = 4'd1;

localparam state_PUSH_flag   = 4'd2;
localparam state_PUSH_PC     = 4'd3;

localparam state_POP_PC      = 4'd4;
localparam state_POP_flags   = 4'd5;

wire push_op_started;
wire push_op_ended;

wire pop_op_started;
wire pop_op_ended;

//[push/pop]_op_[started/ended] jelek a stack allapotgep kimeo jelei szamara
assign push_op_started = (state == state_NOP_after_PUSH || state == state_NOP_after_POP) && stack_op_ongoing && (push_or_pop == PUSH);
assign push_op_ended = (state == state_NOP_after_PUSH) && !stack_op_ongoing;

assign pop_op_started = (state == state_NOP_after_PUSH || state == state_NOP_after_POP) && stack_op_ongoing && (push_or_pop == POP);
assign pop_op_ended = (state == state_NOP_after_POP) && !stack_op_ongoing;

//A JSR/RTS stack muvelet veget reprezentalo jel a CPU szamara
assign stack_op_end = ((state == state_POP_flags) || (state == state_PUSH_PC));

//Stack allapotvaltozo
reg [2:0] state = state_NOP_after_PUSH;

//A stack kimenetei az adott allapotokban
always @(*)
begin
   if(state == state_PUSH_flag || push_op_started)
   begin
      data_mem_addr <= SP_in - 8'd1;
      data_mem_dout <= {2'b0, Flags_in};
   end
   else if(state == state_PUSH_PC || push_op_ended)
   begin
      data_mem_addr <= SP_in - 8'd2;
      data_mem_dout <= PC_in;
   end //==============================

   else if(state == state_POP_PC || pop_op_started)
   begin
      data_mem_addr <= SP_in;
      data_mem_dout <= 8'b00000000;
   end
   else if(state == state_POP_flags || pop_op_ended)
   begin
      data_mem_addr <= SP_in + 8'd1;
      data_mem_dout <= 8'b00000000;
   end //==============================

   else begin
      data_mem_addr <= 8'b00000000;
      data_mem_dout <= 8'b00000000;
   end
end

//Stack allapotgep
always @(posedge clk)
begin
  if (rst)
      state <= state_NOP_after_PUSH;
   else
      case (state)
        state_NOP_after_PUSH, state_NOP_after_POP : if(stack_op_ongoing)
                       begin
                          if(push_or_pop == PUSH)
                          begin
                              SP_out <= SP_in - 8'd2;
                              state <= state_PUSH_flag;
                          end
                          else begin
                              SP_out <= SP_in + 8'd2;
                              state <= state_POP_PC;
                          end
                       end
                       else
                          state <= state_NOP_after_POP;

        state_PUSH_flag: if(bus_grant)
                          state <= state_PUSH_PC;
                       else
                          state <= state_PUSH_flag;

        state_PUSH_PC  : if(bus_grant)
                          state <= state_NOP_after_PUSH;
                       else
                          state <= state_PUSH_PC;


        state_POP_PC : if(bus_grant)
                       begin
                          PC_out <= data_mem_din;
                          state <= state_POP_flags;
                       end
                       else
                          state <= state_POP_PC;

        state_POP_flags: if(bus_grant)
                         begin
                          Flags_out <= data_mem_din[5:0];
                          state <= state_NOP_after_POP;
                         end
                         else
                          state <= state_POP_flags;

          
        //�rv�nytelen �llapotok.
        default       : state <= state_NOP_after_PUSH;
      endcase
end

endmodule