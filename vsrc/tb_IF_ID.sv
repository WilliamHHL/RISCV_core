`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/01 02:29:12
// Design Name: 
// Module Name: tb_IF_ID
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module tb_IF_ID;


    logic clk = 0;
    logic [31:0] pc;

    logic [31:0] instr;

    
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [2:0]  imm_type, funct3;
    logic [6:0]  funct7; 
    logic        reg_write, mem_read, mem_write, branch;
    logic [3:0]  alu_op;
    logic        is_addi, is_sub;

  
    IF u_IF (
        .clk(clk),
        .pc(pc),
        .instr(instr)
    );

 
    ID u_ID (
        .inst      (instr),
        .rs1_addr  (rs1_addr),
        .rs2_addr  (rs2_addr),
        .rd_addr   (rd_addr),
        .imm_type  (imm_type),
        .funct3    (funct3),
        .funct7    (funct7),
        .reg_write (reg_write),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .branch    (branch),
        .alu_op    (alu_op),
        .is_addi   (is_addi),
        .is_sub    (is_sub)
    );

 
    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_IF_ID);
        pc = 32'h8000_0000; 
        #10;

        repeat (5) begin
            @(negedge clk);
            $display("PC=%08x INSTR=%08x | rs1=%0d rs2=%0d rd=%0d imm_type=%0d reg_write=%b mem_read=%b mem_write=%b branch=%b alu_op=%0d is_addi=%b is_sub=%b",
                pc, instr, rs1_addr, rs2_addr, rd_addr, imm_type, reg_write, mem_read, mem_write, branch, alu_op, is_addi, is_sub
            );
            pc = pc + 32'd4; 
        end

        #20 $finish;
    end

endmodule
