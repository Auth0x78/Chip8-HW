`timescale 1ns / 1ps
`include "control_unit_params.vh"

module control_unit (
    // Clock and rst
    input wire clk,
    input wire rst,

    // Data coming from memory
    input wire [15:0] in_data,

    // Address output to memory
    output wire [15:0] mem_addr,
    output wire [ 7:0] out_mem_data
);

  // Control Unit Internal Registers
  reg [15:0] pc;
  reg [ 7:0] sp;
  reg [15:0] instr_reg;  // Instruction Cache Register

  
endmodule
