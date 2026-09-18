`timescale 1ns / 1ps

module tb_cpu;

  // Inputs to DUT
  reg         clk;
  reg         rst;
  reg  [15:0] key_state;
  reg         gpu_cmd_ready;

  // Outputs from DUT
  wire [11:0] mem_addr;
  wire [ 7:0] out_mem_data;
  wire        mem_write_en;
  wire        mem_req;
  wire        gpu_cmd_valid;
  wire [ 1:0] gpu_cmd_type;
  wire [ 7:0] gpu_cmd_x;
  wire [ 7:0] gpu_cmd_y;
  wire [ 3:0] gpu_cmd_height;
  wire [11:0] gpu_cmd_index;
  wire        sound_active;
  wire [15:0] pc_out;
  wire [ 7:0] sp_out;
  wire [ 2:0] state_out;
  wire [15:0] i_out;
  wire [ 7:0] dt_out;
  wire [ 7:0] st_out;

  // Mock Main RAM: 4 KiB byte memory
  reg  [ 7:0] ram [0:4095];
  wire [15:0] in_data;

  // Instruction word is 16 bits: big-endian consecutive bytes
  assign in_data = (state_out == 3'd0) ?
                   {ram[pc_out[11:0]], (pc_out[11:0] < 12'hFFF) ? ram[pc_out[11:0] + 12'd1] : 8'h00} :
                   {ram[mem_addr], (mem_addr < 12'hFFF) ? ram[mem_addr + 12'd1] : 8'h00};

  // Synchronous Memory Write
  always_ff @(posedge clk) begin
    if (mem_req && mem_write_en) begin
      ram[mem_addr] <= out_mem_data;
    end
  end

  // Counters
  integer pass_count = 0;
  integer fail_count = 0;
  integer i;

  // Instantiate Unit Under Test (DUT)
  cpu #(
      .CLK_FREQ_HZ   (600),     // Fast 60 Hz tick for quick simulation
      .RESET_PC_ADDR (16'h0200),
      .FONT_BASE_ADDR(16'h0050)
  ) uut (
      .clk           (clk),
      .rst           (rst),
      .in_data       (in_data),
      .mem_addr      (mem_addr),
      .out_mem_data  (out_mem_data),
      .mem_write_en  (mem_write_en),
      .mem_req       (mem_req),
      .key_state     (key_state),
      .gpu_cmd_ready (gpu_cmd_ready),
      .gpu_cmd_valid (gpu_cmd_valid),
      .gpu_cmd_type  (gpu_cmd_type),
      .gpu_cmd_x     (gpu_cmd_x),
      .gpu_cmd_y     (gpu_cmd_y),
      .gpu_cmd_height(gpu_cmd_height),
      .gpu_cmd_index (gpu_cmd_index),
      .sound_active  (sound_active),
      .pc_out        (pc_out),
      .sp_out        (sp_out),
      .state_out     (state_out),
      .i_out         (i_out),
      .dt_out        (dt_out),
      .st_out        (st_out)
  );

  // Clock generation
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Helper task to write a 16-bit instruction into memory
  task static load_instruction;
    input [11:0] addr;
    input [15:0] instr;
    begin
      ram[addr]     = instr[15:8];
      ram[addr + 1] = instr[7:0];
    end
  endtask

  // Helper task to step CPU cycles
  task static step_cycles;
    input integer count;
    begin
      repeat (count) @(posedge clk);
      #1;
    end
  endtask

  // Main Test Stimulus
  initial begin
    // Setup GTKWave VCD dump files
    $dumpfile({`VCD_DIR, "/cpu.vcd"});
    $dumpvars(0, tb_cpu);

    // Initialize inputs
    clk           = 1'b0;
    rst           = 1'b1;
    key_state     = 16'h0000;
    gpu_cmd_ready = 1'b1;

    // Initialize entire RAM to 0
    for (i = 0; i < 4096; i = i + 1) begin
      ram[i] = 8'h00;
    end

    // -------------------------------------------------------------------------
    // Load Test Program into RAM starting at 0x200
    // -------------------------------------------------------------------------
    // 0x200: 6005 -> LD V0, 0x05
    load_instruction(12'h200, 16'h6005);
    // 0x202: 6103 -> LD V1, 0x03
    load_instruction(12'h202, 16'h6103);
    // 0x204: 8014 -> ADD V0, V1 (V0 = 8, VF = 0)
    load_instruction(12'h204, 16'h8014);
    // 0x206: 62FF -> LD V2, 0xFF
    load_instruction(12'h206, 16'h62FF);
    // 0x208: 6302 -> LD V3, 0x02
    load_instruction(12'h208, 16'h6302);
    // 0x20A: 8234 -> ADD V2, V3 (V2 = 0x01, VF = 1 carry)
    load_instruction(12'h20A, 16'h8234);
    // 0x20C: 3008 -> SE V0, 0x08 (V0 == 8 -> skips 0x20E)
    load_instruction(12'h20C, 16'h3008);
    // 0x20E: 1350 -> JP 0x350 (Must be SKIPPED)
    load_instruction(12'h20E, 16'h1350);
    // 0x210: 64AA -> LD V4, 0xAA (Target of skip)
    load_instruction(12'h210, 16'h64AA);
    // 0x212: A600 -> LD I, 0x600
    load_instruction(12'h212, 16'hA600);
    // 0x214: F233 -> BCD store of V2 (V2 = 1 -> 0, 0, 1 at 0x600..0x602)
    load_instruction(12'h214, 16'hF233);
    // 0x216: 2300 -> CALL 0x300
    load_instruction(12'h216, 16'h2300);

    // Subroutine at 0x300:
    // 0x300: 6577 -> LD V5, 0x77
    load_instruction(12'h300, 16'h6577);
    // 0x302: 00EE -> RET (Returns to 0x218)
    load_instruction(12'h302, 16'h00EE);

    // 0x218: F515 -> LD DT, V5 (DT = 0x77)
    load_instruction(12'h218, 16'hF515);
    // 0x21A: F518 -> LD ST, V5 (ST = 0x77, sound_active becomes 1)
    load_instruction(12'h21A, 16'hF518);
    // 0x21C: 00E0 -> CLS (Clear screen GPU command)
    load_instruction(12'h21C, 16'h00E0);
    // 0x21E: D015 -> DRW V0, V1, 5 (Draw sprite GPU command)
    load_instruction(12'h21E, 16'hD015);
    // 0x220: 1220 -> JP 0x220 (Infinite loop / Halt)
    load_instruction(12'h220, 16'h1220);

    #20;
    @(negedge clk);
    rst = 1'b0;
    #1;

    $display("==================================================");
    $display("             RUNNING CPU TESTBENCH                ");
    $display("==================================================");

    // 1. Check initial reset state
    if (pc_out === 16'h0200 && sp_out === 8'h00 && state_out === 3'h0) begin
      pass_count = pass_count + 1;
      $display("[PASS] Reset vector: PC=0x%0h, SP=0x%0h", pc_out, sp_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] Reset vector: PC=0x%0h SP=0x%0h state=%0d", pc_out, sp_out, state_out);
    end

    // 2. Execute 6005 (LD V0, 5): takes 2 cycles
    step_cycles(2);
    if (pc_out === 16'h0202) begin
      pass_count = pass_count + 1;
      $display("[PASS] 6005 executed: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 6005 executed: PC=0x%0h (exp 0x0202)", pc_out);
    end

    // 3. Execute 6103 (LD V1, 3): takes 2 cycles
    step_cycles(2);
    if (pc_out === 16'h0204) begin
      pass_count = pass_count + 1;
      $display("[PASS] 6103 executed: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 6103 executed: PC=0x%0h (exp 0x0204)", pc_out);
    end

    // 4. Execute 8014 (ADD V0, V1): ALU op with VF writeback takes 3 cycles
    step_cycles(3);
    if (pc_out === 16'h0206) begin
      pass_count = pass_count + 1;
      $display("[PASS] 8014 executed: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 8014 executed: PC=0x%0h (exp 0x0206)", pc_out);
    end

    // 5. Execute 62FF (LD V2, 0xFF): 2 cycles
    step_cycles(2);
    // 6. Execute 6302 (LD V3, 0x02): 2 cycles
    step_cycles(2);
    // 7. Execute 8234 (ADD V2, V3): 3 cycles
    step_cycles(3);
    if (pc_out === 16'h020C) begin
      pass_count = pass_count + 1;
      $display("[PASS] 8234 executed: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 8234 executed: PC=0x%0h (exp 0x020C)", pc_out);
    end

    // 8. Execute 3008 (SE V0, 8): V0 is 8, so skip is taken! (PC advances to 0x210, skipping 0x20E)
    step_cycles(2);
    if (pc_out === 16'h0210) begin
      pass_count = pass_count + 1;
      $display("[PASS] 3008 Skip Taken: PC=0x%0h (skipped 0x020E correctly)", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 3008 Skip: PC=0x%0h (exp 0x0210)", pc_out);
    end

    // 9. Execute 64AA (LD V4, 0xAA): 2 cycles
    step_cycles(2);
    if (pc_out === 16'h0212) begin
      pass_count = pass_count + 1;
      $display("[PASS] 64AA executed: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 64AA executed: PC=0x%0h", pc_out);
    end

    // 10. Execute A600 (LD I, 0x600): 2 cycles
    step_cycles(2);
    if (pc_out === 16'h0214 && i_out === 16'h0600) begin
      pass_count = pass_count + 1;
      $display("[PASS] A600 executed: I=0x%0h, PC=0x%0h", i_out, pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] A600 executed: I=0x%0h (exp 0x600) PC=0x%0h", i_out, pc_out);
    end

    // 11. Execute F233 (BCD Store of V2):
    // V2 = 0x01 (from 0xFF + 0x02 = 0x101 truncated to 0x01).
    // BCD takes: 1 fetch + 1 decode/calc + 3 write cycles + 1 fetch overlap = 6 cycles
    step_cycles(6);
    if (ram[12'h600] === 8'd0 && ram[12'h601] === 8'd0 && ram[12'h602] === 8'd1 &&
        pc_out === 16'h0216) begin
      pass_count = pass_count + 1;
      $display("[PASS] F233 BCD store: ram[0x600..602] = {%0d, %0d, %0d}",
               ram[12'h600], ram[12'h601], ram[12'h602]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] F233 BCD store: ram[0x600..602] = {%0d, %0d, %0d} PC=0x%0h",
               ram[12'h600], ram[12'h601], ram[12'h602], pc_out);
    end

    // 12. Execute 2300 (CALL 0x300): 1 cycle decode/exec (fetch occurred during final BCD write)
    step_cycles(1);
    if (pc_out === 16'h0300 && sp_out === 8'h01) begin
      pass_count = pass_count + 1;
      $display("[PASS] 2300 CALL: PC=0x%0h, SP=%0d", pc_out, sp_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 2300 CALL: PC=0x%0h (exp 0x0300), SP=%0d (exp 1)", pc_out, sp_out);
    end

    // 13. In subroutine: Execute 6577 (LD V5, 0x77): 2 cycles
    step_cycles(2);
    if (pc_out === 16'h0302) begin
      pass_count = pass_count + 1;
      $display("[PASS] 6577 in sub: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 6577 in sub: PC=0x%0h", pc_out);
    end

    // 14. Execute 00EE (RET): 2 cycles -> returns to 0x218, SP becomes 0
    step_cycles(2);
    if (pc_out === 16'h0218 && sp_out === 8'h00) begin
      pass_count = pass_count + 1;
      $display("[PASS] 00EE RET: PC=0x%0h, SP=%0d", pc_out, sp_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 00EE RET: PC=0x%0h (exp 0x0218), SP=%0d (exp 0)", pc_out, sp_out);
    end

    // 15. Execute F515 (LD DT, V5=0x77): 2 cycles
    step_cycles(2);
    if (dt_out === 8'h77 && pc_out === 16'h021A) begin
      pass_count = pass_count + 1;
      $display("[PASS] F515 LD DT, V5: DT=0x%0h", dt_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] F515 LD DT: DT=0x%0h (exp 0x77)", dt_out);
    end

    // 16. Execute F518 (LD ST, V5=0x77): 2 cycles -> sound_active should be 1
    step_cycles(2);
    if (st_out === 8'h77 && sound_active === 1'b1 && pc_out === 16'h021C) begin
      pass_count = pass_count + 1;
      $display("[PASS] F518 LD ST, V5: ST=0x%0h, sound_active=%0b", st_out, sound_active);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] F518 LD ST: ST=0x%0h, sound_active=%0b", st_out, sound_active);
    end

    // 17. Execute 00E0 (Clear Screen): GPU command emission
    step_cycles(2);
    if (pc_out === 16'h021E) begin
      pass_count = pass_count + 1;
      $display("[PASS] 00E0 Clear Screen executed: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 00E0: PC=0x%0h", pc_out);
    end

    // 18. Execute D015 (DRW V0, V1, 5): GPU command emission with x=V0(8), y=V1(3), n=5, I=0x600
    step_cycles(2);
    if (pc_out === 16'h0220) begin
      pass_count = pass_count + 1;
      $display("[PASS] D015 Draw Sprite executed: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] D015: PC=0x%0h", pc_out);
    end

    // Final Output Summary
    $display("==================================================");
    $display("RESULTS: %0d PASSED | %0d FAILED", pass_count, fail_count);
    $display("==================================================");

    if (fail_count == 0) begin
      $display(">>> SUCCESS: All CPU integration tests passed! <<<");
      $finish;
    end else begin
      $display(">>> ERROR: CPU integration test failures detected. <<<");
      $fatal(1, "CPU testbench failed");
    end
  end

endmodule
