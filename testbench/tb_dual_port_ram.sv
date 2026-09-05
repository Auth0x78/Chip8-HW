`timescale 1ns / 1ps

module tb_dual_port_ram;

  // Port A: CPU master
  reg        port_a_req;
  reg        port_a_write_en;
  reg [7:0]  port_a_data_in;
  reg [11:0] port_a_address;
  wire [7:0] port_a_data_out;

  // Port B: GPU read-only slave
  reg        port_b_req;
  reg [11:0] port_b_address;
  wire [7:0] port_b_data_out;
  wire       port_b_ack;

  // Reference model and counters
  reg [7:0] reference_memory [0:4095];
  reg [7:0] expected_data;
  integer i;
  integer pass_count = 0;
  integer fail_count = 0;

  // Instantiate Unit Under Test
  dual_port_ram dut (
      .port_a_req      (port_a_req),
      .port_a_write_en (port_a_write_en),
      .port_a_data_in  (port_a_data_in),
      .port_a_address  (port_a_address),
      .port_a_data_out (port_a_data_out),
      .port_b_req      (port_b_req),
      .port_b_address  (port_b_address),
      .port_b_data_out (port_b_data_out),
      .port_b_ack      (port_b_ack)
  );

  task static check_condition;
    input condition;
    input string description;
    begin
      if (condition) begin
        pass_count = pass_count + 1;
      end
      else begin
        fail_count = fail_count + 1;
        $display("[FAIL] %s", description);
      end
    end
  endtask

  function [11:0] random_address_value;
    begin
      random_address_value = 12'($urandom());
    end
  endfunction

  function [7:0] random_data_value;
    begin
      random_data_value = 8'($urandom());
    end
  endfunction

  task static cpu_write;
    input [11:0] addr;
    input [7:0] data;
    begin
      port_a_req       = 1'b1;
      port_a_write_en  = 1'b1;
      port_a_address   = addr;
      port_a_data_in   = data;
      #1;
      check_condition(port_b_ack === 1'b0, "GPU was acknowledged during a CPU write");
      reference_memory[addr] = data;
      port_a_req       = 1'b0;
      port_a_write_en  = 1'b0;
      port_a_address   = 12'h000;
      port_a_data_in   = 8'h00;
      #1;
    end
  endtask

  task static cpu_read;
    input [11:0] addr;
    begin
      port_a_req       = 1'b1;
      port_a_write_en  = 1'b0;
      port_a_address   = addr;
      #1;
      check_condition(port_a_data_out === reference_memory[addr], "CPU read returned incorrect data");
      port_a_req       = 1'b0;
      port_a_address   = 12'h000;
      #1;
    end
  endtask

  task static gpu_read;
    input [11:0] addr;
    begin
      port_b_req       = 1'b1;
      port_b_address   = addr;
      #1;
      check_condition(port_b_ack === 1'b1, "GPU read was not acknowledged");
      check_condition(port_b_data_out === reference_memory[addr], "GPU read returned incorrect data");
      port_b_req       = 1'b0;
      port_b_address   = 12'h000;
      #1;
    end
  endtask

  task static simultaneous_read;
    input [11:0] cpu_addr;
    input [11:0] gpu_addr;
    begin
      port_a_req       = 1'b1;
      port_a_write_en  = 1'b0;
      port_a_address   = cpu_addr;
      port_b_req       = 1'b1;
      port_b_address   = gpu_addr;
      #1;
      check_condition(port_b_ack === 1'b1, "GPU read was not acknowledged during simultaneous reads");
      check_condition(port_a_data_out === reference_memory[cpu_addr], "CPU simultaneous read returned incorrect data");
      check_condition(port_b_data_out === reference_memory[gpu_addr], "GPU simultaneous read returned incorrect data");
      port_a_req       = 1'b0;
      port_b_req       = 1'b0;
      port_a_address   = 12'h000;
      port_b_address   = 12'h000;
      #1;
    end
  endtask

  // Main Test Stimulus
  initial begin
    $dumpfile({`VCD_DIR, "/dual_port_ram.vcd"});
    $dumpvars(0, tb_dual_port_ram);

    for (i = 4090; i < 4096; i = i + 1) $dumpvars(0, dut.memory[i]);

    // Initialize inputs. This RAM intentionally has no clock or reset port.
    port_a_req       = 1'b0;
    port_a_write_en  = 1'b0;
    port_a_data_in   = 8'h00;
    port_a_address   = 12'h000;
    port_b_req       = 1'b0;
    port_b_address   = 12'h000;

    $display("==================================================");
    $display("       RUNNING STATIC TRUE DUAL-PORT RAM TEST    ");
    $display("==================================================");

    // Idle outputs and inactive acknowledgements.
    #1;
    check_condition(port_b_ack === 1'b0, "Port B acknowledged while idle");
    check_condition(port_a_data_out === 8'h00, "Port A inactive data output was not zero");
    check_condition(port_b_data_out === 8'h00, "Port B inactive data output was not zero");

    // CPU writes and reads both legal boundary addresses.
    cpu_write(12'h000, 8'hA5);
    cpu_write(12'hFFF, 8'h5A);
    cpu_read(12'h000);
    cpu_read(12'hFFF);

    // GPU can read CPU-written data, but it has no write interface.
    gpu_read(12'h000);
    gpu_read(12'hFFF);

    // Both read ports are acknowledged and return data in parallel.
    simultaneous_read(12'h000, 12'hFFF);
    simultaneous_read(12'hFFF, 12'hFFF);

    // CPU write priority: GPU remains unacknowledged until the write request is
    // released, then reads the value that the CPU has just written.
    port_a_req       = 1'b1;
    port_a_write_en  = 1'b1;
    port_a_address   = 12'h123;
    port_a_data_in   = 8'h3C;
    port_b_req       = 1'b1;
    port_b_address   = 12'h123;
    #1;
    check_condition(port_b_ack === 1'b0, "GPU read was acknowledged during CPU priority write");
    reference_memory[12'h123] = 8'h3C;
    port_a_req       = 1'b0;
    port_a_write_en  = 1'b0;
    port_a_address   = 12'h000;
    #1;
    check_condition(port_b_ack === 1'b1, "GPU read was not acknowledged after CPU write completed");
    check_condition(port_b_data_out === 8'h3C, "GPU read did not see the completed CPU write");
    port_b_req       = 1'b0;
    port_b_address   = 12'h000;
    #1;

    // Random CPU writes and reads exercise the full 12-bit address space.
    for (i = 0; i < 100; i = i + 1) begin
      expected_data = random_data_value();
      cpu_write(random_address_value(), expected_data);
    end

    for (i = 0; i < 100; i = i + 1) begin
      cpu_read(random_address_value());
    end

    $display("==================================================");
    $display("RESULTS: %0d PASSED | %0d FAILED", pass_count, fail_count);
    $display("==================================================");

    if (fail_count == 0) begin
      $display(">>> SUCCESS: All static true dual-port RAM tests passed! <<<");
      $finish;
    end
    else begin
      $display(">>> ERROR: RAM output or handshake mismatches detected. <<<");
      $fatal(1, "Static true dual-port RAM testbench failed");
    end
  end

endmodule
