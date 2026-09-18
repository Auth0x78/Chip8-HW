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

    // -------------------------------------------------------------------------
    // Phase 2: Test remaining opcodes
    // -------------------------------------------------------------------------
    // 0x220: 700A -> ADD V0, 0x0A (V0 = 8 + 10 = 18 = 0x12)
    load_instruction(12'h220, 16'h700A);
    // 0x222: 8600 -> LD V6, V0 (V6 = 0x12)
    load_instruction(12'h222, 16'h8600);
    // 0x224: 670F -> LD V7, 0x0F
    load_instruction(12'h224, 16'h670F);
    // 0x226: 8671 -> OR V6, V7 (V6 = 0x12 | 0x0F = 0x1F, VF = 0)
    load_instruction(12'h226, 16'h8671);
    // 0x228: 6833 -> LD V8, 0x33
    load_instruction(12'h228, 16'h6833);
    // 0x22A: 8682 -> AND V6, V8 (V6 = 0x1F & 0x33 = 0x13, VF = 0)
    load_instruction(12'h22A, 16'h8682);
    // 0x22C: 6955 -> LD V9, 0x55
    load_instruction(12'h22C, 16'h6955);
    // 0x22E: 8693 -> XOR V6, V9 (V6 = 0x13 ^ 0x55 = 0x46, VF = 0)
    load_instruction(12'h22E, 16'h8693);
    // 0x230: 6A20 -> LD VA, 0x20
    load_instruction(12'h230, 16'h6A20);
    // 0x232: 6B10 -> LD VB, 0x10
    load_instruction(12'h232, 16'h6B10);
    // 0x234: 8AB5 -> SUB VA, VB (VA = 0x20 - 0x10 = 0x10, VF = 1)
    load_instruction(12'h234, 16'h8AB5);
    // 0x236: 6C07 -> LD VC, 0x07
    load_instruction(12'h236, 16'h6C07);
    // 0x238: 8C06 -> SHR VC (VC = 0x07 >> 1 = 0x03, VF = 1)
    load_instruction(12'h238, 16'h8C06);
    // 0x23A: 6D05 -> LD VD, 0x05
    load_instruction(12'h23A, 16'h6D05);
    // 0x23C: 6E0C -> LD VE, 0x0C
    load_instruction(12'h23C, 16'h6E0C);
    // 0x23E: 8DE7 -> SUBN VD, VE (VD = VE - VD = 0x0C - 0x05 = 0x07, VF = 1)
    load_instruction(12'h23E, 16'h8DE7);
    // 0x240: 8DEE -> SHL VD (VD = 0x07 << 1 = 0x0E, VF = 0)
    load_instruction(12'h240, 16'h8DEE);
    // 0x242: 4D99 -> SNE VD, 0x99 (VD=0x0E != 0x99 -> skip taken, skips 0x244)
    load_instruction(12'h242, 16'h4D99);
    // 0x244: 1999 -> Trap (Must be skipped)
    load_instruction(12'h244, 16'h1999);
    // 0x246: 4D0E -> SNE VD, 0x0E (VD=0x0E == 0x0E -> skip not taken, goes to 0x248)
    load_instruction(12'h246, 16'h4D0E);
    // 0x248: 610E -> LD V1, 0x0E
    load_instruction(12'h248, 16'h610E);
    // 0x24A: 51D0 -> SE V1, VD (V1 == VD -> skip taken, skips 0x24C)
    load_instruction(12'h24A, 16'h51D0);
    // 0x24C: 1999 -> Trap (Must be skipped)
    load_instruction(12'h24C, 16'h1999);
    // 0x24E: 51A0 -> SE V1, VA (V1 != VA -> skip not taken, goes to 0x250)
    load_instruction(12'h24E, 16'h51A0);
    // 0x250: 91A0 -> SNE V1, VA (V1 != VA -> skip taken, skips 0x252)
    load_instruction(12'h250, 16'h91A0);
    // 0x252: 1999 -> Trap (Must be skipped)
    load_instruction(12'h252, 16'h1999);
    // 0x254: 91D0 -> SNE V1, VD (V1 == VD -> skip not taken, goes to 0x256)
    load_instruction(12'h254, 16'h91D0);
    // 0x256: C00F -> RND V0, 0x0F
    load_instruction(12'h256, 16'hC00F);
    // 0x258: A500 -> LD I, 0x500
    load_instruction(12'h258, 16'hA500);
    // 0x25A: 6120 -> LD V1, 0x20
    load_instruction(12'h25A, 16'h6120);
    // 0x25C: F11E -> ADD I, V1 (I becomes 0x520)
    load_instruction(12'h25C, 16'hF11E);
    // 0x25E: 6105 -> LD V1, 0x05
    load_instruction(12'h25E, 16'h6105);
    // 0x260: F129 -> LD F, V1 (I becomes 0x0050 + 5*5 = 0x0069)
    load_instruction(12'h260, 16'hF129);
    // 0x262: A700 -> LD I, 0x700
    load_instruction(12'h262, 16'hA700);
    // 0x264: 6011 -> LD V0, 0x11
    load_instruction(12'h264, 16'h6011);
    // 0x266: 6122 -> LD V1, 0x22
    load_instruction(12'h266, 16'h6122);
    // 0x268: 6233 -> LD V2, 0x33
    load_instruction(12'h268, 16'h6233);
    // 0x26A: 6344 -> LD V3, 0x44
    load_instruction(12'h26A, 16'h6344);
    // 0x26C: F355 -> LD [I], V3 (stores V0..V3 to ram[0x700..0x703])
    load_instruction(12'h26C, 16'hF355);
    // 0x26E: 6000 -> LD V0, 0x00
    load_instruction(12'h26E, 16'h6000);
    // 0x270: 6100 -> LD V1, 0x00
    load_instruction(12'h270, 16'h6100);
    // 0x272: 6200 -> LD V2, 0x00
    load_instruction(12'h272, 16'h6200);
    // 0x274: 6300 -> LD V3, 0x00
    load_instruction(12'h274, 16'h6300);
    // 0x276: F365 -> LD V3, [I] (loads ram[0x700..0x703] back into V0..V3)
    load_instruction(12'h276, 16'hF365);
    // 0x278: F407 -> LD V4, DT (read delay timer into V4)
    load_instruction(12'h278, 16'hF407);
    // 0x27A: 6503 -> LD V5, 0x03
    load_instruction(12'h27A, 16'h6503);
    // 0x27C: E59E -> SKP V5 (skip if key 3 is pressed)
    load_instruction(12'h27C, 16'hE59E);
    // 0x27E: 1999 -> Trap (Must be skipped)
    load_instruction(12'h27E, 16'h1999);
    // 0x280: E5A1 -> SKNP V5 (skip if key 3 is NOT pressed)
    load_instruction(12'h280, 16'hE5A1);
    // 0x282: E5A1 -> SKNP V5 (skip if key 3 is NOT pressed)
    load_instruction(12'h282, 16'hE5A1);
    // 0x284: 1999 -> Trap (Must be skipped)
    load_instruction(12'h284, 16'h1999);
    // 0x286: E59E -> SKP V5 (skip if key 3 is pressed)
    load_instruction(12'h286, 16'hE59E);
    // 0x288: F60A -> LD V6, K (wait for keypress)
    load_instruction(12'h288, 16'hF60A);
    // 0x28A: 6004 -> LD V0, 0x04
    load_instruction(12'h28A, 16'h6004);
    // 0x28C: B290 -> JP V0, 0x290 (PC = 0x290 + 0x04 = 0x294)
    load_instruction(12'h28C, 16'hB290);
    // 0x28E: 1999 -> Trap
    load_instruction(12'h28E, 16'h1999);
    // 0x290: 1999 -> Trap
    load_instruction(12'h290, 16'h1999);
    // 0x292: 1999 -> Trap
    load_instruction(12'h292, 16'h1999);
    // 0x294: 1294 -> JP 0x294 (Infinite loop / Halt)
    load_instruction(12'h294, 16'h1294);

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

    // =========================================================================
    // PHASE 2: Verification of remaining opcodes
    // =========================================================================

    // 19. 700A: ADD V0, 0x0A (V0 was 8; 8 + 10 = 18 = 0x12)
    step_cycles(2);
    step_cycles(1); // FETCH of 8600 commits V0 = 0x12
    if (pc_out === 16'h0222 && uut.u_register_file.V[0] === 8'h12) begin
      pass_count = pass_count + 1;
      $display("[PASS] 700A ADD V0, 0x0A: V0=0x%0h, PC=0x%0h", uut.u_register_file.V[0], pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 700A ADD V0, 0x0A: V0=0x%0h (exp 0x12), PC=0x%0h", uut.u_register_file.V[0], pc_out);
    end

    // 20. 8600: LD V6, V0 (V6 = 0x12)
    step_cycles(1); // DECODE_EXEC of 8600
    step_cycles(1); // FETCH of 670F commits V6 = 0x12
    if (pc_out === 16'h0224 && uut.u_register_file.V[6] === 8'h12) begin
      pass_count = pass_count + 1;
      $display("[PASS] 8600 LD V6, V0: V6=0x%0h, PC=0x%0h", uut.u_register_file.V[6], pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 8600 LD V6, V0: V6=0x%0h (exp 0x12), PC=0x%0h", uut.u_register_file.V[6], pc_out);
    end

    // 21. 670F: LD V7, 0x0F
    step_cycles(1); // DECODE_EXEC of 670F

    // 22. 8671: OR V6, V7 (0x12 | 0x0F = 0x1F, VF=0)
    step_cycles(3); // FETCH, EXEC, ALU_VF_WRITE
    step_cycles(1); // FETCH of 6833 commits V6 and VF
    if (pc_out === 16'h0228 && uut.u_register_file.V[6] === 8'h1F && uut.u_register_file.V[15] === 8'h00) begin
      pass_count = pass_count + 1;
      $display("[PASS] 8671 OR V6, V7: V6=0x%0h, VF=0x%0h", uut.u_register_file.V[6], uut.u_register_file.V[15]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 8671 OR V6, V7: V6=0x%0h (exp 0x1F), VF=0x%0h (exp 0)", uut.u_register_file.V[6], uut.u_register_file.V[15]);
    end

    // 23. 6833: LD V8, 0x33
    step_cycles(1); // DECODE_EXEC of 6833

    // 24. 8682: AND V6, V8 (0x1F & 0x33 = 0x13, VF=0)
    step_cycles(3); // FETCH, EXEC, ALU_VF_WRITE
    step_cycles(1); // FETCH of 6955 commits V6 and VF
    if (pc_out === 16'h022C && uut.u_register_file.V[6] === 8'h13 && uut.u_register_file.V[15] === 8'h00) begin
      pass_count = pass_count + 1;
      $display("[PASS] 8682 AND V6, V8: V6=0x%0h, VF=0x%0h", uut.u_register_file.V[6], uut.u_register_file.V[15]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 8682 AND V6, V8: V6=0x%0h (exp 0x13), VF=0x%0h (exp 0)", uut.u_register_file.V[6], uut.u_register_file.V[15]);
    end

    // 25. 6955: LD V9, 0x55
    step_cycles(1); // DECODE_EXEC of 6955

    // 26. 8693: XOR V6, V9 (0x13 ^ 0x55 = 0x46, VF=0)
    step_cycles(3); // FETCH, EXEC, ALU_VF_WRITE
    step_cycles(1); // FETCH of 6A20 commits V6 and VF
    if (pc_out === 16'h0230 && uut.u_register_file.V[6] === 8'h46 && uut.u_register_file.V[15] === 8'h00) begin
      pass_count = pass_count + 1;
      $display("[PASS] 8693 XOR V6, V9: V6=0x%0h, VF=0x%0h", uut.u_register_file.V[6], uut.u_register_file.V[15]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 8693 XOR V6, V9: V6=0x%0h (exp 0x46), VF=0x%0h (exp 0)", uut.u_register_file.V[6], uut.u_register_file.V[15]);
    end

    // 27. 6A20: LD VA, 0x20
    step_cycles(1); // DECODE_EXEC of 6A20
    // 28. 6B10: LD VB, 0x10
    step_cycles(2); // FETCH + DECODE_EXEC of 6B10

    // 29. 8AB5: SUB VA, VB (0x20 - 0x10 = 0x10, VF=1 no borrow)
    step_cycles(3); // FETCH, EXEC, ALU_VF_WRITE
    step_cycles(1); // FETCH of 6C07 commits VA and VF
    if (pc_out === 16'h0236 && uut.u_register_file.V[10] === 8'h10 && uut.u_register_file.V[15] === 8'h01) begin
      pass_count = pass_count + 1;
      $display("[PASS] 8AB5 SUB VA, VB: VA=0x%0h, VF=0x%0h", uut.u_register_file.V[10], uut.u_register_file.V[15]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 8AB5 SUB VA, VB: VA=0x%0h (exp 0x10), VF=0x%0h (exp 1)", uut.u_register_file.V[10], uut.u_register_file.V[15]);
    end

    // 30. 6C07: LD VC, 0x07
    step_cycles(1); // DECODE_EXEC of 6C07

    // 31. 8C06: SHR VC (0x07 >> 1 = 0x03, VF=1 LSB)
    step_cycles(3); // FETCH, EXEC, ALU_VF_WRITE
    step_cycles(1); // FETCH of 6D05 commits VC and VF
    if (pc_out === 16'h023A && uut.u_register_file.V[12] === 8'h03 && uut.u_register_file.V[15] === 8'h01) begin
      pass_count = pass_count + 1;
      $display("[PASS] 8C06 SHR VC: VC=0x%0h, VF=0x%0h", uut.u_register_file.V[12], uut.u_register_file.V[15]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 8C06 SHR VC: VC=0x%0h (exp 0x03), VF=0x%0h (exp 1)", uut.u_register_file.V[12], uut.u_register_file.V[15]);
    end

    // 32. 6D05: LD VD, 0x05
    step_cycles(1); // DECODE_EXEC of 6D05
    // 33. 6E0C: LD VE, 0x0C
    step_cycles(2); // FETCH + DECODE_EXEC of 6E0C

    // 34. 8DE7: SUBN VD, VE (VE - VD = 0x0C - 0x05 = 0x07, VF=1 no borrow)
    step_cycles(3); // FETCH, EXEC, ALU_VF_WRITE
    step_cycles(1); // FETCH of 8DEE commits VD and VF
    if (pc_out === 16'h0240 && uut.u_register_file.V[13] === 8'h07 && uut.u_register_file.V[15] === 8'h01) begin
      pass_count = pass_count + 1;
      $display("[PASS] 8DE7 SUBN VD, VE: VD=0x%0h, VF=0x%0h", uut.u_register_file.V[13], uut.u_register_file.V[15]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 8DE7 SUBN VD, VE: VD=0x%0h (exp 0x07), VF=0x%0h (exp 1)", uut.u_register_file.V[13], uut.u_register_file.V[15]);
    end

    // 35. 8DEE: SHL VD (0x07 << 1 = 0x0E, VF=0 MSB)
    step_cycles(2); // EXEC of 8DEE, ALU_VF_WRITE
    step_cycles(1); // FETCH of 4D99 commits VD and VF
    if (pc_out === 16'h0242 && uut.u_register_file.V[13] === 8'h0E && uut.u_register_file.V[15] === 8'h00) begin
      pass_count = pass_count + 1;
      $display("[PASS] 8DEE SHL VD: VD=0x%0h, VF=0x%0h", uut.u_register_file.V[13], uut.u_register_file.V[15]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 8DEE SHL VD: VD=0x%0h (exp 0x0E), VF=0x%0h (exp 0), PC=0x%0h", uut.u_register_file.V[13], uut.u_register_file.V[15], pc_out);
    end

    // 36. 4D99: SNE VD, 0x99 (VD=0x0E != 0x99 -> skip taken, skips 0x244, lands on 0x246)
    step_cycles(1); // DECODE_EXEC of 4D99
    if (pc_out === 16'h0246) begin
      pass_count = pass_count + 1;
      $display("[PASS] 4D99 SNE taken: PC=0x%0h (skipped 0x0244)", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 4D99 SNE taken: PC=0x%0h (exp 0x0246)", pc_out);
    end

    // 37. 4D0E: SNE VD, 0x0E (VD=0x0E == 0x0E -> skip not taken, lands on 0x248)
    step_cycles(2); // FETCH + DECODE_EXEC of 4D0E
    if (pc_out === 16'h0248) begin
      pass_count = pass_count + 1;
      $display("[PASS] 4D0E SNE not taken: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 4D0E SNE not taken: PC=0x%0h (exp 0x0248)", pc_out);
    end

    // 38. 610E: LD V1, 0x0E
    step_cycles(2);

    // 39. 51D0: SE V1, VD (V1=0x0E == VD=0x0E -> skip taken, skips 0x24C, lands on 0x24E)
    step_cycles(2);
    if (pc_out === 16'h024E) begin
      pass_count = pass_count + 1;
      $display("[PASS] 51D0 SE taken: PC=0x%0h (skipped 0x024C)", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 51D0 SE taken: PC=0x%0h (exp 0x024E)", pc_out);
    end

    // 40. 51A0: SE V1, VA (V1=0x0E != VA=0x10 -> skip not taken, lands on 0x250)
    step_cycles(2);
    if (pc_out === 16'h0250) begin
      pass_count = pass_count + 1;
      $display("[PASS] 51A0 SE not taken: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 51A0 SE not taken: PC=0x%0h (exp 0x0250)", pc_out);
    end

    // 41. 91A0: SNE V1, VA (V1=0x0E != VA=0x10 -> skip taken, skips 0x252, lands on 0x254)
    step_cycles(2);
    if (pc_out === 16'h0254) begin
      pass_count = pass_count + 1;
      $display("[PASS] 91A0 SNE taken: PC=0x%0h (skipped 0x0252)", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 91A0 SNE taken: PC=0x%0h (exp 0x0254)", pc_out);
    end

    // 42. 91D0: SNE V1, VD (V1=0x0E == VD=0x0E -> skip not taken, lands on 0x256)
    step_cycles(2);
    if (pc_out === 16'h0256) begin
      pass_count = pass_count + 1;
      $display("[PASS] 91D0 SNE not taken: PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] 91D0 SNE not taken: PC=0x%0h (exp 0x0256)", pc_out);
    end

    // 43. C00F: RND V0, 0x0F (V0 = rand & 0x0F)
    step_cycles(2); // FETCH + DECODE_EXEC
    step_cycles(1); // FETCH of A500 commits V0
    if (pc_out === 16'h0258 && (uut.u_register_file.V[0] & 8'hF0) === 8'h00) begin
      pass_count = pass_count + 1;
      $display("[PASS] C00F RND V0, 0x0F: V0=0x%0h", uut.u_register_file.V[0]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] C00F RND V0: V0=0x%0h", uut.u_register_file.V[0]);
    end

    // 44. A500: LD I, 0x500
    step_cycles(1); // DECODE_EXEC of A500
    // 45. 6120: LD V1, 0x20
    step_cycles(2);

    // 46. F11E: ADD I, V1 (I becomes 0x500 + 0x20 = 0x520)
    step_cycles(2);
    if (pc_out === 16'h025E && i_out === 16'h0520) begin
      pass_count = pass_count + 1;
      $display("[PASS] F11E ADD I, V1: I=0x%0h", i_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] F11E ADD I, V1: I=0x%0h (exp 0x0520)", i_out);
    end

    // 47. 6105: LD V1, 0x05
    step_cycles(2);

    // 48. F129: LD F, V1 (I becomes 0x0050 + 5*5 = 0x0069)
    step_cycles(2);
    if (pc_out === 16'h0262 && i_out === 16'h0069) begin
      pass_count = pass_count + 1;
      $display("[PASS] F129 LD F, V1: I=0x%0h", i_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] F129 LD F, V1: I=0x%0h (exp 0x0069)", i_out);
    end

    // 49. Set up registers for FX55: I=0x700, V0=0x11, V1=0x22, V2=0x33, V3=0x44
    step_cycles(2); // A700
    step_cycles(2); // 6011
    step_cycles(2); // 6122
    step_cycles(2); // 6233
    step_cycles(2); // 6344

    // 50. F355: Store V0..V3 to RAM at 0x700
    while (pc_out !== 16'h026E) begin
      step_cycles(1);
    end
    if (ram[12'h700] === 8'h11 && ram[12'h701] === 8'h22 &&
        ram[12'h702] === 8'h33 && ram[12'h703] === 8'h44) begin
      pass_count = pass_count + 1;
      $display("[PASS] F355 Store V0..V3: ram[0x700..703] = {%0h, %0h, %0h, %0h}",
               ram[12'h700], ram[12'h701], ram[12'h702], ram[12'h703]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] F355 Store V0..V3: ram[0x700..703] = {%0h, %0h, %0h, %0h}",
               ram[12'h700], ram[12'h701], ram[12'h702], ram[12'h703]);
    end

    // 51. Zero out V0..V3:
    step_cycles(2); // 6000
    step_cycles(2); // 6100
    step_cycles(2); // 6200
    step_cycles(2); // 6300

    // 52. F365: Load V0..V3 from RAM at 0x700
    while (pc_out !== 16'h0278) begin
      step_cycles(1);
    end
    step_cycles(1); // FETCH of F407 commits V3
    if (uut.u_register_file.V[0] === 8'h11 && uut.u_register_file.V[1] === 8'h22 &&
        uut.u_register_file.V[2] === 8'h33 && uut.u_register_file.V[3] === 8'h44) begin
      pass_count = pass_count + 1;
      $display("[PASS] F365 Load V0..V3: V0..V3 = {%0h, %0h, %0h, %0h}",
               uut.u_register_file.V[0], uut.u_register_file.V[1], uut.u_register_file.V[2], uut.u_register_file.V[3]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] F365 Load V0..V3: V0..V3 = {%0h, %0h, %0h, %0h}",
               uut.u_register_file.V[0], uut.u_register_file.V[1], uut.u_register_file.V[2], uut.u_register_file.V[3]);
    end

    // 53. F407: LD V4, DT (read active delay timer into V4)
    step_cycles(1); // DECODE_EXEC of F407
    step_cycles(1); // FETCH of 6503 commits V4
    if (pc_out === 16'h027A && uut.u_register_file.V[4] > 8'h00) begin
      pass_count = pass_count + 1;
      $display("[PASS] F407 LD V4, DT: V4=0x%0h", uut.u_register_file.V[4]);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] F407 LD V4, DT: V4=0x%0h (exp > 0)", uut.u_register_file.V[4]);
    end

    // 54. 6503: LD V5, 0x03 (key index = 3)
    step_cycles(1); // DECODE_EXEC of 6503

    // Assert key 3
    key_state = 16'h0008;

    // 55. E59E: SKP V5 (Key 3 pressed -> skip taken, lands on 0x280)
    step_cycles(2);
    if (pc_out === 16'h0280) begin
      pass_count = pass_count + 1;
      $display("[PASS] E59E SKP taken (key 3 pressed): PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] E59E SKP taken: PC=0x%0h (exp 0x0280)", pc_out);
    end

    // 56. E5A1: SKNP V5 (Key 3 IS pressed -> skip not taken, lands on 0x282)
    step_cycles(2);
    if (pc_out === 16'h0282) begin
      pass_count = pass_count + 1;
      $display("[PASS] E5A1 SKNP not taken (key 3 pressed): PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] E5A1 SKNP not taken: PC=0x%0h (exp 0x0282)", pc_out);
    end

    // Release key 3
    key_state = 16'h0000;

    // 57. E5A1: SKNP V5 (Key 3 NOT pressed -> skip taken, lands on 0x286)
    step_cycles(2);
    if (pc_out === 16'h0286) begin
      pass_count = pass_count + 1;
      $display("[PASS] E5A1 SKNP taken (key 3 released): PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] E5A1 SKNP taken: PC=0x%0h (exp 0x0286)", pc_out);
    end

    // 58. E59E: SKP V5 (Key 3 NOT pressed -> skip not taken, lands on 0x288)
    step_cycles(2);
    if (pc_out === 16'h0288) begin
      pass_count = pass_count + 1;
      $display("[PASS] E59E SKP not taken (key 3 released): PC=0x%0h", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] E59E SKP not taken: PC=0x%0h (exp 0x0288)", pc_out);
    end

    // 59. F60A: LD V6, K (wait for keypress)
    step_cycles(2);
    if (state_out === 3'd5) begin
      pass_count = pass_count + 1;
      $display("[PASS] F60A entered CU_STATE_KEY_WAIT (state=5, PC=0x%0h)", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] F60A state=0x%0d (exp 5)", state_out);
    end

    // Stall in KEY_WAIT
    step_cycles(2);

    // Press key 6 (bit 6 = 1)
    key_state = 16'h0040;
    step_cycles(1);
    key_state = 16'h0000;
    step_cycles(1); // FETCH of 6004 commits V6
    if (pc_out === 16'h028A && uut.u_register_file.V[6] === 8'h06) begin
      pass_count = pass_count + 1;
      $display("[PASS] F60A Key Pressed: V6=0x%0h, PC=0x%0h", uut.u_register_file.V[6], pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] F60A Key Pressed: V6=0x%0h (exp 0x06), PC=0x%0h", uut.u_register_file.V[6], pc_out);
    end

    // 60. 6004: LD V0, 0x04
    step_cycles(1); // DECODE_EXEC of 6004

    // 61. B290: JP V0, 0x290 (PC = 0x290 + 0x04 = 0x294)
    step_cycles(2);
    if (pc_out === 16'h0294) begin
      pass_count = pass_count + 1;
      $display("[PASS] B290 JP V0, 0x290: PC=0x%0h (0x290 + V0)", pc_out);
    end else begin
      fail_count = fail_count + 1;
      $display("[FAIL] B290 JP V0, 0x290: PC=0x%0h (exp 0x0294)", pc_out);
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
