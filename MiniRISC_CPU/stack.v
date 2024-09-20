`timescale 1ns / 1ps

module stack(
  input  wire clk,
  input  wire rst,

  input  wire stack_op_ongoing,
  input  wire push_or_pop,
  output wire stack_op_end,

  input  wire bus_grant,

  output wire data_mem_addr,
  inout  wire data_mem_din,
  output wire data_mem_dout,

  input  wire [7:0] SP,
  output reg  [7:0] SP_out,
    
  input  wire [7:0] data_in_PC,
  input  wire [5:0] data_in_flags, 

  output wire [5:0] data_out_flags,
  output wire [7:0] data_out_PC,
);

`include "src\MiniRISC_CPU\control_defs.vh"
`include "src\MiniRISC_CPU\opcode_defs.vh"

localparam state_NOP       = 4'd0;
localparam state_FIRST     = 4'd1;
localparam state_SECOND    = 4'd2;
localparam state_THIRD     = 4'd3;
localparam state_END_OF_OP = 4'd4;

//A stack "in_progress" beallitasa a folyamat kezdetekor es kikapcsolasa a folyamat vegevel
always @(posedge clk)
begin
   if (rst)
      in_progress <= 1'b0;
   else
      if(stack_op_start == 1'b1)
         in_progress <= 1'b1;
      else if((state == state_NOP) && (in_progress == 1'b1))
         in_progress <= 1'b0;
end

assign stack_op_end = ((state == state_NOP) && (in_progress == 1'b1));

//A stack-et vezerlo allapotgep
reg [7:0] state = state_NOP;

always @(posedge clk)
begin
  if (rst)
      state <= state_NOP;
   else
      case (state)
        state_NOP    : if(stack_op_start)
                          state <= state_FIRST;
                       else
                          state <= state_NOP;

        state_FIRST  : if(fetch)
                          state <= state_SECOND;
                       else
                          state <= state_FIRST;

        state_SECOND : if(fetch)
                          state <= state_THIRD;
                       else
                          state <= state_SECOND;

        state_THIRD  : if(fetch)
                          state <= state_END_OF_OP;
                       else
                          state <= state_THIRD;

        state_END_OF_OP: state <= state_NOP;
          
        //�rv�nytelen �llapotok.
        default       : state <= state_NOP;
      endcase
end

//Elvegzendo utasitasok az egyes allapotokban
always @(*)
begin
   case (state)
      state_FIRST : if(push_or_pop == PUSH)
                      sub_ir[7:0] <= SP;
                    else if(push_or_pop == POP)
                      sub_ir <= 16'b0;

      state_SECOND: if(push_or_pop == PUSH)
                      sub_ir <= 16'b0;
                    else if(push_or_pop == POP)
                      sub_ir <= 16'b0;

      state_THIRD : if(push_or_pop == PUSH)
                      sub_ir <= 16'b0;
                    else if(push_or_pop == POP)
                      sub_ir <= 16'b0;
      
      default     : sub_ir <= 16'b0;
   endcase
end

endmodule