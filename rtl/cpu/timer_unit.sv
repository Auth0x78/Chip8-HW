`timescale 1ns / 1ps

module timer_unit #(
    parameter integer CLK_FREQ_HZ = 50_000_000
) (
    // Clock and rst
    input wire clk,
    input wire rst,

    // Write Interface from CPU
    input wire       dt_write_en,
    input wire [7:0] dt_in,
    input wire       st_write_en,
    input wire [7:0] st_in,

    // Timer Outputs
    output reg  [7:0] dt_out,
    output reg  [7:0] st_out,
    output wire       sound_active,
    output wire       tick_60hz
);

  localparam integer TICKS_PER_60HZ = CLK_FREQ_HZ / 60;

  // 60 Hz Tick Divider Counter
  reg [31:0] tick_cnt;
  reg        tick_reg;

  assign tick_60hz    = tick_reg;
  assign sound_active = (st_out > 8'h00);

  // 60 Hz Tick Generation Logic
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      tick_cnt <= 32'd0;
      tick_reg <= 1'b0;
    end else begin
      if (tick_cnt >= (TICKS_PER_60HZ - 1)) begin
        tick_cnt <= 32'd0;
        tick_reg <= 1'b1;
      end else begin
        tick_cnt <= tick_cnt + 32'd1;
        tick_reg <= 1'b0;
      end
    end
  end

  // Delay Timer (DT) Register
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      dt_out <= 8'h00;
    end else if (dt_write_en) begin
      dt_out <= dt_in;
    end else if (tick_reg && (dt_out > 8'h00)) begin
      dt_out <= dt_out - 8'h01;
    end
  end

  // Sound Timer (ST) Register
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      st_out <= 8'h00;
    end else if (st_write_en) begin
      st_out <= st_in;
    end else if (tick_reg && (st_out > 8'h00)) begin
      st_out <= st_out - 8'h01;
    end
  end

endmodule
