module PC_reg(
    input logic clk,
    input logic rstn_sync,
    output logic [31:0] pc,
    input logic [31:0] pc_next
);    
  always_ff @( posedge clk ) begin 
    if(rstn_sync) begin
        pc <= 32'h8000_0000 ; 
    end
    else begin
        pc <= pc_next;
     end
    
  end  
endmodule

