`timescale 1ns / 1ps
`include "control_unit_params.vh"

module control_unit(
    // Clock and rst
    input wire clk,
    input wire rst,

    // Data coming from memory
    input wire [15:0] in_data,

    // Address output to memory
    output wire [15:0] mem_addr,
    output wire [7:0] out_mem_data
);

// Control Unit Internal Registers
reg [15:0] pc;
reg [7:0] sp; 
reg [15:0] instr_reg; // Instruction Cache Register
reg [1:0] state = CU_STATE_FETCH; // Current state of CPU

// Combinational Logic for next addr
wire [15:0] next_pc;

// Assign mem_addr as PC or custom memory address
assign mem_addr = pc;

// Initial value of state should be FETCH
initial begin
    state = CU_STATE_FETCH;
end

always_comb begin
    next_pc = pc + 2;
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= CU_STATE_FETCH;
        pc <= 16'h0200;
    end else begin
        
        instr_reg <= in_data;
    end
end
    
endmodule