module dual_port_ram (
    // Inputs to double port ram
    input wire write_en,
    input wire high_en,
    input wire [7:0] data_in,
    input wire [11:0] address,

    // Output data lane
    inout wire [15:0] data_out
);

  // Internal wires
  wire [15:0] internal_data;

  // Memory cells of the ram
  reg [7:0] memory[4096];

  assign internal_data = high_en ? {memory[address], memory[address+1]} : {8'hZZ, memory[address]};

  assign data_out = write_en ? 16'hZZZZ : internal_data;

  always_latch begin
    if (write_en) begin
      memory[address] = data_in;
    end
  end

endmodule
