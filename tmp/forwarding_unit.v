module forwarding_unit (
    input  [4:0] ex_rs1_addr,
    input  [4:0] ex_rs2_addr,
    
    // EX/MEM stage
    input        exmem_reg_write,
    input        exmem_mem_read,
    input        exmem_csr_hit,         // NEW
    input  [4:0] exmem_rd,
    
    // MEM2 stage
    input        mem2_reg_write,
    input        mem2_csr_hit,          // NEW
    input  [4:0] mem2_rd,
    
    // MEM/WB stage
    input        memwb_reg_write,       // Should be wb_wen_final from top
    input  [4:0] memwb_rd,
    
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

    // For CSR and loads, we can't forward from EX/MEM or MEM2 (data not ready)
    // Only WB forwarding works for CSR
    
    always @(*) begin
        forward_a = 2'b00;
        
        // MEM/WB forwarding (includes CSR via wb_wen_final)
        if (memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == ex_rs1_addr))
            forward_a = 2'b01;
        
        // MEM2 forwarding - but NOT for CSR (value not ready)
        if (mem2_reg_write && !mem2_csr_hit && (mem2_rd != 5'd0) && (mem2_rd == ex_rs1_addr))
            forward_a = 2'b11;
            
        // EX/MEM forwarding - NOT for loads or CSR
        if (exmem_reg_write && !exmem_mem_read && !exmem_csr_hit && 
            (exmem_rd != 5'd0) && (exmem_rd == ex_rs1_addr))
            forward_a = 2'b10;
    end
    
    always @(*) begin
        forward_b = 2'b00;
        
        if (memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == ex_rs2_addr))
            forward_b = 2'b01;
            
        if (mem2_reg_write && !mem2_csr_hit && (mem2_rd != 5'd0) && (mem2_rd == ex_rs2_addr))
            forward_b = 2'b11;
            
        if (exmem_reg_write && !exmem_mem_read && !exmem_csr_hit && 
            (exmem_rd != 5'd0) && (exmem_rd == ex_rs2_addr))
            forward_b = 2'b10;
    end

endmodule