module register_file (
    input wire clk,
    input wire rst,
    
    // Control / Write Signals
    input wire        write_en,
    input wire [3:0]  vx_sel,   // Vx index
    input wire [3:0]  vy_sel,   // Vy index
    input wire [2:0]  write_dst_sel,

    input wire [7:0]  in_data_low,
    input wire [7:0]  in_data_high,
    
    // Register Outputs
    output wire [7:0] Vx,    // Vx
    output wire [7:0] Vy,    // Vy
    
    // Special Registers
    output reg [15:0] I_reg,
    output reg [7:0]  DT_reg,
    output reg [7:0]  ST_reg
);

    `include "register_file_params.vh"    

    reg [7:0] V [0:15];

    // Read Logic (Asynchronous)
    assign Vx = V[vx_sel];
    assign Vy = V[vy_sel];

    // Write Logic (Synchronous)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            integer i;
            // Reset all 16 - General Purpose Registers to 0
            for (i = 0; i < 16; i = i + 1) begin
                V[i] <= 8'h00;
            end

            // Reset all special registers
            I_reg <= 16'h0000;
            DT_reg <= 8'h00;
            ST_reg <= 8'h00;
        end else if(write_en) begin
            case (write_dst_sel)
                RF_WRITE_V:
                    V[vx_sel] <= in_data_low;
                RF_WRITE_I:
                    I_reg <= {in_data_high, in_data_low};
                RF_WRITE_DT:
                    DT_reg <= in_data_low;
                RF_WRITE_ST: 
                    ST_reg <= in_data_low;
            endcase
        end
    end

endmodule