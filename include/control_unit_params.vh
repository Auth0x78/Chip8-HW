`ifndef CONTROL_UNIT_PARAMS_VH
`define CONTROL_UNIT_PARAMS_VH

localparam logic [1:0] CU_STATE_FETCH        = 2'h0;
localparam logic [1:0] CU_STATE_DECODE_EXEC  = 2'h1;
localparam logic [1:0] CU_STATE_UNUSED       = 2'h2;

`endif
