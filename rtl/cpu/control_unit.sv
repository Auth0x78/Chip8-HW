`timescale 1ns / 1ps
`include "control_unit_params.vh"
`include "register_file_params.vh"
`include "alu_params.vh"

module control_unit #(
    parameter [15:0] RESET_PC_ADDR  = 16'h0200,
    parameter [15:0] FONT_BASE_ADDR = 16'h0050
) (
    // Clock and rst
    input wire clk,
    input wire rst,

    // Memory Interface
    input  wire [15:0] in_data,
    output reg  [15:0] mem_addr,
    output reg  [ 7:0] out_mem_data,
    output reg         mem_write_en,
    output reg         mem_req,

    // Register File Interface
    output reg         rf_write_en,
    output reg  [ 4:0] rf_addr_a,
    output reg  [ 3:0] rf_rd_addr_reg_y,
    output reg  [ 2:0] rf_write_dst_sel,
    output reg  [ 7:0] rf_in_data_low,
    output reg  [ 7:0] rf_in_data_high,
    input  wire [15:0] rf_data_bus,
    input  wire [15:0] rf_i_reg,
    input  wire [ 7:0] rf_dt_reg,

    // ALU Interface
    output reg  [ 3:0] alu_op_out,
    output reg  [ 7:0] alu_xin,
    output reg  [ 7:0] alu_yin,
    output reg  [15:0] alu_rin,
    input  wire [ 7:0] alu_result,
    input  wire [ 7:0] alu_vf,

    // Timer Interface
    output reg         dt_write_en,
    output reg  [ 7:0] dt_write_val,
    output reg         st_write_en,
    output reg  [ 7:0] st_write_val,

    // Random Number Input (LFSR)
    input  wire [ 7:0] rand_data,

    // Keypad Interface
    input  wire [15:0] key_state,

    // GPU Command Interface
    input  wire        gpu_cmd_ready,
    output reg         gpu_cmd_valid,
    output reg  [ 1:0] gpu_cmd_type,
    output reg  [ 7:0] gpu_cmd_x,
    output reg  [ 7:0] gpu_cmd_y,
    output reg  [ 3:0] gpu_cmd_height,
    output reg  [11:0] gpu_cmd_index,

    // Internal State Monitors
    output wire [15:0] pc_monitor,
    output wire [ 7:0] sp_monitor,
    output wire [ 2:0] state_monitor
);

  // Control Unit Internal Registers
  reg [15:0] pc;
  reg [ 7:0] sp;
  reg [15:0] instr_reg;
  reg [ 2:0] state;

  // Multi-cycle sub-sequence registers
  reg [ 3:0] sub_cnt;
  reg [ 7:0] bcd_h;
  reg [ 7:0] bcd_t;
  reg [ 7:0] bcd_o;
  reg        vf_pending;
  reg        vf_writing;
  reg [15:0] internal_mem_addr;
  reg [ 7:0] internal_out_mem_data;
  reg [ 7:0] internal_rf_in_data_low;

  // Status Monitors
  assign pc_monitor    = pc;
  assign sp_monitor    = sp;
  assign state_monitor = state;

  // Decoder Wires
  wire        video_cmd_clear;
  wire        video_cmd_draw;
  wire        ky_skip_xkey_press;
  wire        ky_skip_xkey_notpress;
  wire        br_ret;
  wire        br_jump;
  wire        br_jump_v0_offset;
  wire        br_call;
  wire        br_skip_eq_imm;
  wire        br_skip_neq_imm;
  wire        br_skip_eq_reg;
  wire        br_skip_neq_reg;
  wire        load_x_imm;
  wire        load_x_from_y;
  wire        load_index_imm;
  wire        load_vx_dt;
  wire        load_vx_key;
  wire        load_dt_vx;
  wire        load_st_vx;
  wire        load_i_font;
  wire        store_bcd_of_x;
  wire        store_V_reg;
  wire        read_vx_mem_i;
  wire        alu_x_imm_add;
  wire        alu_and_rand_imm;
  wire        alu_xy_op;
  wire        alu_add_i_x;
  wire [ 3:0] dec_alu_op;
  wire [ 3:0] reg_x_addr;
  wire [ 3:0] reg_y_addr;
  wire [ 7:0] imm_data;
  wire [11:0] imm_addr;

  decoder u_decoder (
      .instr                (instr_reg),
      .video_cmd_clear      (video_cmd_clear),
      .video_cmd_draw       (video_cmd_draw),
      .ky_skip_xkey_press   (ky_skip_xkey_press),
      .ky_skip_xkey_notpress(ky_skip_xkey_notpress),
      .br_ret               (br_ret),
      .br_jump              (br_jump),
      .br_jump_v0_offset    (br_jump_v0_offset),
      .br_call              (br_call),
      .br_skip_eq_imm       (br_skip_eq_imm),
      .br_skip_neq_imm      (br_skip_neq_imm),
      .br_skip_eq_reg       (br_skip_eq_reg),
      .br_skip_neq_reg      (br_skip_neq_reg),
      .load_x_imm           (load_x_imm),
      .load_x_from_y        (load_x_from_y),
      .load_index_imm       (load_index_imm),
      .load_vx_dt           (load_vx_dt),
      .load_vx_key          (load_vx_key),
      .load_dt_vx           (load_dt_vx),
      .load_st_vx           (load_st_vx),
      .load_i_font          (load_i_font),
      .store_bcd_of_x       (store_bcd_of_x),
      .store_V_reg          (store_V_reg),
      .read_vx_mem_i        (read_vx_mem_i),
      .alu_x_imm_add        (alu_x_imm_add),
      .alu_and_rand_imm     (alu_and_rand_imm),
      .alu_xy_op            (alu_xy_op),
      .alu_add_i_x          (alu_add_i_x),
      .alu_op               (dec_alu_op),
      .reg_x_addr           (reg_x_addr),
      .reg_y_addr           (reg_y_addr),
      .imm_data             (imm_data),
      .imm_addr             (imm_addr)
  );

  // Key Priority Encoder for Fx0A
  logic [3:0] pressed_key_id;
  logic       any_key_pressed;

  always_comb begin
    any_key_pressed = (key_state != 16'h0000);
    pressed_key_id  = 4'h0;
    if (key_state[0])  pressed_key_id = 4'h0;
    else if (key_state[1])  pressed_key_id = 4'h1;
    else if (key_state[2])  pressed_key_id = 4'h2;
    else if (key_state[3])  pressed_key_id = 4'h3;
    else if (key_state[4])  pressed_key_id = 4'h4;
    else if (key_state[5])  pressed_key_id = 4'h5;
    else if (key_state[6])  pressed_key_id = 4'h6;
    else if (key_state[7])  pressed_key_id = 4'h7;
    else if (key_state[8])  pressed_key_id = 4'h8;
    else if (key_state[9])  pressed_key_id = 4'h9;
    else if (key_state[10]) pressed_key_id = 4'hA;
    else if (key_state[11]) pressed_key_id = 4'hB;
    else if (key_state[12]) pressed_key_id = 4'hC;
    else if (key_state[13]) pressed_key_id = 4'hD;
    else if (key_state[14]) pressed_key_id = 4'hE;
    else if (key_state[15]) pressed_key_id = 4'hF;
  end

  // Register File & ALU Read Address Routing (Combinational)
  wire [ 7:0] vx_val;
  wire [ 7:0] vy_val;
  wire [15:0] stack_top_val;

  // Intermediate arithmetic wires for safe part-select slicing
  wire [ 7:0] sp_minus_1;
  wire [15:0] pc_plus_2;
  wire [15:0] i_plus_vx;
  wire [15:0] font_addr_calc;

  assign sp_minus_1     = sp - 8'd1;
  assign pc_plus_2      = pc + 16'd2;
  assign i_plus_vx      = rf_i_reg + {8'h0, vx_val};
  assign font_addr_calc = FONT_BASE_ADDR + ({12'h0, vx_val[3:0]} * 16'd5);

  assign vx_val        = rf_data_bus[15:8];
  assign vy_val        = rf_data_bus[7:0];
  assign stack_top_val = rf_data_bus;

  // Combinational routing to Register File, ALU, and GPU
  always_comb begin
    // Defaults for ALU and RF Read
    rf_rd_addr_reg_y = reg_y_addr;
    alu_op_out       = dec_alu_op;
    alu_xin          = vx_val;
    alu_yin          = vy_val;
    alu_rin          = rf_i_reg;

    // Register File address routing
    if (rf_write_dst_sel == RF_WRITE_STACK) begin
      rf_addr_a = {1'b1, sp_minus_1[3:0]};
    end else if (state == CU_STATE_DECODE_EXEC && br_ret) begin
      rf_addr_a = {1'b1, sp_minus_1[3:0]};
    end else if (state == CU_STATE_DECODE_EXEC && br_jump_v0_offset) begin
      rf_addr_a = 5'h00;
    end else if (state == CU_STATE_FETCH && vf_writing) begin
      rf_addr_a = 5'h0F;
    end else if (state == CU_STATE_STORE_REGS || state == CU_STATE_LOAD_REGS) begin
      rf_addr_a = {1'b0, sub_cnt};
    end else begin
      rf_addr_a = {1'b0, reg_x_addr};
    end

    // GPU Command routing
    gpu_cmd_valid  = 1'b0;
    gpu_cmd_type   = GPU_CMD_NONE;
    gpu_cmd_x      = vx_val;
    gpu_cmd_y      = vy_val;
    gpu_cmd_height = imm_data[3:0];
    gpu_cmd_index  = rf_i_reg[11:0];

    if (state == CU_STATE_DECODE_EXEC || state == CU_STATE_GPU_WAIT) begin
      if (video_cmd_clear) begin
        gpu_cmd_valid = 1'b1;
        gpu_cmd_type  = GPU_CMD_CLEAR;
      end else if (video_cmd_draw) begin
        gpu_cmd_valid = 1'b1;
        gpu_cmd_type  = GPU_CMD_DRAW;
      end
    end

    // Memory data routing
    if (state == CU_STATE_STORE_REGS) begin
      out_mem_data = vx_val;
    end else begin
      out_mem_data = internal_out_mem_data;
    end

    // RF input data routing
    if (state == CU_STATE_LOAD_REGS) begin
      rf_in_data_low = in_data[15:8];
    end else begin
      rf_in_data_low = internal_rf_in_data_low;
    end

    // Memory address routing
    if (state == CU_STATE_STORE_REGS || state == CU_STATE_LOAD_REGS) begin
      mem_addr = rf_i_reg + {12'h0, sub_cnt};
    end else if (mem_write_en) begin
      mem_addr = internal_mem_addr;
    end else begin
      mem_addr = pc;
    end
  end

  // Synchronous State Machine
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state            <= CU_STATE_FETCH;
      pc               <= RESET_PC_ADDR;
      sp               <= 8'h00;
      instr_reg        <= 16'h0000;
      sub_cnt          <= 4'd0;
      bcd_h            <= 8'h00;
      bcd_t            <= 8'h00;
      bcd_o            <= 8'h00;
      vf_pending       <= 1'b0;

      internal_mem_addr     <= 16'h0000;
      internal_out_mem_data <= 8'h00;
      mem_write_en          <= 1'b0;
      mem_req               <= 1'b0;

      rf_write_en           <= 1'b0;
      rf_write_dst_sel      <= RF_WRITE_V;
      internal_rf_in_data_low <= 8'h00;
      rf_in_data_high       <= 8'h00;

      dt_write_en      <= 1'b0;
      dt_write_val     <= 8'h00;
      st_write_en      <= 1'b0;
      st_write_val     <= 8'h00;
      vf_writing       <= 1'b0;
    end else begin
      // Deassert single-cycle strobes by default
      mem_write_en  <= 1'b0;
      mem_req       <= 1'b0;
      rf_write_en   <= 1'b0;
      dt_write_en   <= 1'b0;
      st_write_en   <= 1'b0;

      case (state)
        // ---------------------------------------------------------------------
        // FETCH: Issue PC address and capture 16-bit instruction
        // ---------------------------------------------------------------------
        CU_STATE_FETCH: begin
          mem_req    <= 1'b1;
          instr_reg  <= in_data;
          vf_writing <= 1'b0;
          state      <= CU_STATE_DECODE_EXEC;
        end

        // ---------------------------------------------------------------------
        // DECODE & EXECUTE: Single-cycle instructions and multi-cycle dispatch
        // ---------------------------------------------------------------------
        CU_STATE_DECODE_EXEC: begin
          // 1. Return from Subroutine (00EE)
          if (br_ret) begin
            sp    <= sp - 8'd1;
            pc    <= stack_top_val;
            state <= CU_STATE_FETCH;
          end

          // 2. Clear Display (00E0)
          else if (video_cmd_clear) begin
            if (gpu_cmd_ready) begin
              pc    <= pc + 16'd2;
              state <= CU_STATE_FETCH;
            end else begin
              state <= CU_STATE_GPU_WAIT;
            end
          end

          // 3. Jump to NNN (1nnn)
          else if (br_jump) begin
            pc    <= {4'h0, imm_addr};
            state <= CU_STATE_FETCH;
          end

          // 4. Call Subroutine (2nnn)
          else if (br_call) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_STACK;
            rf_in_data_high  <= pc_plus_2[15:8];
            internal_rf_in_data_low <= pc_plus_2[7:0];
            sp               <= sp + 8'd1;
            pc               <= {4'h0, imm_addr};
            state            <= CU_STATE_FETCH;
          end

          // 5. Skip if Vx == NN (3xkk)
          else if (br_skip_eq_imm) begin
            pc    <= (vx_val == imm_data) ? (pc + 16'd4) : (pc + 16'd2);
            state <= CU_STATE_FETCH;
          end

          // 6. Skip if Vx != NN (4xkk)
          else if (br_skip_neq_imm) begin
            pc    <= (vx_val != imm_data) ? (pc + 16'd4) : (pc + 16'd2);
            state <= CU_STATE_FETCH;
          end

          // 7. Skip if Vx == Vy (5xy0)
          else if (br_skip_eq_reg) begin
            pc    <= (vx_val == vy_val) ? (pc + 16'd4) : (pc + 16'd2);
            state <= CU_STATE_FETCH;
          end

          // 8. Load Vx = NN (6xkk)
          else if (load_x_imm) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_V;
            internal_rf_in_data_low <= imm_data;
            pc               <= pc + 16'd2;
            state            <= CU_STATE_FETCH;
          end

          // 9. Add Vx = Vx + NN (7xkk)
          else if (alu_x_imm_add) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_V;
            internal_rf_in_data_low <= vx_val + imm_data;
            pc               <= pc + 16'd2;
            state            <= CU_STATE_FETCH;
          end

          // 10. Load Vx = Vy (8xy0)
          else if (load_x_from_y) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_V;
            internal_rf_in_data_low <= vy_val;
            pc               <= pc + 16'd2;
            state            <= CU_STATE_FETCH;
          end

          // 11. ALU Register Operations (8xy1 - 8xy7, 8xyE)
          else if (alu_xy_op) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_V;
            internal_rf_in_data_low <= alu_result;

            if (reg_x_addr != 4'hF) begin
              vf_pending <= alu_vf[0];
              state      <= CU_STATE_ALU_VF_WRITE;
            end else begin
              pc    <= pc + 16'd2;
              state <= CU_STATE_FETCH;
            end
          end

          // 12. Skip if Vx != Vy (9xy0)
          else if (br_skip_neq_reg) begin
            pc    <= (vx_val != vy_val) ? (pc + 16'd4) : (pc + 16'd2);
            state <= CU_STATE_FETCH;
          end

          // 13. Load I = NNN (Annn)
          else if (load_index_imm) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_I;
            rf_in_data_high  <= {4'h0, imm_addr[11:8]};
            internal_rf_in_data_low <= imm_addr[7:0];
            pc               <= pc + 16'd2;
            state            <= CU_STATE_FETCH;
          end

          // 14. Jump with V0 offset (Bnnn)
          else if (br_jump_v0_offset) begin
            pc    <= {4'h0, imm_addr} + {8'h0, vx_val};
            state <= CU_STATE_FETCH;
          end

          // 15. Random AND Immediate (Cxkk)
          else if (alu_and_rand_imm) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_V;
            internal_rf_in_data_low <= rand_data & imm_data;
            pc               <= pc + 16'd2;
            state            <= CU_STATE_FETCH;
          end

          // 16. Draw Sprite (Dxyn)
          else if (video_cmd_draw) begin
            if (gpu_cmd_ready) begin
              pc    <= pc + 16'd2;
              state <= CU_STATE_FETCH;
            end else begin
              state <= CU_STATE_GPU_WAIT;
            end
          end

          // 17. Skip if Key Vx is Pressed (Ex9E)
          else if (ky_skip_xkey_press) begin
            pc    <= key_state[vx_val[3:0]] ? (pc + 16'd4) : (pc + 16'd2);
            state <= CU_STATE_FETCH;
          end

          // 18. Skip if Key Vx is Not Pressed (ExA1)
          else if (ky_skip_xkey_notpress) begin
            pc    <= (!key_state[vx_val[3:0]]) ? (pc + 16'd4) : (pc + 16'd2);
            state <= CU_STATE_FETCH;
          end

          // 19. Load Vx = DT (Fx07)
          else if (load_vx_dt) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_V;
            internal_rf_in_data_low <= rf_dt_reg;
            pc               <= pc + 16'd2;
            state            <= CU_STATE_FETCH;
          end

          // 20. Wait for Key Press (Fx0A)
          else if (load_vx_key) begin
            if (any_key_pressed) begin
              rf_write_en      <= 1'b1;
              rf_write_dst_sel <= RF_WRITE_V;
              internal_rf_in_data_low <= {4'h0, pressed_key_id};
              pc               <= pc + 16'd2;
              state            <= CU_STATE_FETCH;
            end else begin
              state <= CU_STATE_KEY_WAIT;
            end
          end

          // 21. Set DT = Vx (Fx15)
          else if (load_dt_vx) begin
            dt_write_en  <= 1'b1;
            dt_write_val <= vx_val;
            pc           <= pc + 16'd2;
            state        <= CU_STATE_FETCH;
          end

          // 22. Set ST = Vx (Fx18)
          else if (load_st_vx) begin
            st_write_en  <= 1'b1;
            st_write_val <= vx_val;
            pc           <= pc + 16'd2;
            state        <= CU_STATE_FETCH;
          end

          // 23. Add I = I + Vx (Fx1E)
          else if (alu_add_i_x) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_I;
            rf_in_data_high  <= i_plus_vx[15:8];
            internal_rf_in_data_low <= i_plus_vx[7:0];
            pc               <= pc + 16'd2;
            state            <= CU_STATE_FETCH;
          end

          // 24. Set I = Font sprite location for Vx (Fx29)
          else if (load_i_font) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_I;
            rf_in_data_high  <= font_addr_calc[15:8];
            internal_rf_in_data_low <= font_addr_calc[7:0];
            pc               <= pc + 16'd2;
            state            <= CU_STATE_FETCH;
          end

          // 25. Store BCD of Vx (Fx33)
          else if (store_bcd_of_x) begin
            bcd_h   <= vx_val / 8'd100;
            bcd_t   <= (vx_val / 8'd10) % 8'd10;
            bcd_o   <= vx_val % 8'd10;
            sub_cnt <= 4'd0;
            state   <= CU_STATE_STORE_BCD;
          end

          // 26. Store V0..Vx to memory at I (Fx55)
          else if (store_V_reg) begin
            mem_req      <= 1'b1;
            mem_write_en <= 1'b1;
            sub_cnt      <= 4'd0;
            state        <= CU_STATE_STORE_REGS;
          end

          // 27. Read V0..Vx from memory at I (Fx65)
          else if (read_vx_mem_i) begin
            mem_req          <= 1'b1;
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_V;
            sub_cnt          <= 4'd0;
            state            <= CU_STATE_LOAD_REGS;
          end

          // Default / Unknown opcode: advance PC
          else begin
            pc    <= pc + 16'd2;
            state <= CU_STATE_FETCH;
          end
        end

        // ---------------------------------------------------------------------
        // ALU VF WRITEBACK: Second cycle to write VF flag
        // ---------------------------------------------------------------------
        CU_STATE_ALU_VF_WRITE: begin
          rf_write_en      <= 1'b1;
          rf_write_dst_sel <= RF_WRITE_V;
          internal_rf_in_data_low <= {7'h0, vf_pending};
          vf_writing       <= 1'b1;
          pc               <= pc + 16'd2;
          state            <= CU_STATE_FETCH;
        end

        // ---------------------------------------------------------------------
        // STORE BCD (Fx33): Multi-cycle write of hundreds, tens, ones
        // ---------------------------------------------------------------------
        CU_STATE_STORE_BCD: begin
          mem_req      <= 1'b1;
          mem_write_en <= 1'b1;
          case (sub_cnt)
            4'd0: begin
              internal_mem_addr     <= rf_i_reg;
              internal_out_mem_data <= bcd_h;
              sub_cnt               <= 4'd1;
            end
            4'd1: begin
              internal_mem_addr     <= rf_i_reg + 16'd1;
              internal_out_mem_data <= bcd_t;
              sub_cnt               <= 4'd2;
            end
            4'd2: begin
              internal_mem_addr     <= rf_i_reg + 16'd2;
              internal_out_mem_data <= bcd_o;
              pc                    <= pc + 16'd2;
              state                 <= CU_STATE_FETCH;
            end
            default: state <= CU_STATE_FETCH;
          endcase
        end

        // ---------------------------------------------------------------------
        // STORE REGS (Fx55): Multi-cycle write of V0..Vx
        // ---------------------------------------------------------------------
        CU_STATE_STORE_REGS: begin
          mem_req      <= 1'b1;
          mem_write_en <= 1'b1;

          if (sub_cnt == reg_x_addr) begin
            pc           <= pc + 16'd2;
            state        <= CU_STATE_FETCH;
            mem_write_en <= 1'b0;
          end else begin
            sub_cnt <= sub_cnt + 4'd1;
          end
        end

        // ---------------------------------------------------------------------
        // LOAD REGS (Fx65): Multi-cycle read of V0..Vx
        // ---------------------------------------------------------------------
        CU_STATE_LOAD_REGS: begin
          mem_req          <= 1'b1;
          rf_write_en      <= 1'b1;
          rf_write_dst_sel <= RF_WRITE_V;

          if (sub_cnt == reg_x_addr) begin
            pc          <= pc + 16'd2;
            state       <= CU_STATE_FETCH;
            rf_write_en <= 1'b0;
          end else begin
            sub_cnt <= sub_cnt + 4'd1;
          end
        end

        // ---------------------------------------------------------------------
        // KEY WAIT (Fx0A): Halt until any key is pressed
        // ---------------------------------------------------------------------
        CU_STATE_KEY_WAIT: begin
          if (any_key_pressed) begin
            rf_write_en      <= 1'b1;
            rf_write_dst_sel <= RF_WRITE_V;
            internal_rf_in_data_low <= {4'h0, pressed_key_id};
            pc               <= pc + 16'd2;
            state            <= CU_STATE_FETCH;
          end
        end

        // ---------------------------------------------------------------------
        // GPU WAIT: Stall if GPU command FIFO is full
        // ---------------------------------------------------------------------
        CU_STATE_GPU_WAIT: begin
          if (gpu_cmd_ready) begin
            pc    <= pc + 16'd2;
            state <= CU_STATE_FETCH;
          end
        end

        default: state <= CU_STATE_FETCH;
      endcase
    end
  end

endmodule
