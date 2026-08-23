module ALU (
    input wire [3:0] alu_op,
    input wire [7:0] Xin,
    input wire [7:0] Yin,
    input wire [15:0] I,

    output reg [7:0] Z,
    output reg [7:0] A
);

always @(*) begin
    // Default assignments to prevent unintended latches
    A = 8'h00;
    Z = 8'h00;

    case (alu_op)
        4'b0000: begin 
            A[0] = Xin[0];     // VF = shifted out LSB (CHIP-8 SHR)
            Z = Xin >> 1; 
        end
        4'b0001: begin
            A[0] = Xin[7];     // VF = shifted out MSB (CHIP-8 SHL)
            Z = Xin << 1; 
        end
        4'b0010: Z = Xin | Yin; // OR
        4'b0011: Z = Xin & Yin; // AND
        4'b0100: Z = Xin ^ Yin; // XOR
        4'b0101: begin
            {A[0], Z} = {1'b0, Xin} + {1'b0, Yin}; // Add with carry bit in A[0]
        end
        4'b0110, 4'b0111: begin
            // Subtract with borrow (SUB / SUBN)
            {A[0], Z} = alu_op[0] ? ({1'b0, Yin} - {1'b0, Xin}) 
                                   : ({1'b0, Xin} - {1'b0, Yin});
        end
        4'b1000: begin 
            {A, Z} = I + {8'b0, Xin}; // Zero-extend Xin to match 16-bit I
        end
        default: begin 
            Z = 8'h00;
            A = 8'h00;
        end
    endcase
end

endmodule