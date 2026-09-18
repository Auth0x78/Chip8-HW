`timescale 1ns / 1ps

module dual_port_ram (
    // Port A: CPU master, read/write, highest priority
    input wire        port_a_req,
    input wire        port_a_write_en,
    input wire [7:0]  port_a_data_in,
    input wire [11:0] port_a_address,
    output wire [7:0] port_a_data_out,

    // Port B: GPU slave, read-only
    input wire        port_b_req,
    input wire [11:0] port_b_address,
    output wire [7:0] port_b_data_out,
    output wire       port_b_ack
);

  // Memory cells of the static RAM. Port B has no write path.
  reg [7:0] memory [0:4095];

  // Port A writes have priority over every Port B read. CPU and GPU reads can
  // be served in parallel because neither operation changes the memory array.
  assign port_b_ack      = port_b_req && !(port_a_req && port_a_write_en);
  assign port_a_data_out = (!port_a_write_en && port_a_req) ? memory[port_a_address] : 8'h00;
  assign port_b_data_out = port_b_req && !(port_a_req && port_a_write_en) ? memory[port_b_address] : 8'h00;

  // Preserve the static, level-sensitive write behavior of the original RAM.
  always_latch begin
    if (port_a_req && port_a_write_en) begin
      memory[port_a_address] = port_a_data_in;
    end
  end

endmodule
