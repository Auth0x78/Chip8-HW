`timescale 1ns / 1ps
`include "alu_params.vh"

module tb_alu;

  // Inputs to DUT
  reg [3:0] alu_op;
  reg [7:0] Xin;
  reg [7:0] Yin;
  reg [15:0] Rin;

  // Outputs from DUT
  wire [7:0] Z;
  wire [7:0] A;

  // Reference Model Expected Values
  reg [7:0] expected_Z;
  reg [7:0] expected_A;

  // Counters
  integer i;
  integer pass_count = 0;
  integer fail_count = 0;

  // Instantiate Unit Under Test (DUT)
  alu uut (
      .alu_op(alu_op),
      .Xin(Xin),
      .Yin(Yin),
      .Rin(Rin),
      .Z(Z),
      .A(A)
  );

  // Reference model calculation task
  task check_result;
    input [3:0] op;
    input [7:0] x;
    input [7:0] y;
    input [15:0] r;
    begin
      expected_A = 8'h00;
      expected_Z = 8'h00;

      case (op)
        ALU_SHIFT_RIGHT: begin
          expected_Z = x >> 1;
          expected_A[0] = x[0];  // VF = LSB prior to shift
        end
        ALU_SHIFT_LEFT: begin
          expected_Z = x << 1;
          expected_A[0] = x[7];  // VF = MSB prior to shift
        end
        ALU_OR: begin
          expected_Z = x | y;
        end
        ALU_AND: begin
          expected_Z = x & y;
        end
        ALU_XOR: begin
          expected_Z = x ^ y;
        end
        ALU_ADD_XY: begin
          {expected_A[0], expected_Z} = x + y;  // Carry out flag in A[0]
        end
        ALU_SUB_XY: begin
          expected_Z = x - y;
          expected_A[0] = (x >= y) ? 1'b1 : 1'b0;  // VF = 1 if no borrow (x >= y)
        end
        ALU_SUB_YX: begin
          expected_Z = y - x;
          expected_A[0] = (y >= x) ? 1'b1 : 1'b0;  // VF = 1 if no borrow (y >= x)
        end
        ALU_ADD_RX: begin
          // Assuming 16-bit address addition (I + Vx) or 8-bit result return
          {expected_A, expected_Z} = r + {8'h0, x};
        end
        default: begin
          expected_Z = 8'h00;
          expected_A = 8'h00;
        end
      endcase
    end
  endtask

  // Apply one directed vector and compare the DUT against the reference model.
  task run_edge_case;
    input [3:0] op;
    input [7:0] x;
    input [7:0] y;
    input [15:0] r;
    begin
      alu_op = op;
      Xin = x;
      Yin = y;
      Rin = r;
      #5;
      check_result(op, x, y, r);

      if ((Z === expected_Z) && (A[0] === expected_A[0]) &&
          ((op != ALU_ADD_RX) || (A === expected_A))) begin
        pass_count = pass_count + 1;
      end else begin
        fail_count = fail_count + 1;
        $display(
            "[FAIL Edge] OP=4'h%0h | Xin=%h Yin=%h Rin=%h | Expected (Z=%h A=%h) Got (Z=%h A=%h)",
            op, x, y, r, expected_Z, expected_A, Z, A);
      end
    end
  endtask

  // Helper task to select opcode based on index
  task select_opcode;
    input [3:0] index;
    begin
      case (index)
        4'd0: alu_op = ALU_SHIFT_RIGHT;
        4'd1: alu_op = ALU_SHIFT_LEFT;
        4'd2: alu_op = ALU_OR;
        4'd3: alu_op = ALU_AND;
        4'd4: alu_op = ALU_XOR;
        4'd5: alu_op = ALU_ADD_XY;
        4'd6: alu_op = ALU_SUB_XY;
        4'd7: alu_op = ALU_SUB_YX;
        4'd8: alu_op = ALU_ADD_RX;
        default: alu_op = ALU_OR;
      endcase
    end
  endtask

  // Main Test Stimulus
  initial begin
    // Setup GTKWave VCD dump files
    $dumpfile({`VCD_DIR, "/alu.vcd"});
    $dumpvars(0, tb_alu);

    // Initialize inputs
    alu_op = 0;
    Xin    = 0;
    Yin    = 0;
    Rin    = 0;
    #10;

    $display("==================================================");
    $display("          RUNNING ALU TESTBENCH (9 OPCODES)       ");
    $display("==================================================");

    // Directed Edge-Case Checks
    $display("--- Running Directed Edge Cases (20 vectors) ---");

    // ALU_ADD_RX: boundaries, byte transitions, and 16-bit overflow.
    run_edge_case(ALU_ADD_RX, 8'h00, 8'h00, 16'h0000);
    run_edge_case(ALU_ADD_RX, 8'hFF, 8'h00, 16'h0000);
    run_edge_case(ALU_ADD_RX, 8'h01, 8'h00, 16'h00FF);
    run_edge_case(ALU_ADD_RX, 8'hFF, 8'h00, 16'h0001);
    run_edge_case(ALU_ADD_RX, 8'h00, 8'h00, 16'hFFFF);
    run_edge_case(ALU_ADD_RX, 8'h01, 8'h00, 16'hFFFF);
    run_edge_case(ALU_ADD_RX, 8'hFF, 8'h00, 16'hFF00);
    run_edge_case(ALU_ADD_RX, 8'hFF, 8'h00, 16'h0100);
    run_edge_case(ALU_ADD_RX, 8'h12, 8'h00, 16'hABCD);
    run_edge_case(ALU_ADD_RX, 8'hFF, 8'h00, 16'hFFFF);

    // Other operations: zero/max values, equal operands, carries, and flags.
    run_edge_case(ALU_SHIFT_RIGHT, 8'h01, 8'h00, 16'h0000);
    run_edge_case(ALU_SHIFT_LEFT, 8'h80, 8'h00, 16'h0000);
    run_edge_case(ALU_OR, 8'h00, 8'h00, 16'h0000);
    run_edge_case(ALU_OR, 8'hAA, 8'h55, 16'h0000);
    run_edge_case(ALU_AND, 8'hFF, 8'h0F, 16'h0000);
    run_edge_case(ALU_XOR, 8'hFF, 8'hFF, 16'h0000);
    run_edge_case(ALU_ADD_XY, 8'hFF, 8'h01, 16'h0000);
    run_edge_case(ALU_SUB_XY, 8'h05, 8'h0A, 16'h0000);
    run_edge_case(ALU_SUB_YX, 8'h0A, 8'h05, 16'h0000);
    run_edge_case(4'h0, 8'hFF, 8'hFF, 16'hFFFF);

    // Randomized Test Stream
    $display("--- Running 1000 Random Vector Iterations ---");
    for (i = 0; i < 1000; i = i + 1) begin
      Xin = $urandom_range(0, 255)[7:0];
      Yin = $urandom_range(0, 255)[7:0];
      Rin = $urandom()[15:0];

      select_opcode($urandom_range(0, 8)[3:0]);

      #5;  // Wait for combinational settling

      check_result(alu_op, Xin, Yin, Rin);

      if ((Z === expected_Z) && (A[0] === expected_A[0])) begin
        pass_count = pass_count + 1;
      end else begin
        fail_count = fail_count + 1;
        $display(
            "[FAIL] Iter %0d: OP=4'h%0h | Xin=%0d Yin=%0d Rin=%0d | Expected (Z=%0d A[0]=%0b) Got (Z=%0d A[0]=%0b)",
            i, alu_op, Xin, Yin, Rin, expected_Z, expected_A[0], Z, A[0]);
      end
      #5;
    end

    // Final Output Summary
    $display("==================================================");
    $display("RESULTS: %0d PASSED | %0d FAILED", pass_count, fail_count);
    $display("==================================================");

    if (fail_count == 0) $display(">>> SUCCESS: All ALU tests passed! <<<");
    else $display(">>> ERROR: Output mismatches detected. <<<");

    $finish;
  end

endmodule
