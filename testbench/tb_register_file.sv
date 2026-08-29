`timescale 1ns / 1ps
`include "register_file_params.vh"

module tb_register_file;

  // Inputs to DUT
  reg clk;
  reg rst;
  reg write_en;

  // Register read and write select
  reg [4:0] sp_or_vx_sel;
  reg [3:0] vy_sel;
  reg [2:0] write_dst_sel;
  reg [7:0] data_low;
  reg [7:0] data_high;

  // Outputs from DUT
  wire [15:0] data_out;
  wire [7:0] DT;
  wire [7:0] ST;
  wire [15:0] I;

  // Counters
  integer write_test_cnt = 1000;
  integer i;
  integer pass_count = 0;
  integer fail_count = 0;

  // Instantiate Unit Under Test (DUT)
  register_file uut (
    // Inputs
      .clk            (clk),
      .rst            (rst),

    // Control Signals
      .write_en       (write_en),
      .addr_a         (sp_or_vx_sel),
      .rd_addr_reg_y  (vy_sel),
      .write_dst_sel  (write_dst_sel),
      .in_data_low    (data_low),
      .in_data_high   (data_high),
    
    // Register outputs
      .data_bus       (data_out),
      .I_reg          (I),
      .DT_reg         (DT),
      .ST_reg         (ST)
  );

  // Write to V register
  // NOTE: Signals are driven BEFORE the posedge so the DUT samples them
  // correctly on the rising edge.
  task static write_v_register;
    input [3:0] vx_index;
    input [7:0] data;
    begin
      // Drive signals before the rising edge
      write_en      = 1;
      sp_or_vx_sel  = {1'b0, vx_index};
      data_low      = data;
      write_dst_sel = RF_WRITE_V;

      @(posedge clk);  // Write occurs on this edge
      @(negedge clk);  // Deassert halfway through the cycle
      write_en      = 0;
      sp_or_vx_sel  = 5'h0;
      data_low      = 8'h0;
    end
  endtask

  // Write to Index register
  task static write_index_register;
    input [7:0] data_h;
    input [7:0] data_l;
    begin
      // Drive signals before the rising edge
      write_en      = 1;
      data_low      = data_l;
      data_high     = data_h;
      write_dst_sel = RF_WRITE_I;
      @(posedge clk);  // Write occurs on this edge

      @(negedge clk);
      write_en  = 0;
      data_low  = 8'h0;
      data_high = 8'h0;
    end
  endtask

  // Write to Timer register
  task static write_timer_register;
    input st_sel;
    input [7:0] data;
    begin
      // Drive signals before the rising edge
      write_en      = 1;
      data_low      = data;
      data_high     = 8'h0;
      write_dst_sel = st_sel ? RF_WRITE_ST : RF_WRITE_DT;
      @(posedge clk);  // Write occurs on this edge

      @(negedge clk);
      write_en  = 0;
      data_low  = 8'h0;
    end
  endtask

  // Write to Stack
  task static write_stack_register;
    input [3:0] stack_index;
    input [15:0] data;
    begin
      // Drive signals before the rising edge
      write_en      = 1;
      sp_or_vx_sel  = {1'b1, stack_index};
      data_low      = data[7:0];
      data_high     = data[15:8];
      write_dst_sel = RF_WRITE_STACK;
      @(posedge clk);  // Write occurs on this edge

      @(negedge clk);
      write_en      = 0;
      sp_or_vx_sel  = 5'h0;
      data_low      = 8'h0;
      data_high     = 8'h0;
    end
  endtask

  // Clock generation
  initial begin
    clk = 0;

    forever #10 clk = ~clk;
  end

  // Main Test Stimulus
  initial begin
    // Output for task
    reg [7:0] expected_low;
    reg [7:0] expected_high;
    reg [3:0] reg_index_x;
    reg [3:0] reg_index_y;
    reg [3:0] stack_index;
    reg [15:0] expected_stack_data;
    reg st_sel;

    logic [7:0] out;
    string reg_name;

    // Setup GTKWave VCD dump files
    $dumpfile({`VCD_DIR, "/register_file.vcd"});
    $dumpvars(0, tb_register_file);

    for (i = 0; i < 16; i = i + 1) $dumpvars(0, uut.V[i]);

    // Initialize inputs
    pass_count = 0;
    fail_count = 0;

    write_en = 0;
    sp_or_vx_sel = 0;
    vy_sel = 0;
    write_dst_sel = 0;
    
    data_low = 0;
    data_high = 0;
    rst = 1;
    #1;
    rst = 0;

    $display("==================================================");
    $display("          RUNNING REGISTER FILE TESTBENCH         ");
    $display("==================================================");

    // Write test to single write V Register
    for (i = 0; i < write_test_cnt; i = i + 1) begin
      expected_low = $urandom_range(0, 255);
      reg_index_x  = $urandom_range(0, 15);

      write_v_register(reg_index_x, expected_low);

      // Select Vx for read
      sp_or_vx_sel = {1'b0, reg_index_x};
      vy_sel = 4'h0;
      // Let read outputs settle
      #1;

      if (data_out[15:8] === expected_low) begin
        pass_count = pass_count + 1;
      end else begin
        fail_count = fail_count + 1;
        $display("[FAIL] Iteration %0d: Write to V[%0d] | Expected = %0d Got = %0d", i,
                 reg_index_x, expected_low, data_out[15:8]);
      end
    end

    // Write to Timer Register Test
    for (i = 0; i < write_test_cnt; i = i + 1) begin
      expected_low = $urandom_range(0, 255);
      st_sel = $urandom_range(0, 1);
      
      write_timer_register(st_sel, expected_low);

      // Read Timer register
      out = st_sel ? ST : DT;

      // Register Name set
      reg_name = st_sel ? "ST" : "DT";

      if (out === expected_low) begin
        pass_count = pass_count + 1;
      end else begin

        fail_count = fail_count + 1;
        $display("[FAIL] Iteration %0d: Write to %s | Expected = %0d Got = %0d", i, reg_name,
                 expected_low, out);
      end
    end

    // Write to Index Register test
    for (i = 0; i < write_test_cnt; i = i + 1) begin
      expected_low  = $urandom_range(0, 255);
      expected_high = $urandom_range(0, 255);
      write_index_register(expected_high, expected_low);

      if (I === {expected_high, expected_low}) begin
        pass_count = pass_count + 1;
      end else begin
        fail_count = fail_count + 1;
        $display("[FAIL] Iteration %0d: Write to Index | Expected = %0h Got = %0h", i,
                 {expected_high, expected_low}, I);
      end
    end

    // Write to Stack Register test
    for (i = 0; i < write_test_cnt; i = i + 1) begin
      expected_high = $urandom_range(0, 255);
      expected_low  = $urandom_range(0, 255);
      expected_stack_data = {expected_high, expected_low};
      stack_index = $urandom_range(0, 15);
      write_stack_register(stack_index, expected_stack_data);

      // Select stack entry for read
      sp_or_vx_sel = {1'b1, stack_index};
      #1;
      if (data_out === expected_stack_data) begin
        pass_count = pass_count + 1;
      end else begin
        fail_count = fail_count + 1;
        $display("[FAIL] Iteration %0d: Write to Stack[%0d] | Expected = %0h Got = %0h",
                 i, stack_index, expected_stack_data, data_out);
      end
    end

    // Double same register read test
    for (i = 0; i < write_test_cnt; i = i + 1) begin
      reg_index_x = $urandom_range(0, 15);

      // Write known values first so the test does not depend on
      // the contents left by previous tests.
      expected_high = $urandom_range(0, 255);
      expected_low  = $urandom_range(0, 255);

      write_v_register(reg_index_x, expected_high);
      write_v_register(reg_index_x, expected_low);

      // Read the same V register on both read lanes
      sp_or_vx_sel = {1'b0, reg_index_x};
      vy_sel = reg_index_x;

      #1;
      if (data_out === {expected_low, expected_low}) begin
        pass_count = pass_count + 1;
      end else begin
        fail_count = fail_count + 1;
        $display("[FAIL] Iteration %0d: Double read V[%0d] | Expected = %0h Got = %0h",
                 i, reg_index_x, {expected_low, expected_low}, data_out);
      end
    end

    // Final Output Summary
    $display("==================================================");
    $display("RESULTS: %0d PASSED | %0d FAILED", pass_count, fail_count);
    $display("==================================================");
    
    if (fail_count == 0) 
      $display(">>> SUCCESS: All tests passed! <<<");
    else 
      $display(">>> ERROR: Output mismatches detected. <<<");
    
    $finish;
  end

endmodule
