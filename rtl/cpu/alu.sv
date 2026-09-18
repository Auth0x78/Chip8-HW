`timescale 1ns / 1ps

module alu (
    input wire [ 3:0] alu_op,
    input wire [ 7:0] Xin,
    input wire [ 7:0] Yin,
    input wire [15:0] Rin,

    output logic [7:0] Z,
    output logic [7:0] A
);

`include "alu_params.vh"

  always_comb begin
    // Default assignments to prevent unintended latches
    A = 8'h00;
    Z = 8'h00;

    case (alu_op)
      ALU_SHIFT_RIGHT: begin
        A[0] = Xin[0];     // VF = shifted out LSB (CHIP-8 SHR)
        Z = Xin >> 1;
      end
      ALU_SHIFT_LEFT: begin
        A[0] = Xin[7];     // VF = shifted out MSB (CHIP-8 SHL)
        Z = Xin << 1;
      end
      ALU_OR:  Z = Xin | Yin;  // OR
      ALU_AND: Z = Xin & Yin;  // AND
      ALU_XOR: Z = Xin ^ Yin;  // XOR
      ALU_ADD_XY: begin
        {A[0], Z} = Xin + Yin;  // Add with carry bit in A[0]
      end
      ALU_SUB_XY: begin
        Z = Xin - Yin;
        A[0] = (Xin >= Yin) ? 1'b1 : 1'b0;  // VF = 1 if no borrow (x >= y)
      end
      ALU_SUB_YX: begin
        Z = Yin - Xin;
        A[0] = (Yin >= Xin) ? 1'b1 : 1'b0;  // VF = 1 if no borrow (y >= x)
      end
      ALU_ADD_RX: begin
        {A, Z} = Rin + {8'b0, Xin};  // Zero-extend Xin to match 16-bit I
      end
      default: begin
        Z = 8'h00;
        A = 8'h00;
      end
    endcase
  end

endmodule
