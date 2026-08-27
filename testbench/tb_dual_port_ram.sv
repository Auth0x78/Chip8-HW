`timescale 1ns / 1ps

module tb_dual_port_ram;

  // Inputs to DUT
  reg write_en;
  reg high_en;

  reg [7:0] data_in;
  reg [11:0] address;

  // Outputs from DUT
  wire [15:0] data_out;

  // Reference Model Expected Values
  reg [15:0] expected_data;
  reg [15:0] rx_data;

  // Counters
  integer i;
  integer pass_count = 0;
  integer fail_count = 0;

  // Instantiate Unit Under Test (DUT)
  dual_port_ram dut (
      // Inputs to double port ram
      .write_en(write_en),
      .high_en (high_en),
      .data_in (data_in),
      .address (address),
      // Output data lane
      .data_out(data_out)
  );

  // Reference model calculation task
  task static write_data;
    input [11:0] addr;
    input [7:0] data;
    begin
      data_in = data;
      address = addr;
      #1;  // Wait for data to reach the port and settle

      write_en = 1;
      #5;  // Wait for the write to actually happen

      write_en = 0;
      #1;  // Hold data for a while so that write_en settles to zero
      data_in = 8'hZZ;
      address = 12'hZZZ;
    end
  endtask

  task static read_data;
    input [11:0] addr;
    input highEn;
    begin
      write_en = 0;
      address  = addr;
      high_en  = highEn;

      #1;
      rx_data = data_out;
      #1;  // Wait for signals to settle and read to actually happen
      address = 12'hZZZ;
      high_en = 0;
    end
  endtask

  // Main Test Stimulus
  initial begin
    // Initialize inputs
    write_en = 0;
    high_en = 0;
    data_in = 8'h00;
    address = 12'h000;
    expected_data = 16'h0000;
    rx_data = 16'h0000;

    // Setup GTKWave VCD dump files
    $dumpfile({`VCD_DIR, "/dual_port_ram.vcd"});
    $dumpvars(0, tb_dual_port_ram);

    for (i = 4090; i < 4096; i = i + 1) $dumpvars(0, dut.memory[i]);

    $display("==================================================");
    $display("          RUNNING 2 PORT RAM TESTBENCH            ");
    $display("==================================================");

    // Directed Edge-Case Checks
    $display("--- Running Directed Edge Cases ---");

    // Test 1: Write data and read the data as word
    expected_data = 16'hAA55;
    write_data(12'hFFE, expected_data[15:8]);
    write_data(12'hFFF, expected_data[7:0]);

    #5;
    read_data(12'hFFE, 1);

    if (rx_data == expected_data) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL]: 2 Byte write and word read | Expected = %0h Got = %0h", expected_data,
               rx_data);
    end


    // Test 2: Read already written data as byte
    #5;
    read_data(12'hFFE, 0);

    if (rx_data[15:8] === 8'hZZ && rx_data[7:0] == expected_data[15:8]) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL]: Byte read already present data | Expected = ZZ%0b Got = %0b",
               expected_data[15:8], rx_data);
    end

    // Final Output Summary
    $display("==================================================");
    $display("RESULTS: %0d PASSED | %0d FAILED", pass_count, fail_count);
    $display("==================================================");

    if (fail_count == 0) $display(">>> SUCCESS: All RAM tests passed! <<<");
    else $display(">>> FAILURE: Output mismatches detected. <<<");

    $finish;
  end
endmodule
