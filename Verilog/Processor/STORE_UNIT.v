/*
Store Unit: builds the 32-bit write data and 4-bit byte mask
for SB (funct3=0), SH (funct3=1), SW (funct3=2).
*/

module STORE_UNIT (
    input  [31:0] rs2_data,
    input  [1:0]  byte_offset,   // mem_addr[1:0]
    input  [2:0]  funct3,
    output reg [31:0] store_data,
    output reg [3:0]  store_mask
);

    always @(*) begin
        case (funct3)
            3'h0: begin // SB
                store_data = {4{rs2_data[7:0]}};
                store_mask = 4'b0001 << byte_offset;
            end
            3'h1: begin // SH
                store_data = {2{rs2_data[15:0]}};
                store_mask = (byte_offset[1]) ? 4'b1100 : 4'b0011;
            end
            3'h2: begin // SW
                store_data = rs2_data;
                store_mask = 4'b1111;
            end
            default: begin
                store_data = 32'h0;
                store_mask = 4'b0000;
            end
        endcase
    end

endmodule
