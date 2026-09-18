`timescale 1ns / 1ps

module cpu #(
    parameter integer CLK_FREQ_HZ    = 50_000_000,
    parameter [15:0]  RESET_PC_ADDR  = 16'h0200,
    parameter [15:0]  FONT_BASE_ADDR = 16'h0050
) (
    // Clock and rst
    input wire clk,
    input wire rst,

    // Memory Bus Interface
    input  wire [15:0] in_data,
    output wire [11:0] mem_addr,
    output wire [ 7:0] out_mem_data,
    output wire        mem_write_en,
    output wire        mem_req,

    // Keypad Interface
    input wire [15:0] key_state,

    // GPU Command FIFO Interface
    input  wire        gpu_cmd_ready,
    output wire        gpu_cmd_valid,
    output wire [ 1:0] gpu_cmd_type,
    output wire [ 7:0] gpu_cmd_x,
    output wire [ 7:0] gpu_cmd_y,
    output wire [ 3:0] gpu_cmd_height,
    output wire [11:0] gpu_cmd_index,

    // Audio Interface
    output wire sound_active,

    // Debug / Status Interface
    output wire [15:0] pc_out,
    output wire [ 7:0] sp_out,
    output wire [ 2:0] state_out,
    output wire [15:0] i_out,
    output wire [ 7:0] dt_out,
    output wire [ 7:0] st_out
);

  // Internal Wires: Control Unit <-> Register File
  wire        rf_write_en;
  wire [ 4:0] rf_addr_a;
  wire [ 3:0] rf_rd_addr_reg_y;
  wire [ 2:0] rf_write_dst_sel;
  wire [ 7:0] rf_in_data_low;
  wire [ 7:0] rf_in_data_high;
  wire [15:0] rf_data_bus;
  wire [15:0] rf_i_reg;
  wire [ 7:0] rf_dt_reg_unused;
  wire [ 7:0] rf_st_reg_unused;

  // Internal Wires: Control Unit <-> ALU
  wire [ 3:0] alu_op;
  wire [ 7:0] alu_xin;
  wire [ 7:0] alu_yin;
  wire [15:0] alu_rin;
  wire [ 7:0] alu_result;
  wire [ 7:0] alu_vf;

  // Internal Wires: Control Unit <-> Timer Unit
  wire        dt_write_en;
  wire [ 7:0] dt_write_val;
  wire        st_write_en;
  wire [ 7:0] st_write_val;
  wire [ 7:0] timer_dt_out;
  wire [ 7:0] timer_st_out;
  wire        timer_tick_60hz;

  // Internal Wires: LFSR
  wire [ 7:0] rand_byte;

  // Internal 16-bit memory address wire
  wire [15:0] full_mem_addr;
  assign mem_addr = full_mem_addr[11:0];

  wire        timer_sound_active;
  wire [15:0] current_i = (rf_write_en && (rf_write_dst_sel == RF_WRITE_I)) ? {rf_in_data_high, rf_in_data_low} : rf_i_reg;

  // Debug Monitor Assignments
  assign i_out        = current_i;
  assign dt_out       = dt_write_en ? dt_write_val : timer_dt_out;
  assign st_out       = st_write_en ? st_write_val : timer_st_out;
  assign sound_active = (st_write_en && (st_write_val > 8'h00)) || timer_sound_active;

  // ---------------------------------------------------------------------------
  // Control Unit Instance
  // ---------------------------------------------------------------------------
  control_unit #(
      .RESET_PC_ADDR (RESET_PC_ADDR),
      .FONT_BASE_ADDR(FONT_BASE_ADDR)
  ) u_control_unit (
      .clk             (clk),
      .rst             (rst),
      .in_data         (in_data),
      .mem_addr        (full_mem_addr),
      .out_mem_data    (out_mem_data),
      .mem_write_en    (mem_write_en),
      .mem_req         (mem_req),
      .rf_write_en     (rf_write_en),
      .rf_addr_a       (rf_addr_a),
      .rf_rd_addr_reg_y(rf_rd_addr_reg_y),
      .rf_write_dst_sel(rf_write_dst_sel),
      .rf_in_data_low  (rf_in_data_low),
      .rf_in_data_high (rf_in_data_high),
      .rf_data_bus     (rf_data_bus),
      .rf_i_reg        (rf_i_reg),
      .rf_dt_reg       (timer_dt_out),
      .alu_op_out      (alu_op),
      .alu_xin         (alu_xin),
      .alu_yin         (alu_yin),
      .alu_rin         (alu_rin),
      .alu_result      (alu_result),
      .alu_vf          (alu_vf),
      .dt_write_en     (dt_write_en),
      .dt_write_val    (dt_write_val),
      .st_write_en     (st_write_en),
      .st_write_val    (st_write_val),
      .rand_data       (rand_byte),
      .key_state       (key_state),
      .gpu_cmd_ready   (gpu_cmd_ready),
      .gpu_cmd_valid   (gpu_cmd_valid),
      .gpu_cmd_type    (gpu_cmd_type),
      .gpu_cmd_x       (gpu_cmd_x),
      .gpu_cmd_y       (gpu_cmd_y),
      .gpu_cmd_height  (gpu_cmd_height),
      .gpu_cmd_index   (gpu_cmd_index),
      .pc_monitor      (pc_out),
      .sp_monitor      (sp_out),
      .state_monitor   (state_out)
  );

  // ---------------------------------------------------------------------------
  // Register File Instance
  // ---------------------------------------------------------------------------
  register_file u_register_file (
      .clk          (clk),
      .rst          (rst),
      .write_en     (rf_write_en),
      .addr_a       (rf_addr_a),
      .rd_addr_reg_y(rf_rd_addr_reg_y),
      .write_dst_sel(rf_write_dst_sel),
      .in_data_low  (rf_in_data_low),
      .in_data_high (rf_in_data_high),
      .data_bus     (rf_data_bus),
      .I_reg        (rf_i_reg),
      .DT_reg       (rf_dt_reg_unused),
      .ST_reg       (rf_st_reg_unused)
  );

  // ---------------------------------------------------------------------------
  // ALU Instance
  // ---------------------------------------------------------------------------
  alu u_alu (
      .alu_op(alu_op),
      .Xin   (alu_xin),
      .Yin   (alu_yin),
      .Rin   (alu_rin),
      .Z     (alu_result),
      .A     (alu_vf)
  );

  // ---------------------------------------------------------------------------
  // LFSR 8-bit Random Number Generator Instance
  // ---------------------------------------------------------------------------
  lfsr_8bit u_lfsr_8bit (
      .clk     (clk),
      .rst_n   (~rst),
      .rand_out(rand_byte)
  );

  // ---------------------------------------------------------------------------
  // Timer Unit Instance
  // ---------------------------------------------------------------------------
  timer_unit #(
      .CLK_FREQ_HZ(CLK_FREQ_HZ)
  ) u_timer_unit (
      .clk         (clk),
      .rst         (rst),
      .dt_write_en (dt_write_en),
      .dt_in       (dt_write_val),
      .st_write_en (st_write_en),
      .st_in       (st_write_val),
      .dt_out      (timer_dt_out),
      .st_out      (timer_st_out),
      .sound_active(timer_sound_active),
      .tick_60hz   (timer_tick_60hz)
  );

endmodule
