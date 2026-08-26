`timescale 1ns / 1ps

module lfsr_8bit (
    input  logic       clk,
    input  logic       rst_n,
    output logic [7:0] rand_out
);

  // Uses the standard maximal length polynomial taps for 8 bits: x^8 + x^6 + x^5 + x^4 + 1
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rand_out <= 8'hFF;  // Seed value must NOT be zero
    end else begin
      rand_out <= {rand_out[6:0], rand_out[7] ^ rand_out[5] ^ rand_out[4] ^ rand_out[3]};
    end
  end

endmodule
