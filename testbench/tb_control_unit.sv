`timescale 1ns / 1ps
module tb_control_unit;

  `include "control_unit_params.vh"
  `include "register_file_params.vh"
  `include "alu_params.vh"

  // Inputs to DUT
  reg         clk;
  reg         rst;
  reg  [15:0] in_data;
  reg  [15:0] rf_data_bus;
  reg  [15:0] rf_i_reg;
  reg  [ 7:0] rf_dt_reg;
  reg  [ 7:0] alu_result;
  reg  [ 7:0] alu_vf;
  reg  [ 7:0] rand_data;
  reg  [15:0] key_state;
  reg         gpu_cmd_ready;

  // Outputs from DUT
  wire [15:0] mem_addr;
  wire [ 7:0] out_mem_data;
  wire        mem_write_en;
  wire        mem_req;
  wire        rf_write_en;
  wire [ 4:0] rf_addr_a;
  wire [ 3:0] rf_rd_addr_reg_y;
  wire [ 2:0] rf_write_dst_sel;
  wire [ 7:0] rf_in_data_low;
  wire [ 7:0] rf_in_data_high;
  wire [ 3:0] alu_op_out;
  wire [ 7:0] alu_xin;
  wire [ 7:0] alu_yin;
  wire [15:0] alu_rin;
  wire        dt_write_en;
  wire [ 7:0] dt_write_val;
  wire        st_write_en;
  wire [ 7:0] st_write_val;
  wire        gpu_cmd_valid;
  wire [ 1:0] gpu_cmd_type;
  wire [ 7:0] gpu_cmd_x;
  wire [ 7:0] gpu_cmd_y;
  wire [ 3:0] gpu_cmd_height;
  wire [11:0] gpu_cmd_index;
  wire [15:0] pc_monitor;
  wire [ 7:0] sp_monitor;
  wire [ 2:0] state_monitor;

  // Counters
  integer pass_count = 0;
  integer fail_count = 0;

  // Instantiate Unit Under Test (DUT)
  control_unit uut (
      .clk              (clk),
      .rst              (rst),
      .in_data          (in_data),
      .mem_addr         (mem_addr),
      .out_mem_data     (out_mem_data),
      .mem_write_en     (mem_write_en),
      .mem_req          (mem_req),
      .rf_write_en      (rf_write_en),
      .rf_addr_a        (rf_addr_a),
      .rf_rd_addr_reg_y (rf_rd_addr_reg_y),
      .rf_write_dst_sel (rf_write_dst_sel),
      .rf_in_data_low   (rf_in_data_low),
      .rf_in_data_high  (rf_in_data_high),
      .rf_data_bus      (rf_data_bus),
      .rf_i_reg         (rf_i_reg),
      .rf_dt_reg        (rf_dt_reg),
      .alu_op_out       (alu_op_out),
      .alu_xin          (alu_xin),
      .alu_yin          (alu_yin),
      .alu_rin          (alu_rin),
      .alu_result       (alu_result),
      .alu_vf           (alu_vf),
      .dt_write_en      (dt_write_en),
      .dt_write_val     (dt_write_val),
      .st_write_en      (st_write_en),
      .st_write_val     (st_write_val),
      .rand_data        (rand_data),
      .key_state        (key_state),
      .gpu_cmd_ready    (gpu_cmd_ready),
      .gpu_cmd_valid    (gpu_cmd_valid),
      .gpu_cmd_type     (gpu_cmd_type),
      .gpu_cmd_x        (gpu_cmd_x),
      .gpu_cmd_y        (gpu_cmd_y),
      .gpu_cmd_height   (gpu_cmd_height),
      .gpu_cmd_index    (gpu_cmd_index),
      .pc_monitor       (pc_monitor),
      .sp_monitor       (sp_monitor),
      .state_monitor    (state_monitor)
  );

  // Clock generation
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Task to step through a 2-cycle instruction (FETCH -> DECODE_EXEC -> FETCH)
  task static step_instruction;
    input [15:0] opcode;
    begin
      in_data = opcode;
      @(posedge clk);  // Latches opcode into instr_reg; state becomes DECODE_EXEC
      #1;
      @(posedge clk);  // Executes instruction; state returns to FETCH
      #1;
    end
  endtask

  // Main Test Stimulus
  initial begin
    // Setup GTKWave VCD dump files
    $dumpfile({`VCD_DIR, "/control_unit.vcd"});
    $dumpvars(0, tb_control_unit);

    // Initialize inputs
    clk           = 1'b0;
    rst           = 1'b1;
    in_data       = 16'h0000;
    rf_data_bus   = 16'h0000;
    rf_i_reg      = 16'h0000;
    rf_dt_reg     = 8'h00;
    alu_result    = 8'h00;
    alu_vf        = 8'h00;
    rand_data     = 8'hA5;
    key_state     = 16'h0000;
    gpu_cmd_ready = 1'b1;

    #20;
    @(negedge clk);
    rst = 1'b0;
    #1;

    $display("==================================================");
    $display("          RUNNING CONTROL UNIT TESTBENCH          ");
    $display("==================================================");

    // 1. Reset check
    if (pc_monitor === 16'h0200 && sp_monitor === 8'h00 && state_monitor === CU_STATE_FETCH) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Reset state: pc=%0h sp=%0h state=%0d", pc_monitor, sp_monitor, state_monitor);
    end

    // 2. Jump (1350)
    step_instruction(16'h1350);
    if (pc_monitor === 16'h0350 && state_monitor === CU_STATE_FETCH) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Jump 1350: expected pc=0350, got pc=%0h state=%0d", pc_monitor, state_monitor);
    end

    // 3. Subroutine Call (2400)
    // When executing 2400 from pc=0350, return address is 0352
    in_data = 16'h2400;
    @(posedge clk);  // FETCH -> DECODE_EXEC
    #1;
    @(posedge clk);  // Executes: pushes return address, pc becomes 0400, sp becomes 1
    #1;
    if (pc_monitor === 16'h0400 && sp_monitor === 8'h01 && rf_write_en === 1'b1 &&
        rf_write_dst_sel === RF_WRITE_STACK && rf_in_data_low === 8'h52 && rf_in_data_high === 8'h03) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Call 2400: pc=%0h (exp 0400) sp=%0d (exp 1) ret_addr=%0h%0h (exp 0352)",
               pc_monitor, sp_monitor, rf_in_data_high, rf_in_data_low);
    end

    // 4. Return from Subroutine (00EE)
    in_data = 16'h00EE;
    @(posedge clk);  // FETCH -> DECODE_EXEC
    #1;
    rf_data_bus = 16'h0352;  // Mock stack pop data
    @(posedge clk);  // Executes: pops stack, pc becomes 0352, sp becomes 0
    #1;
    if (pc_monitor === 16'h0352 && sp_monitor === 8'h00) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Ret 00EE: pc=%0h (exp 0352) sp=%0d (exp 0)", pc_monitor, sp_monitor);
    end

    // 5. Skip if Equal Immediate (3120) with Vx == 20
    in_data = 16'h3120;
    @(posedge clk);  // FETCH -> DECODE_EXEC
    #1;
    rf_data_bus = 16'h2000;  // Vx = 20
    @(posedge clk);  // Executes skip
    #1;
    if (pc_monitor === 16'h0356) begin  // 0352 + 4 = 0356
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Skip SE: pc=%0h (exp 0356)", pc_monitor);
    end

    // 6. Load Immediate (62AB) -> V2 = AB
    in_data = 16'h62AB;
    @(posedge clk);  // FETCH -> DECODE_EXEC
    #1;
    @(posedge clk);  // Executes: writes V2 = AB
    #1;
    if (rf_write_en === 1'b1 && rf_addr_a === 5'h02 && rf_write_dst_sel === RF_WRITE_V &&
        rf_in_data_low === 8'hAB && pc_monitor === 16'h0358) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Load 62AB: rf_write_en=%0b addr=%0h data=%0h",
               rf_write_en, rf_addr_a, rf_in_data_low);
    end

    // 7. ALU Add Reg (8124) with carry
    in_data = 16'h8124;
    @(posedge clk);  // FETCH -> DECODE_EXEC
    #1;
    rf_data_bus = 16'hFF02;  // V1 = FF, V2 = 02
    alu_result  = 8'h01;
    alu_vf      = 8'h01;    // carry = 1
    @(posedge clk);  // Executes: writes V1=01, transitions to ALU_VF_WRITE
    #1;
    if (state_monitor === CU_STATE_ALU_VF_WRITE && rf_write_en === 1'b1 && rf_addr_a === 5'h01 &&
        rf_in_data_low === 8'h01) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] ALU 8124 step 1: state=%0d write_en=%0b addr=%0h data=%0h",
               state_monitor, rf_write_en, rf_addr_a, rf_in_data_low);
    end

    @(posedge clk);  // Writes VF=1, transitions to FETCH
    #1;
    if (rf_write_en === 1'b1 && rf_addr_a === 5'h0F && rf_in_data_low === 8'h01 &&
        pc_monitor === 16'h035A) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] ALU 8124 VF write: rf_addr_a=%0h data=%0h pc=%0h",
               rf_addr_a, rf_in_data_low, pc_monitor);
    end

    // 8. BCD Store (F133) for Vx = 254 (0xFE)
    rf_i_reg = 16'h0600;
    in_data  = 16'hF133;
    @(posedge clk);  // FETCH -> DECODE_EXEC
    #1;
    rf_data_bus = 16'hFE00;  // Vx = 254
    @(posedge clk);  // DECODE_EXEC -> STORE_BCD (calc BCD)
    #1;
    @(posedge clk);  // STORE_BCD step 0: writes hundreds (2) to 0600
    #1;
    if (mem_addr === 16'h0600 && out_mem_data === 8'd2 && mem_write_en === 1'b1) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] BCD hundreds: addr=%0h data=%0d", mem_addr, out_mem_data);
    end

    @(posedge clk);  // STORE_BCD step 1: writes tens (5) to 0601
    #1;
    if (mem_addr === 16'h0601 && out_mem_data === 8'd5 && mem_write_en === 1'b1) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] BCD tens: addr=%0h data=%0d", mem_addr, out_mem_data);
    end

    @(posedge clk);  // STORE_BCD step 2: writes ones (4) to 0602
    #1;
    if (mem_addr === 16'h0602 && out_mem_data === 8'd4 && mem_write_en === 1'b1 &&
        pc_monitor === 16'h035C) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] BCD ones: addr=%0h data=%0d pc=%0h", mem_addr, out_mem_data, pc_monitor);
    end

    // 9. GPU Clear Display (00E0)
    in_data = 16'h00E0;
    @(posedge clk);  // FETCH -> DECODE_EXEC
    #1;
    if (gpu_cmd_valid === 1'b1 && gpu_cmd_type === GPU_CMD_CLEAR) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] GPU Clear 00E0: valid=%0b type=%0b", gpu_cmd_valid, gpu_cmd_type);
    end

    @(posedge clk);  // DECODE_EXEC -> FETCH
    #1;

    // Final Output Summary
    $display("==================================================");
    $display("RESULTS: %0d PASSED | %0d FAILED", pass_count, fail_count);
    $display("==================================================");

    if (fail_count == 0) begin
      $display(">>> SUCCESS: All control unit tests passed! <<<");
      $finish;
    end else begin
      $display(">>> ERROR: Output mismatches detected. <<<");
      $fatal(1, "Control unit testbench failed");
    end
  end

endmodule
