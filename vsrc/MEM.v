module MEM (
    input        clk,
    input        mem_read,
    input        mem_write,
    input  [31:0] alu_result,
    input  [31:0] rs2_data,
    output reg [31:0] mem_data,
    input        load_signed,     // 1: signed load, 0: unsigned
    input  [1:0] load_size,        // 00: byte, 01: halfword, 10/11: word
    input  [1:0] store_size
);


    localparam [31:0] DMEM_BASE    = 32'h1000_0000;
    localparam [31:0] UART_TX_ADDR = 32'h2000_0000;
    localparam integer DMEM_BYTES  = 131072; // 128 KiB
    
    reg [7:0] dmem [0:DMEM_BYTES-1];
    
    `ifndef SYNTHESIS
    initial begin
        $readmemh("data.hex", dmem);
    end
    `endif
    

    wire [31:0] dmem_addr = alu_result - DMEM_BASE;
    wire [16:0] addr = dmem_addr[16:0];

    `ifndef SYNTHESIS
    always @(*) begin
        if (mem_read || mem_write) begin
            if ((dmem_addr >= DMEM_BYTES) &&
               !(mem_write && (alu_result == UART_TX_ADDR))) begin
                $fatal(1,"DMEM OOR: 0x%08x", alu_result);
            end
            if (dmem_addr < DMEM_BYTES) begin
                if ((mem_read && (load_size == 2'b01)) ||
                    (mem_write && (store_size == 2'b01))) begin
                    if (dmem_addr[0] !== 1'b0) $fatal(1,"Unaligned halfword @0x%08x", alu_result);
                end
                if ((mem_read && load_size[1]) ||
                    (mem_write && (store_size == 2'b10))) begin
                    if (dmem_addr[1:0] !== 2'b00) $fatal(1,"Unaligned word @0x%08x", alu_result);
                end
            end
        end
    end
    `endif




    always @(*) begin
        mem_data = 32'b0;
        if (mem_read) begin
            case (load_size)
                2'b00: begin//LB
                    mem_data = load_signed ?
                        {{24{dmem[addr][7]}}, dmem[addr]} ://Signed value(2's complement)
                        {24'b0, dmem[addr]};//Unsigned Value
                end
                2'b01: begin//LH
                    mem_data = load_signed ?
                        {{16{dmem[addr+1][7]}}, dmem[addr+1], dmem[addr]} :
                        {16'b0, dmem[addr+1], dmem[addr]};
                end
                default: begin//LW
                    mem_data = {dmem[addr+3], dmem[addr+2], dmem[addr+1], dmem[addr]};
                end
            endcase
        end
    end

    always @(posedge clk) begin  // Byte/half/word stores in little-endian order. UART TX at fixed MMIO emits character on write.
        if (mem_write) begin
            `ifndef SYNTHESIS
            if (alu_result == UART_TX_ADDR) begin
                $write("%c", rs2_data[7:0]);
                $fflush();
            end 
            else 
            `endif
            if (dmem_addr < DMEM_BYTES) begin
            case (store_size)
                2'b00: dmem[addr] <= rs2_data[7:0];//SB
                2'b01: begin                       //SH
                    dmem[addr]   <= rs2_data[7:0];
                    dmem[addr+1] <= rs2_data[15:8];
                end
                2'b10:begin                        //SW
                    dmem[addr]   <= rs2_data[7:0];
                    dmem[addr+1] <= rs2_data[15:8];
                    dmem[addr+2] <= rs2_data[23:16];
                    dmem[addr+3] <= rs2_data[31:24];
                end
                default: begin                     //default SW
                    dmem[addr]   <= rs2_data[7:0];
                    dmem[addr+1] <= rs2_data[15:8];
                    dmem[addr+2] <= rs2_data[23:16];
                    dmem[addr+3] <= rs2_data[31:24];
                end
            endcase
        end
        end
    end

endmodule
