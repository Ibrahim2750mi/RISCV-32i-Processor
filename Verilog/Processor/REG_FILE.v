/*
Register File: 32 registers × 32 bits.
*/

module REG_FILE (
    input  [4:0]  read_reg_num1,
    input  [4:0]  read_reg_num2,
    input  [4:0]  write_reg,
    input  [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2,
    input         regwrite,
    input         clock,
    input         reset
);

    reg [31:0] reg_memory [31:0];
    integer i;

    always @(posedge reset) begin
        for (i = 0; i < 32; i = i + 1)
            reg_memory[i] = 32'h0;
    end

    assign read_data1 = reg_memory[read_reg_num1];
    assign read_data2 = reg_memory[read_reg_num2];

    always @(posedge clock) begin
        if (regwrite && write_reg != 5'd0)
            reg_memory[write_reg] <= write_data;
    end

endmodule
