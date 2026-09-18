`timescale 1ns / 1ps

module decoder (
    // Input to decoder module
    input wire [15:0] instr,

    // Video commands
    // CLS (00E0)
    output wire video_cmd_clear,
    // DRW Vx, Vy, nibble (Dxyn)
    output wire video_cmd_draw,

    // Keyboard driver commands
    // SKP Vx (Ex9E) 
    output wire ky_skip_xkey_press,
    // SKNP Vx (ExA1) 
    output wire ky_skip_xkey_notpress,

    // Branch operations
    // Return from caller
    output wire br_ret,
    // Jump (1nnn) to 'nnn'
    output wire br_jump,
    // Jump with offset in V0 (Bnnn)
    output wire br_jump_v0_offset,
    // Call (2nnn) addr
    output wire br_call,
    // SE Vx, byte (3xkk)
    output wire br_skip_eq_imm,
    // SNE Vx, byte (4xkk)
    output wire br_skip_neq_imm,
    // SE Vx, Vy (5xy0)
    output wire br_skip_eq_reg,
    // SNE Vx, Vy (9xy0)
    output wire br_skip_neq_reg,

    // Load operations
    // LD Vx, byte (6xkk)
    output wire load_x_imm,
    // LD Vx, Vy (8xy0)
    output wire load_x_from_y,
    // LD I, addr (Annn)
    output wire load_index_imm,
    // LD Vx, DT (Fx07): Set Vx = DT
    output wire load_vx_dt,
    // LD Vx, K (Fx0A): Load Vx = Key Pressed Value
    output wire load_vx_key,
    // LD DT, Vx (Fx15): Set DT = Vx
    output wire load_dt_vx,
    // LD ST, Vx (Fx18)
    output wire load_st_vx,
    // LD F, VX  (Fx29) : Set I = location of sprite for digit Vx.
    output wire load_i_font,

    // Store operation
    // LD B, Vx (Fx33) : Store BCD representation of Vx in memory locations I, I+1, and I+2.
    output wire store_bcd_of_x,
    // LD [I], Vx  (Fx55)     : Store registers V0 -> Vx in memory starting at location I.
    output wire store_V_reg,

    // Read operation
    // LD Vx, [I]  (Fx65)     : Read registers V0 through Vx from memory starting at location I.
    output wire read_vx_mem_i,

    // ALU operations
    // ADD Vx, byte (7xKK) 
    output wire alu_x_imm_add,
    // RND Vx(rand), imm (Cxkk) : Set Vx = (random byte) AND 'kk'.
    output wire alu_and_rand_imm,
    // OR Vx, Vy      (8xy1)
    // AND Vx, Vy     (8xy2)
    // XOR Vx, Vy     (8xy3)
    // ADD Vx, Vy     (8xy4)
    // SUB Vx, Vy     (8xy5)
    // SHR Vx {, Vy}  (8xy6)
    // SUBN Vx, Vy    (8xy7)
    // SHL Vx {, Vy}  (8xyE)
    output wire alu_xy_op,
    // ADD I, Vx      (Fx1E)    : Add I with Vx & store in I
    output wire alu_add_i_x,

    // Other control outputs
    output wire [ 3:0] alu_op,
    output wire [ 3:0] reg_x_addr,
    output wire [ 3:0] reg_y_addr,
    output wire [ 7:0] imm_data,
    output wire [11:0] imm_addr
);

  `include "alu_params.vh"

  // Internal routing wire
  wire [3:0] nibble3;

  assign nibble3 = instr[15:12];

  assign video_cmd_clear       = (instr == 16'h00E0);
  assign video_cmd_draw        = (nibble3 == 4'hD);

  assign ky_skip_xkey_press    = (nibble3 == 4'hE) && (instr[7:0] == 8'h9E);
  assign ky_skip_xkey_notpress = (nibble3 == 4'hE) && (instr[7:0] == 8'hA1);

  assign br_ret                = (instr == 16'h00EE);
  assign br_jump               = (nibble3 == 4'h1);
  assign br_call               = (nibble3 == 4'h2);
  assign br_skip_eq_imm        = (nibble3 == 4'h3);
  assign br_skip_neq_imm       = (nibble3 == 4'h4);
  assign br_skip_eq_reg        = (nibble3 == 4'h5) && (instr[3:0] == 4'h0);
  assign br_skip_neq_reg       = (nibble3 == 4'h9) && (instr[3:0] == 4'h0);
  assign br_jump_v0_offset     = (nibble3 == 4'hB);

  assign load_x_imm            = (nibble3 == 4'h6);
  assign load_x_from_y         = (nibble3 == 4'h8) && (instr[3:0] == 4'h0);
  assign load_index_imm        = (nibble3 == 4'hA);
  assign load_vx_dt            = (nibble3 == 4'hF) && (instr[7:0] == 8'h07);
  assign load_vx_key           = (nibble3 == 4'hF) && (instr[7:0] == 8'h0A);
  assign load_dt_vx            = (nibble3 == 4'hF) && (instr[7:0] == 8'h15);
  assign load_st_vx            = (nibble3 == 4'hF) && (instr[7:0] == 8'h18);
  assign load_i_font           = (nibble3 == 4'hF) && (instr[7:0] == 8'h29);

  assign store_bcd_of_x        = (nibble3 == 4'hF) && (instr[7:0] == 8'h33);
  assign store_V_reg           = (nibble3 == 4'hF) && (instr[7:0] == 8'h55);

  assign read_vx_mem_i         = (nibble3 == 4'hF) && (instr[7:0] == 8'h65);

  assign alu_x_imm_add         = (nibble3 == 4'h7);
  assign alu_and_rand_imm      = (nibble3 == 4'hC);
  assign alu_xy_op             = (nibble3 == 4'h8) && (((instr[3:0] > 4'h0) && (instr[3:0] < 4'h8)) || (instr[3:0] == 4'hE));
  assign alu_add_i_x           = (nibble3 == 4'hF) && (instr[7:0] == 8'h1E);

  assign reg_x_addr            = instr[11:8];
  assign reg_y_addr            = instr[7:4];
  assign imm_data              = (nibble3 == 4'hD) ? {4'h0, instr[3:0]} : instr[7:0];
  assign imm_addr              = instr[11:0];
  assign alu_op                = alu_xy_op ? instr[3:0] : (alu_add_i_x ? ALU_ADD_RX : 4'h0);

endmodule
