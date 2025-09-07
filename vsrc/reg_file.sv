module reg_file (
    input  logic        clk,
    input  logic        rst,           //reset
    input  logic [4:0]  rs1_addr,      //source register1 address
    input  logic [4:0]  rs2_addr,      //source register2 address
    input  logic [4:0]  rd_addr,       //destination register address
    input  logic [31:0] rd_data,       //data to write to the destination register
    input  logic        rd_wen,        //write enable
    output logic [31:0] rs1_data,      //data from source register1
    output logic [31:0] rs2_data,      //data from source register2
    output logic [31:0] regs_out1,
    output logic [31:0] regs_out2,
    output logic [31:0] regs_out3,
    output logic [31:0] regs_out4 
);
    logic [31:0] regs[31:0]; // 32 registers, 32 bits each

    // Read ports
    assign rs1_data = (rs1_addr == 5'd0) ? 32'b0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'b0 : regs[rs2_addr];
    assign regs_out1 = regs[1];
    assign regs_out2 = regs[2];
    assign regs_out3 = regs[3];
    assign regs_out4 = regs[4];

    // Write port (writes on rising edge)
    always_ff @(posedge clk) begin
        if(rst) begin
            for (int i = 0;i < 32;i++) begin
                regs[i] <= 32'b0; 
            end
        end
        else if (rd_wen && (rd_addr != 5'd0)) begin
            regs[rd_addr] <= rd_data;
        end
    end
endmodule