//******************************************************************************
//* MiniRISC CPU                                                               *
//*                                                                            *
//* Program counter (PC).                                                      *
//******************************************************************************
module program_counter(
   //Clock and reset.
   input  wire       clk,           //Clock signal
   input  wire       pc_clr,        //Reset signal
   
   //Control signals.
   input  wire       pc_jmp,        //Load signal (jump, subrutine call/return)
   input  wire       pc_rts,        //Return address select (return from subrutine)
   input  wire       pc_jsr,        //Save the return address (subrutine call)
   input  wire       pc_inc,        //Enable signal
   
   //Jump address.
   input  wire [7:0] jmp_addr,
   
   //Value of the program counter.
   output reg  [7:0] pc,            //Current value of the program counter
   output reg  [7:0] next_pc        //Next value of the program counter
);

//******************************************************************************
//* Program counter.                                                           *
//******************************************************************************
reg [7:0] return_addr;

always @(posedge clk)
begin
   if (pc_clr)
      pc <= 8'd0;                      //Reset
   else
      if (pc_jmp)
         if (pc_rts)
            pc <= return_addr;         //Load the return address
         else
            pc <= jmp_addr;            //Load the jump address
      else
         if (pc_inc)
            pc <= pc + 8'd1;           //Increment the program counter
end

//Value of the program counter in the next fetch state.
always @(*)
begin
   if (pc_jmp)
      if (pc_rts)
         next_pc <= return_addr;       //Return address
      else
         next_pc <= jmp_addr;          //Jump address
   else
      next_pc <= pc;                   //The PC has been incremented in the
end                                    //previous fetch state


//******************************************************************************
//* Register for storing the return address. The value of the program counter  *
//* is saved into this register when a JSR instruction is executed.            *
//******************************************************************************
always @(posedge clk)
begin
   if (pc_jsr)
      return_addr <= pc;
end


endmodule
