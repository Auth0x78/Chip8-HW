`timescale 1ns / 1ps
`include "alu_params.vh"

module tb_decoder;

  // Inputs to DUT
  reg [15:0] instr;

  // Outputs from DUT
  wire video_cmd_clear;
  wire video_cmd_draw;
  wire ky_skip_xkey_press;
  wire ky_skip_xkey_notpress;
  wire br_ret;
  wire br_jump;
  wire br_jump_v0_offset;
  wire br_call;
  wire br_skip_eq_imm;
  wire br_skip_neq_imm;
  wire br_skip_eq_reg;
  wire br_skip_neq_reg;
  wire load_x_imm;
  wire load_x_from_y;
  wire load_index_imm;
  wire load_vx_dt;
  wire load_vx_key;
  wire load_dt_vx;
  wire load_st_vx;
  wire load_i_font;
  wire store_bcd_of_x;
  wire store_V_reg;
  wire read_vx_mem_i;
  wire alu_x_imm_add;
  wire alu_and_rand_imm;
  wire alu_xy_op;
  wire alu_add_i_x;
  wire [3:0] alu_op;
  wire [3:0] reg_x_addr;
  wire [3:0] reg_y_addr;
  wire [7:0] imm_data;
  wire [11:0] imm_addr;

  // Reference model expected values
  reg expected_video_cmd_clear;
  reg expected_video_cmd_draw;
  reg expected_ky_skip_xkey_press;
  reg expected_ky_skip_xkey_notpress;
  reg expected_br_ret;
  reg expected_br_jump;
  reg expected_br_jump_v0_offset;
  reg expected_br_call;
  reg expected_br_skip_eq_imm;
  reg expected_br_skip_neq_imm;
  reg expected_br_skip_eq_reg;
  reg expected_br_skip_neq_reg;
  reg expected_load_x_imm;
  reg expected_load_x_from_y;
  reg expected_load_index_imm;
  reg expected_load_vx_dt;
  reg expected_load_vx_key;
  reg expected_load_dt_vx;
  reg expected_load_st_vx;
  reg expected_load_i_font;
  reg expected_store_bcd_of_x;
  reg expected_store_V_reg;
  reg expected_read_vx_mem_i;
  reg expected_alu_x_imm_add;
  reg expected_alu_and_rand_imm;
  reg expected_alu_xy_op;
  reg expected_alu_add_i_x;
  reg [3:0] expected_alu_op;
  reg [3:0] expected_reg_x_addr;
  reg [3:0] expected_reg_y_addr;
  reg [7:0] expected_imm_data;
  reg [11:0] expected_imm_addr;

  // Counters
  integer i;
  integer pass_count = 0;
  integer fail_count = 0;

  // Instantiate Unit Under Test (DUT)
  decoder uut (
      .instr                   (instr),
      .video_cmd_clear         (video_cmd_clear),
      .video_cmd_draw          (video_cmd_draw),
      .ky_skip_xkey_press      (ky_skip_xkey_press),
      .ky_skip_xkey_notpress   (ky_skip_xkey_notpress),
      .br_ret                  (br_ret),
      .br_jump                 (br_jump),
      .br_jump_v0_offset       (br_jump_v0_offset),
      .br_call                 (br_call),
      .br_skip_eq_imm          (br_skip_eq_imm),
      .br_skip_neq_imm         (br_skip_neq_imm),
      .br_skip_eq_reg          (br_skip_eq_reg),
      .br_skip_neq_reg         (br_skip_neq_reg),
      .load_x_imm              (load_x_imm),
      .load_x_from_y           (load_x_from_y),
      .load_index_imm          (load_index_imm),
      .load_vx_dt              (load_vx_dt),
      .load_vx_key             (load_vx_key),
      .load_dt_vx              (load_dt_vx),
      .load_st_vx              (load_st_vx),
      .load_i_font             (load_i_font),
      .store_bcd_of_x          (store_bcd_of_x),
      .store_V_reg             (store_V_reg),
      .read_vx_mem_i           (read_vx_mem_i),
      .alu_x_imm_add           (alu_x_imm_add),
      .alu_and_rand_imm        (alu_and_rand_imm),
      .alu_xy_op               (alu_xy_op),
      .alu_add_i_x             (alu_add_i_x),
      .alu_op                  (alu_op),
      .reg_x_addr              (reg_x_addr),
      .reg_y_addr              (reg_y_addr),
      .imm_data                (imm_data),
      .imm_addr                (imm_addr)
  );

  // Reference model and comparison task
  task static check_instruction;
    input [15:0] instruction;
    begin
      expected_video_cmd_clear       = instruction === 16'h00E0;
      expected_video_cmd_draw        = instruction[15:12] === 4'hD;
      expected_ky_skip_xkey_press    = instruction[15:12] === 4'hE && instruction[7:0] === 8'h9E;
      expected_ky_skip_xkey_notpress = instruction[15:12] === 4'hE && instruction[7:0] === 8'hA1;

      expected_br_ret            = instruction === 16'h00EE;
      expected_br_jump           = instruction[15:12] === 4'h1;
      expected_br_jump_v0_offset = instruction[15:12] === 4'hB;
      expected_br_call           = instruction[15:12] === 4'h2;
      expected_br_skip_eq_imm    = instruction[15:12] === 4'h3;
      expected_br_skip_neq_imm   = instruction[15:12] === 4'h4;
      expected_br_skip_eq_reg   = instruction[15:12] === 4'h5 && instruction[3:0] === 4'h0;
      expected_br_skip_neq_reg  = instruction[15:12] === 4'h9 && instruction[3:0] === 4'h0;

      expected_load_x_imm        = instruction[15:12] === 4'h6;
      expected_load_x_from_y     = instruction[15:12] === 4'h8 && instruction[3:0] === 4'h0;
      expected_load_index_imm    = instruction[15:12] === 4'hA;
      expected_load_vx_dt        = instruction[15:12] === 4'hF && instruction[7:0] === 8'h07;
      expected_load_vx_key       = instruction[15:12] === 4'hF && instruction[7:0] === 8'h0A;
      expected_load_dt_vx        = instruction[15:12] === 4'hF && instruction[7:0] === 8'h15;
      expected_load_st_vx        = instruction[15:12] === 4'hF && instruction[7:0] === 8'h18;
      expected_load_i_font       = instruction[15:12] === 4'hF && instruction[7:0] === 8'h29;

      expected_store_bcd_of_x    = instruction[15:12] === 4'hF && instruction[7:0] === 8'h33;
      expected_store_V_reg       = instruction[15:12] === 4'hF && instruction[7:0] === 8'h55;
      expected_read_vx_mem_i     = instruction[15:12] === 4'hF && instruction[7:0] === 8'h65;

      expected_alu_x_imm_add     = instruction[15:12] === 4'h7;
      expected_alu_and_rand_imm  = instruction[15:12] === 4'hC;
      expected_alu_xy_op         = instruction[15:12] === 4'h8 &&
                                   ((instruction[3:0] > 4'h0 && instruction[3:0] < 4'h8) ||
                                    instruction[3:0] === 4'hE);
      expected_alu_add_i_x       = instruction[15:12] === 4'hF && instruction[7:0] === 8'h1E;

      expected_alu_op     = 4'h0;
      expected_reg_x_addr = 4'h0;
      expected_reg_y_addr = 4'h0;
      expected_imm_data   = 8'h00;
      expected_imm_addr   = 12'h000;

      if (expected_alu_xy_op)
        expected_alu_op = instruction[3:0];
      else if (expected_alu_add_i_x)
        expected_alu_op = ALU_ADD_RX;

      if (expected_br_jump || expected_br_call || expected_load_index_imm || expected_br_jump_v0_offset) begin
        expected_imm_addr = instruction[11:0];
      end else if (expected_br_skip_eq_imm || expected_br_skip_neq_imm || expected_load_x_imm ||
                   expected_alu_and_rand_imm) begin
        expected_reg_x_addr = instruction[11:8];
        expected_imm_data   = instruction[7:0];
      end else if (expected_br_skip_eq_reg || expected_br_skip_neq_reg) begin
        expected_reg_x_addr = instruction[11:8];
        expected_reg_y_addr = instruction[7:4];
      end else if (expected_ky_skip_xkey_press || expected_ky_skip_xkey_notpress ||
                   expected_read_vx_mem_i || expected_store_V_reg || expected_store_bcd_of_x ||
                   expected_load_i_font || expected_load_st_vx || expected_load_dt_vx ||
                   expected_load_vx_key || expected_load_vx_dt || expected_alu_add_i_x) begin
        expected_reg_x_addr = instruction[11:8];
      end else if (expected_video_cmd_draw) begin
        expected_reg_x_addr = instruction[11:8];
        expected_reg_y_addr = instruction[7:4];
        expected_imm_data   = {4'h0, instruction[3:0]};
      end

      #5;
      if (video_cmd_clear !== expected_video_cmd_clear || video_cmd_draw !== expected_video_cmd_draw ||
          ky_skip_xkey_press !== expected_ky_skip_xkey_press || ky_skip_xkey_notpress !== expected_ky_skip_xkey_notpress ||
          br_ret !== expected_br_ret || br_jump !== expected_br_jump || br_jump_v0_offset !== expected_br_jump_v0_offset ||
          br_call !== expected_br_call || br_skip_eq_imm !== expected_br_skip_eq_imm ||
          br_skip_neq_imm !== expected_br_skip_neq_imm || br_skip_eq_reg !== expected_br_skip_eq_reg ||
          br_skip_neq_reg !== expected_br_skip_neq_reg || load_x_imm !== expected_load_x_imm ||
          load_x_from_y !== expected_load_x_from_y || load_index_imm !== expected_load_index_imm ||
          load_vx_dt !== expected_load_vx_dt || load_vx_key !== expected_load_vx_key ||
          load_dt_vx !== expected_load_dt_vx || load_st_vx !== expected_load_st_vx ||
          load_i_font !== expected_load_i_font || store_bcd_of_x !== expected_store_bcd_of_x ||
          store_V_reg !== expected_store_V_reg || read_vx_mem_i !== expected_read_vx_mem_i ||
          alu_x_imm_add !== expected_alu_x_imm_add || alu_and_rand_imm !== expected_alu_and_rand_imm ||
          alu_xy_op !== expected_alu_xy_op || alu_add_i_x !== expected_alu_add_i_x || alu_op !== expected_alu_op ||
          ((expected_br_jump || expected_br_call || expected_load_index_imm || expected_br_jump_v0_offset) &&
           imm_addr !== expected_imm_addr) ||
          ((expected_br_skip_eq_imm || expected_br_skip_neq_imm || expected_load_x_imm ||
            expected_alu_and_rand_imm) &&
           (reg_x_addr !== expected_reg_x_addr || imm_data !== expected_imm_data)) ||
          ((expected_br_skip_eq_reg || expected_br_skip_neq_reg) &&
           (reg_x_addr !== expected_reg_x_addr || reg_y_addr !== expected_reg_y_addr)) ||
          ((expected_ky_skip_xkey_press || expected_ky_skip_xkey_notpress || expected_read_vx_mem_i ||
            expected_store_V_reg || expected_store_bcd_of_x || expected_load_i_font ||
            expected_load_st_vx || expected_load_dt_vx || expected_load_vx_key || expected_load_vx_dt ||
            expected_alu_add_i_x) && reg_x_addr !== expected_reg_x_addr) ||
          (expected_video_cmd_draw &&
           (reg_x_addr !== expected_reg_x_addr || reg_y_addr !== expected_reg_y_addr ||
            imm_data !== expected_imm_data))) begin
        fail_count = fail_count + 1;
        $display("[FAIL] Instruction %0h: expected flags (vx_dt=%b vx_key=%b dt_vx=%b st_vx=%b font=%b bcd=%b store=%b read=%b add_i=%b) got (%b %b %b %b %b %b %b %b %b), expected fields (alu=%h x=%h y=%h data=%h addr=%h) got (%h %h %h %h %h)",
                 instruction, expected_load_vx_dt, expected_load_vx_key, expected_load_dt_vx,
                 expected_load_st_vx, expected_load_i_font, expected_store_bcd_of_x,
                 expected_store_V_reg, expected_read_vx_mem_i, expected_alu_add_i_x,
                 load_vx_dt, load_vx_key, load_dt_vx, load_st_vx, load_i_font,
                 store_bcd_of_x, store_V_reg, read_vx_mem_i, alu_add_i_x,
                 expected_alu_op, expected_reg_x_addr, expected_reg_y_addr,
                 expected_imm_data, expected_imm_addr, alu_op, reg_x_addr,
                 reg_y_addr, imm_data, imm_addr);
      end else begin
        pass_count = pass_count + 1;
      end
    end
  endtask

  // Main Test Stimulus
  initial begin
    // Setup GTKWave VCD dump files
    $dumpfile({`VCD_DIR, "/decoder.vcd"});
    $dumpvars(0, tb_decoder);

    instr = 16'h0000;

    $display("==================================================");
    $display("          RUNNING DECODER TESTBENCH              ");
    $display("==================================================");
    $display("--- Running Exhaustive Instruction Checks ---");

    for (i = 0; i < 65536; i = i + 1) begin
      instr = i[15:0];
      check_instruction(instr);
    end

    // Final Output Summary
    $display("==================================================");
    $display("RESULTS: %0d PASSED | %0d FAILED", pass_count, fail_count);
    $display("==================================================");

    if (fail_count == 0) $display(">>> SUCCESS: All decoder tests passed! <<<");
    else $display(">>> ERROR: Output mismatches detected. <<<");

    $finish;
  end

endmodule
