`timescale 1ns / 1ps

module tb_timer_unit;

  // Parameters
  localparam integer CLK_FREQ = 600;  // 10 cycles per 60 Hz tick for quick sim

  // Inputs to DUT
  reg       clk;
  reg       rst;
  reg       dt_write_en;
  reg [7:0] dt_in;
  reg       st_write_en;
  reg [7:0] st_in;

  // Outputs from DUT
  wire [7:0] dt_out;
  wire [7:0] st_out;
  wire       sound_active;
  wire       tick_60hz;

  // Counters
  integer pass_count = 0;
  integer fail_count = 0;
  integer i;

  // Instantiate Unit Under Test (DUT)
  timer_unit #(
      .CLK_FREQ_HZ(CLK_FREQ)
  ) uut (
      .clk         (clk),
      .rst         (rst),
      .dt_write_en (dt_write_en),
      .dt_in       (dt_in),
      .st_write_en (st_write_en),
      .st_in       (st_in),
      .dt_out      (dt_out),
      .st_out      (st_out),
      .sound_active(sound_active),
      .tick_60hz   (tick_60hz)
  );

  // Clock generation
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Write Delay Timer Task
  task static write_dt;
    input [7:0] data;
    begin
      dt_write_en = 1'b1;
      dt_in       = data;
      @(posedge clk);
      @(negedge clk);
      dt_write_en = 1'b0;
      dt_in       = 8'h00;
    end
  endtask

  // Write Sound Timer Task
  task static write_st;
    input [7:0] data;
    begin
      st_write_en = 1'b1;
      st_in       = data;
      @(posedge clk);
      @(negedge clk);
      st_write_en = 1'b0;
      st_in       = 8'h00;
    end
  endtask

  // Main Test Stimulus
  initial begin
    // Setup GTKWave VCD dump files
    $dumpfile({`VCD_DIR, "/timer_unit.vcd"});
    $dumpvars(0, tb_timer_unit);

    // Initialize inputs
    clk         = 1'b0;
    rst         = 1'b1;
    dt_write_en = 1'b0;
    dt_in       = 8'h00;
    st_write_en = 1'b0;
    st_in       = 8'h00;

    #20;
    @(negedge clk);
    rst = 1'b0;
    @(negedge clk);

    $display("==================================================");
    $display("          RUNNING TIMER UNIT TESTBENCH           ");
    $display("==================================================");

    // 1. Reset check
    if (dt_out === 8'h00 && st_out === 8'h00 && sound_active === 1'b0) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Reset state: dt=%0d st=%0d sound_active=%0b", dt_out, st_out, sound_active);
    end

    // 2. Load DT and ST
    write_dt(8'd5);
    write_st(8'd3);

    if (dt_out === 8'd5 && st_out === 8'd3 && sound_active === 1'b1) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Load timers: dt=%0d (exp 5) st=%0d (exp 3) sound=%0b (exp 1)", dt_out, st_out, sound_active);
    end

    // 3. Observe decrements over ticks
    // Each tick is 10 cycles = 100ns
    for (i = 0; i < 6; i = i + 1) begin
      @(posedge tick_60hz);
      #1;
      $display("Tick %0d: DT=%0d ST=%0d sound_active=%0b", i + 1, dt_out, st_out, sound_active);
    end

    // After 6 ticks, DT (loaded with 5) and ST (loaded with 3) must both be 0 and hold at 0 without underflow
    if (dt_out === 8'd0 && st_out === 8'd0 && sound_active === 1'b0) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Underflow check: dt=%0d st=%0d sound_active=%0b", dt_out, st_out, sound_active);
    end

    // 4. Overwrite while running
    write_dt(8'd10);
    if (dt_out === 8'd10) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Overwrite DT: dt=%0d (exp 10)", dt_out);
    end

    // Final Output Summary
    $display("==================================================");
    $display("RESULTS: %0d PASSED | %0d FAILED", pass_count, fail_count);
    $display("==================================================");

    if (fail_count == 0) begin
      $display(">>> SUCCESS: All timer unit tests passed! <<<");
      $finish;
    end else begin
      $display(">>> ERROR: Output mismatches detected. <<<");
      $fatal(1, "Timer unit testbench failed");
    end
  end

endmodule
