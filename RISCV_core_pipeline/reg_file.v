module reg_file (
    input clk,
    input rst,
    input [4:0] rs1_addr,
    input [4:0] rs2_addr,
    input [4:0] rd_addr,
    input [31:0] rd_data,
    input rd_wen,
    output reg[31:0] rs1_data,
    output reg[31:0] rs2_data
   
);
    
    reg [31:0] regs [0:31];

    integer i;

    // Read ports (combinational)
    //assign rs1_data   = (rs1_addr == 5'd0) ? 32'b0 : regs[rs1_addr];
    //assign rs2_data   = (rs2_addr == 5'd0) ? 32'b0 : regs[rs2_addr];
  
    always @(*) begin
    if (rs1_addr == 0) begin
    rs1_data = 0;
        end else if(rd_wen && rs1_addr == rd_addr) begin
            rs1_data = rd_data;
        end else begin
            rs1_data = regs[rs1_addr];
        end
    end

   
    always @(*) begin
    if (rs2_addr == 0) begin
    rs2_data = 0;
        end else if(rd_wen && rs2_addr == rd_addr) begin
            rs2_data = rd_data;
        end else begin
            rs2_data = regs[rs2_addr];
        end
    end
    // Write port (writes on rising edge)

    
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else if (rd_wen && (rd_addr != 5'd0)) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule