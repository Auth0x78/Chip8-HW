`timescale 1ns / 1ps

module register_file (
    input wire clk,
    input wire rst,

    // Control / Write Signals
    input wire       write_en,
    input wire [4:0] addr_a,        // Data bus (16 bit) will be mapped to Register[rd_addr_a] or {Vx, Vy}
    input wire [3:0] rd_addr_reg_y,
    input wire [2:0] write_dst_sel,

    // Input data to write to registers
    input wire [7:0] in_data_low,
    input wire [7:0] in_data_high,

    // Register Outputs
    output wire [15:0] data_bus,  // {Vx, Vy} or Stack[sp] (low)

    // Special Registers
    output reg [15:0] I_reg,
    output reg [ 7:0] DT_reg,
    output reg [ 7:0] ST_reg
);

  `include "register_file_params.vh"

  reg [7:0] V[16];

  // CHIP 8 has a internal stack with each entry 16-bit wide and has total space for 16 x (16 bits) 
  reg [15:0] stack[16];

  // Internal data address calculation wire 
  wire [3:0] sp_or_x;
  assign sp_or_x = addr_a[3:0];

  // Routed data
  wire [15:0] routed_data; 
  assign routed_data = addr_a[4] ? stack[sp_or_x] : {V[sp_or_x], V[rd_addr_reg_y]};

  // Read Logic (Asynchronous)
  assign data_bus = write_en ? 16'hZZZZ : routed_data;

  // Write Logic (Synchronous)
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      integer i;
      // Reset all 16 - General Purpose Registers to 0
      for (i = 0; i < 16; i = i + 1) begin
        V[i] <= 8'h00;
      end

      // Reset all special registers
      I_reg  <= 16'h0000;
      DT_reg <= 8'h00;
      ST_reg <= 8'h00;
    end 
    else if (write_en) begin
      case (write_dst_sel)
        RF_WRITE_V:  V[sp_or_x] <= in_data_low;
        RF_WRITE_I:  I_reg <= {in_data_high, in_data_low};
        RF_WRITE_DT: DT_reg <= in_data_low;
        RF_WRITE_ST: ST_reg <= in_data_low;
        RF_WRITE_STACK: stack[sp_or_x] <= {in_data_high, in_data_low};
        default: begin
          // Do nothing
        end
      endcase
    end
  end

endmodule
