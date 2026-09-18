`ifndef CONTROL_UNIT_PARAMS_VH
`define CONTROL_UNIT_PARAMS_VH

localparam logic [2:0] CU_STATE_FETCH        = 3'h0;
localparam logic [2:0] CU_STATE_DECODE_EXEC  = 3'h1;
localparam logic [2:0] CU_STATE_STORE_BCD    = 3'h2;
localparam logic [2:0] CU_STATE_STORE_REGS   = 3'h3;
localparam logic [2:0] CU_STATE_LOAD_REGS    = 3'h4;
localparam logic [2:0] CU_STATE_KEY_WAIT     = 3'h5;
localparam logic [2:0] CU_STATE_GPU_WAIT     = 3'h6;
localparam logic [2:0] CU_STATE_ALU_VF_WRITE = 3'h7;

// GPU Command Constants
localparam logic [1:0] GPU_CMD_NONE          = 2'b00;
localparam logic [1:0] GPU_CMD_CLEAR         = 2'b01;
localparam logic [1:0] GPU_CMD_DRAW          = 2'b10;

`endif
