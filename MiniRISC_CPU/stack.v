`timescale 1ns / 1ps

module stack(
  input  wire clk,
  input  wire rst,

  input  wire stack_op_ongoing,
  input  wire push_or_pop,
  output wire stack_op_end,

  input  wire bus_grant,

  output reg  [7:0] data_mem_addr,
  inout  wire [7:0] data_mem_din,
  output reg  [7:0] data_mem_dout,

  input  wire [7:0] SP,
  output reg  [7:0] SP_out,
    
  input  wire [7:0] data_in_PC,
  input  wire [5:0] data_in_flags, 

  output reg  [5:0] data_out_flags,
  output reg  [7:0] data_out_PC
);

`include "control_defs.vh"

localparam state_NOP       = 4'd0;
localparam state_PUSH_flag = 4'd1;
localparam state_PUSH_PC   = 4'd2;
localparam state_POP_PC    = 4'd3;
localparam state_POP_flags = 4'd4;
localparam state_END_OF_OP = 4'd5;

assign stack_op_end = (state == state_END_OF_OP);

//A stack-et vezerlo allapotgep
reg [2:0] state = state_NOP;

always @(*)
begin
   if(state == state_PUSH_flag)
   begin
      data_mem_addr <= SP - 8'd1;
      data_mem_dout <= {2'b0, data_in_flags};
   end
   else if(state == state_PUSH_PC)
   begin
      data_mem_addr <= SP - 8'd2;
      data_mem_dout <= data_in_PC;
   end

   else if(state == state_POP_PC)
      data_mem_addr <= SP;
   else if(state == state_POP_flags)
      data_mem_addr <= SP + 8'd1;
end

always @(posedge clk)
begin
  if (rst)
      state <= state_NOP;
   else
      case (state)
        state_NOP    : if(stack_op_ongoing)
                       begin
                          if(push_or_pop == PUSH)
                          begin
                              SP_out <= SP - 8'd2;
                              state <= state_PUSH_flag;
                          end
                          else begin
                              SP_out <= SP + 8'd2;
                              state <= state_POP_PC;
                          end
                       end
                       else
                          state <= state_NOP;

        state_PUSH_flag: if(bus_grant)
                          state <= state_PUSH_PC;
                       else
                          state <= state_PUSH_flag;

        state_PUSH_PC  : if(bus_grant)
                          state <= state_END_OF_OP;
                       else
                          state <= state_PUSH_PC;

        state_POP_PC : if(bus_grant)
                       begin
                          data_out_PC <= data_mem_din;
                          state <= state_POP_flags;
                       end
                       else
                          state <= state_POP_PC;

        state_POP_flags: if(bus_grant)
                         begin
                          data_out_flags <= data_mem_din;
                          state <= state_END_OF_OP;
                         end
                         else
                          state <= state_POP_flags;

        state_END_OF_OP: state <= state_NOP;
          
        //�rv�nytelen �llapotok.
        default       : state <= state_NOP;
      endcase
end

endmodule