/*
Load Extractor: takes the 32-bit raw word from memory and the byte offset,
then sign- or zero-extends based on funct3 (lb/lh/lw/lbu/lhu).
*/

module LOAD_EXTRACTOR (
    input  [31:0] raw_data,
    input  [1:0]  byte_offset,   // mem_addr[1:0]
    input  [2:0]  funct3,
    output reg [31:0] load_data
);

    wire [7:0]  byte_sel  = raw_data >> {byte_offset, 3'b0};
    wire [15:0] half_sel  = raw_data >> {byte_offset[1], 4'b0};

    always @(*) begin
        case (funct3)
            3'h0: load_data = {{24{byte_sel[7]}},  byte_sel};       // LB
            3'h1: load_data = {{16{half_sel[15]}}, half_sel};       // LH
            3'h2: load_data = raw_data;                             // LW
            3'h4: load_data = {24'b0, byte_sel};                   // LBU
            3'h5: load_data = {16'b0, half_sel};                   // LHU
            default: load_data = 32'hx;
        endcase
    end

endmodule
