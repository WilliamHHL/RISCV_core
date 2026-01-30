module top (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc,
    output wire [31:0] instr,
    output wire        ebreak_pulse
);
	`ifndef SYNTHESIS
	always @(posedge clk) begin
	    if (!rst && mem_read_eff) begin
	       // $display("LOAD_REQ: pc=%08x instr=%08x rs1=%08x imm=%08x alu_addr=%08x",
		         //pc, instr_r, rs1_data, imm, alu_core_result);
	    end
	end
	`endif
	localparam [31:0] NOP = 32'h0000_0013;

	reg [31:0] pc_if_q;     // PC that was presented to IMEM (aligns with instr_raw a cycle later)
	reg [31:0] pc_exec;     // PC aligned with instr_r (what EX must use)

	reg redirect_hold;      // 1-cycle hold so we don't accidentally latch the wrong instr_raw
	wire redirect_now = branch_taken; // covers BRANCH/JAL/JALR because your EX sets branch_taken=1 for jal/jalr

	// Stall IMEM address latch on load first cycle OR on the redirect edge
	wire if_stall = load_req || redirect_now;
    // IF
    wire [31:0] pc_next;

    // IMEM raw output (sync memory output, changes at negedge)
    wire [31:0] instr_raw;

    // IF/ID register (the instruction actually being decoded/executed)
    reg  [31:0] instr_r;
    assign instr = instr_r;

    // ID
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    wire [2:0] imm_type, funct3;
    wire [6:0] funct7;
    wire       reg_write;
    wire       mem_read, mem_write;
    wire       branch, jal, jalr;
    wire [2:0] branch_op;
    wire [3:0] alu_op;
    wire       alu_rs2_imm;
    wire [1:0] wb_sel;
    wire       use_pc_add;
    wire       load_signed;
    wire [1:0] load_size;
    wire [1:0] store_size;
    wire       ecall, ebreak, fence;

    // Regfile read
    wire [31:0] rs1_data, rs2_data;

    // Immgen
    wire [31:0] imm;

    // EX
    wire [31:0] alu_core_result;
    wire [31:0] pc_plus4;
    wire [31:0] auipc_result;
    wire [31:0] branch_target;
    wire        branch_taken;

    // MEM
    wire [31:0] mem_data;

    // ALU-side candidate
    reg  [31:0] alu_wb_candidate;

    // WB core
    wire [31:0] wb_data_core;

    // Final WB
    wire [31:0] wb_data;
    wire        wb_wen;

    // ---------------------------------------
    // LOAD 插 1 拍 bubble 状态位
    // ---------------------------------------
    reg load_wb;                 // 1: load 的第二拍（写回）
    wire is_load  = mem_read;    // 来自 ID（基于 instr_r）
    wire load_req = is_load && (load_wb == 1'b0); // load 第一拍：发请求 + stall

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            load_wb <= 1'b0;
        end else if (load_wb) begin
            load_wb <= 1'b0;
        end else if (is_load) begin
            load_wb <= 1'b1;
        end
    end

    // PC register
    PC_reg u_PC (
        .clk      (clk),
        .rst_sync (rst),
        .pc       (pc),
        .pc_next  (pc_next)
    );

    // IF (sync imem): load 1st tick stall
    IF u_IF (
        .clk      (clk),
        .rst      (rst),
        .pc       (pc),
        .if_stall (if_stall),
        .instr    (instr_raw)
    );
	always @(posedge clk or posedge rst) begin
	    if (rst) redirect_hold <= 1'b0;
	    else     redirect_hold <= redirect_now;
	end
  
	 always @(posedge clk or posedge rst) begin
	    if (rst) begin
		instr_r      <= NOP;
		pc_if_q      <= 32'd0;
		pc_exec      <= 32'd0;
		// redirect_hold handled in its own always block above
	    end else begin
		// Track fetch PC when IMEM actually latches an address
		if (!if_stall) begin
		    pc_if_q <= pc;
		end

		// IF/ID + aligned PC behavior
		if (load_req) begin
		    // hold instr_r (and pc_exec) during load first cycle
		end else if (redirect_now) begin
		    // flush on taken branch/jump edge
		    instr_r <= NOP;
		end else if (redirect_hold) begin
		    // keep bubble one more cycle so we don't latch the already-fetched fall-through
		    instr_r <= NOP;
		end else begin
		    instr_r <= instr_raw;
		    pc_exec <= pc_if_q;   // align PC with the instruction we just latched
		end
	    end
	end

    // ID（用 instr_r，不用 instr_raw）
    ID u_ID (
        .inst        (instr_r),
        .rs1_addr    (rs1_addr),
        .rs2_addr    (rs2_addr),
        .rd_addr     (rd_addr),
        .imm_type    (imm_type),
        .funct3      (funct3),
        .funct7      (funct7),
        .reg_write   (reg_write),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .branch      (branch),
        .jal         (jal),
        .jalr        (jalr),
        .branch_op   (branch_op),
        .alu_op      (alu_op),
        .alu_rs2_imm (alu_rs2_imm),
        .wb_sel      (wb_sel),
        .use_pc_add  (use_pc_add),
        .load_size   (load_size),
        .load_signed (load_signed),
        .store_size  (store_size),
        .ecall       (ecall),
        .ebreak      (ebreak),
        .fence       (fence)
    );

    // Regfile
    reg_file u_regfile (
        .clk      (clk),
        .rst      (rst),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (wb_data),
        .rd_wen   (wb_wen),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // Immgen（用 instr_r）
    immgen u_immgen (
        .inst     (instr_r),
        .imm_type (imm_type),
        .imm      (imm)
    );

    // EX
    EX u_EX (
        .pc              (pc_exec),
        .rs1_data        (rs1_data),
        .rs2_data        (rs2_data),
        .imm             (imm),
        .alu_op          (alu_op),
        .alu_rs2_imm     (alu_rs2_imm),
        .branch          (branch),
        .branch_op       (branch_op),
        .jal             (jal),
        .jalr            (jalr),
        .funct3          (funct3),
        .funct7          (funct7),
        .alu_core_result (alu_core_result),
        .pc_plus4        (pc_plus4),
        .auipc_result    (auipc_result),
        .branch_target   (branch_target),
        .branch_taken    (branch_taken)
    );

    // MEM：load 第二拍不要再次发 mem_read（避免重复读）
    wire mem_read_eff  = mem_read  && (load_wb == 1'b0);
    wire mem_write_eff = mem_write && (load_wb == 1'b0);

    MEM u_MEM (
        .clk         (clk),
        .mem_read    (mem_read_eff),
        .mem_write   (mem_write_eff),
        .alu_result  (alu_core_result),
        .rs2_data    (rs2_data),
        .mem_data    (mem_data),
        .load_signed (load_signed),
        .load_size   (load_size),
        .store_size  (store_size)
    );

    // Next PC：load 第一拍 hold PC，其它照常
  

	wire [31:0] pc_plus4_fetch = pc + 32'd4;
	wire [31:0] pc_next_exec   = branch_taken ? branch_target : pc_plus4_fetch;
	assign pc_next = load_req ? pc : pc_next_exec;
	    // ALU-side candidate for WB
	    always @(*) begin
		if (use_pc_add) begin
		    alu_wb_candidate = auipc_result;
		end else begin
		    case (wb_sel)
		        2'd0: alu_wb_candidate = alu_core_result;
		        2'd2: alu_wb_candidate = pc_plus4;
		        2'd3: alu_wb_candidate = imm;
		        default: alu_wb_candidate = alu_core_result;
		    endcase
		end
	    end

    wire mem_to_reg = (wb_sel == 2'd1);

    // CSR mcycle
    reg [63:0] cycle_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) cycle_cnt <= 64'd0;
        else     cycle_cnt <= cycle_cnt + 1'b1;
    end

    wire        csr_hit;
    wire [31:0] csr_data;
    csr_read u_csr_read (
        .instr     (instr_r),
        .cycle_cnt (cycle_cnt),
        .csr_hit   (csr_hit),
        .csr_data  (csr_data)
    );

    // WB mux
    WB u_WB (
        .mem_to_reg (mem_to_reg),
        .alu_result (alu_wb_candidate),
        .mem_data   (mem_data),
        .wb_data    (wb_data_core)
    );

    assign wb_data = csr_hit ? csr_data : wb_data_core;

    // 写回使能：
    // - load 第一拍：禁止写回
    // - load 第二拍：强制写回一次
    // - 其它：正常写回
    wire wb_wen_normal = csr_hit ? 1'b1 : reg_write;
    assign wb_wen = load_wb ? 1'b1 : (wb_wen_normal && !is_load);

    // EBREAK pulse
    reg ebreak_q;
    always @(posedge clk or posedge rst) begin
        if (rst) ebreak_q <= 1'b0;
        else     ebreak_q <= ebreak;
    end
    assign ebreak_pulse = ebreak & ~ebreak_q;

`ifndef SYNTHESIS
    always @(posedge clk) begin
        if (!rst) begin
            if (ecall) begin
                $display("ECALL at PC=%08x", pc);
                $finish;
            end
            if (ebreak) begin
                $display("EBREAK at PC=%08x", pc);
                $finish;
            end
        end
    end
`endif

endmodule
