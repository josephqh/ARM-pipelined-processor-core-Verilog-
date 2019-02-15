module cpu(
  input wire clk,
  input wire nreset,
  output wire led,
  output wire [7:0] debug_port1,
  output wire [7:0] debug_port2,
  output wire [7:0] debug_port3
  );
  localparam data_width = 32;
  localparam data_width_l2b = $clog2(data_width / 8);
  localparam data_words = 512;
  localparam data_words_l2 = $clog2(data_words);
  localparam data_addr_width = data_words_l2;

  reg [data_width - 1:0]  data_mem[data_words - 1:0];
  reg [data_width - 1:0]  data_mem_rd;
  reg [data_width - 1:0]  data_mem_wd;
  reg [data_addr_width - 1:0] data_addr;
  reg data_mem_we;

  always @(posedge clk) begin
    if (data_mem_we)
        data_mem[data_addr] <= data_mem_wd;
    data_mem_rd <= data_mem[data_addr];
  end

  localparam code_width = 32;
  localparam code_width_l2b = $clog2(code_width / 8);
  localparam code_words = 8;
  localparam code_words_l2 = $clog2(code_words);
  localparam code_addr_width = code_words_l2;
  reg [code_width - 1:0]  code_mem[0:code_words - 1];
  wire [code_width - 1:0]  code_mem_rd;
  wire [code_addr_width - 1:0] code_addr;


  initial begin
    code_mem[0] = 32'b1110_000_0100_0_0010_0010_00000000_0001;  // ADD r2, r2, r1
    code_mem[1] = 32'b1110_101_0_11111111_11111111_11111101;  // branch -12 which is PC = (PC + 8) - 12 = PC - 4
  end

  reg [code_width - 1:0]  pc;
  assign code_addr = pc[code_addr_width - 1 + 2:2];
  assign code_mem_rd = code_mem[code_addr];

  assign led = pc[2]; // make the LED blink on the low order bit of the PC

  assign debug_port1 = pc[9:2];
  assign debug_port2 = code_mem_rd[7:0];
  assign debug_port3 = rf_d1[7:0];

  reg [31:0] rf[0:14];  // register 15 is the pc
initial begin
  rf[1] <= 32'd1;     // for testing
end
  localparam r15 = 4'b1111;
  localparam r14 = 4'b1110; //Link Register

  reg [31:0] cpsr;    // program status register
  localparam cpsr_n = 31;
  localparam cpsr_z = 30;
  localparam cpsr_c = 29;
  localparam cpsr_v = 28;

  reg [3:0] rf_rs1;
  reg [3:0] rf_rs2;
  reg [3:0] rf_ws;
  reg [31:0] rf_wd;
  reg rf_we;
  wire [31:0] rf_d1;
  wire [31:0] rf_d2;

  assign rf_d1 = (rf_rs1 == r15) ? pc : rf[rf_rs1];
  assign rf_d2 = (rf_rs2 == r15) ? pc : rf[rf_rs2];

function automatic [3:0] inst_rn;
  input [31:0] inst;
  inst_rn = inst[19:16];
endfunction

function automatic [3:0] inst_rd;
  input [31:0] inst;
  inst_rd = inst[15:12];
endfunction

function automatic [3:0] inst_rs;
  input [31:0] inst;
  inst_rs = inst[11:8];
endfunction

function automatic [3:0] inst_rm;
  input [31:0] inst;
  inst_rm = inst[3:0];
endfunction

function automatic inst_rs_isreg;
    input [31:0] inst;
    if (inst[4] == 1'b1 && inst[7] == 1'b0)
      inst_rs_isreg = 1'b1;
    else
      inst_rs_isreg = 1'b0;
endfunction

function automatic [7:0] inst_data_proc_imm;
    input [31:0]  inst;
    inst_data_proc_imm = inst[7:0];
endfunction

localparam operand2_is_reg = 1'b0;
localparam operand2_is_imm  = 1'b1;
function automatic operand2_type;
    input [31:0]  inst;
    operand2_type = inst[25];
endfunction


localparam cond_eq = 4'b0000;
localparam cond_ne = 4'b0001;
localparam cond_cs = 4'b0010;
localparam cond_cc = 4'b0011;
localparam cond_ns = 4'b0100;
localparam cond_nc = 4'b0101;
localparam cond_vs = 4'b0110;
localparam cond_vc = 4'b0111;
localparam cond_hi = 4'b1000;
localparam cond_ls = 4'b1001;
localparam cond_ge = 4'b1010;
localparam cond_lt = 4'b1011;
localparam cond_gt = 4'b1100;
localparam cond_le = 4'b1101;
localparam cond_al = 4'b1110;
function automatic [3:0] inst_cond;
    input [31:0]  inst;
    inst_cond = inst[31:28];
endfunction

localparam inst_type_branchLink = 1'b1;
function automatic inst_branch_islink;
    input [31:0]   inst;
    inst_branch_islink = inst[24];
endfunction

//might want this to distinguish for Load/Store Bit
// inst[20] = 1 or Load, = 0 for Store
localparam inst_type_load = 1'b1;
function automatic inst_branch_isload;
    input [31:0]   inst;
    inst_branch_islink = inst[20];
endfunction

function automatic [31:0] inst_branch_imm;
    input [31:0]  inst;
    inst_branch_imm = { {6{inst[23]}}, inst[23:0], 2'b00 };
endfunction

localparam inst_type_branch = 2'b10;
localparam inst_type_data_proc = 2'b00;
localparam inst_type_ldr_str = 2'b01;
function automatic [1:0] inst_type;
    input [31:0]  inst;
    inst_type = inst[27:26];
endfunction

localparam opcode_and = 4'b0000;
localparam opcode_eor = 4'b0001;
localparam opcode_sub = 4'b0010;
localparam opcode_rsb = 4'b0011;
localparam opcode_add = 4'b0100;
localparam opcode_adc = 4'b0101;
localparam opcode_sbc = 4'b0110;
localparam opcode_rsc = 4'b0111;
localparam opcode_tst = 4'b1000;
localparam opcode_teq = 4'b1001;
localparam opcode_cmp = 4'b1010;
localparam opcode_cmpn = 4'b1011;
localparam opcode_orr = 4'b1100;
localparam opcode_mov = 4'b1101;
localparam opcode_bic = 4'b1110;
localparam opcode_mvn = 4'b1111;
function automatic [3:0] inst_opcode;
    input [31:0]  inst;
    inst_opcode = inst[24:21];
endfunction

//  "Fetch" from code memory into instruction bits
  reg [31:0] inst;
  always @(*) begin
    inst = code_mem_rd;
  end

// "Decode" the second operand
  reg [31:0] operand2;
  // compute second operand
  always @(*) begin
    // For now, we only support R type unshifted instructions.
    // shifts and such are NOT implemented.
    if (operand2_type(inst) == operand2_is_reg)
      operand2 = rf_d2;
    else
      operand2 = inst_data_proc_imm(inst);
  end

  // "Decode" what gets read and written
  always @(*) begin
    rf_rs1 = inst_rn(inst);
    rf_rs2 = inst_rm(inst);
    rf_ws = inst_rd(inst);
  end

  // "Decode" whether we write the register file
  always @(*) begin
    rf_we = 1'b0;

    case (inst_type(inst))
        inst_type_branch: rf_we = 1'b0;
        inst_type_data_proc:
          if (inst_cond(inst) == cond_al)
            rf_we = 1'b1;
    endcase
  end

  // "Decode" the branch target
  reg [31:0] branch_target;
  always @(*) begin
    branch_target = pc + 8 + inst_branch_imm(inst);
  end

  // "Execute" the instruction
  reg [32:0] alu_result;
  reg [31:0] rf_d1_copy;
  reg [31:0] operand2_copy;
  always @(*) begin
      alu_result = 33'h0_0000_0000;
      rf_d1_copy = rf_d1;
      operand2_copy = operand2;
      case (inst_opcode(inst))
        opcode_and: alu_result = rf_d1 & operand2;
        opcode_eor: alu_result = (rf_d1 & ~operand2) | (~rf_d1 & operand2);
        opcode_sub: begin
                      alu_result = rf_d1 + ~operand2 + 1;
                      if (inst[20] == 1'b1 && rf_ws != 4'b1111)
                        cpsr[cpsr_v] = ((alu_result < 0 && rf_d1 > 0 && ~operand2 + 1 > 0) ||
                                        (alu_result > 0 && rf_d1 < 0 && ~operand2 + 1 < 0) ? 1 : 0);
                    end
        opcode_rsb: begin
                      alu_result = operand2 + ~rf_d1 + 1;
                      if (inst[20] == 1'b1 && rf_ws != 4'b1111)
                        cpsr[cpsr_v] = ((alu_result < 0 && ~rf_d1 + 1 > 0 && operand2 > 0) ||
                                        (alu_result > 0 && ~rf_d1 + 1 < 0 && operand2 < 0) ? 1 : 0);
                    end
        opcode_add: begin
                      alu_result = rf_d1 + operand2;
                      if (inst[20] == 1'b1 && rf_ws != 4'b1111)
                        cpsr[cpsr_v] = ((alu_result < 0 && rf_d1 > 0 && operand2 > 0) ||
                                        (alu_result > 0 && rf_d1 < 0 && operand2 < 0) ? 1 : 0);
                    end
        opcode_adc: begin
                      alu_result = rf_d1 + operand2 + cpsr[cpsr_c];
                      if (inst[20] == 1'b1 && rf_ws != 4'b1111)
                        cpsr[cpsr_v] = ((alu_result < 0 && rf_d1 > 0 && operand2 > 0) ||
                                        (alu_result > 0 && rf_d1 < 0 && operand2 < 0) ? 1 : 0);
                    end
        opcode_sbc: begin
                      alu_result = rf_d1 + ~operand2 + cpsr[cpsr_c];
                      if (inst[20] == 1'b1 && rf_ws != 4'b1111)
                        cpsr[cpsr_v] = ((alu_result < 0 && rf_d1 > 0 && ~operand2 + 1 > 0) ||
                                        (alu_result > 0 && rf_d1 < 0 && ~operand2 + 1 < 0) ? 1 : 0);
                    end
        opcode_rsc: begin
                      alu_result = operand2 + ~rf_d1 + cpsr[cpsr_c];
                      if (inst[20] == 1'b1 && rf_ws != 4'b1111)
                        cpsr[cpsr_v] = ((alu_result < 0 && ~rf_d1 + 1 > 0 && operand2 > 0) ||
                                        (alu_result > 0 && ~rf_d1 + 1 < 0 && operand2 < 0) ? 1 : 0);
                    end
        opcode_tst: alu_result = rf_d1 & operand2;
        opcode_teq: alu_result = rf_d1 ^ operand2;
        opcode_cmp: begin
                      alu_result = rf_d1 + ~operand2 + 1;
                      if (inst[20] == 1'b1 && rf_ws != 4'b1111)
                        cpsr[cpsr_v] = ((alu_result < 0 && rf_d1 > 0 && ~operand2 + 1> 0) ||
                                        (alu_result > 0 && rf_d1 < 0 && ~operand2 + 1 < 0) ? 1 : 0);
                    end
        opcode_cmpn: begin
                      alu_result = rf_d1 + operand2;
                      if (inst[20] == 1'b1 && rf_ws != 4'b1111)
                        cpsr[cpsr_v] = ((alu_result < 0 && rf_d1 > 0 && operand2 > 0) ||
                                        (alu_result > 0 && rf_d1 < 0 && operand2 < 0) ? 1 : 0);
                    end
        opcode_orr: alu_result = rf_d1 | operand2;
        opcode_mov: alu_result = operand2;
        opcode_bic: alu_result = rf_d1 & ~operand2;
        opcode_mvn: alu_result = 32'hFFFF_FFFF ^ operand2;
      endcase

      // Updates condition bits
      if (inst[20] == 1'b1 && rf_ws != 4'b1111) begin
        cpsr[cpsr_c] = alu_result[32];
        cpsr[cpsr_z] = (alu_result == 33'h0_0000_0000 ? 1 : 0);
        cpsr[cpsr_n] = alu_result[31];
      end

      if (inst_opcode(inst) != opcode_tst &&
          inst_opcode(inst) != opcode_teq &&
          inst_opcode(inst) != opcode_cmp &&
          inst_opcode(inst) != opcode_cmpn)
        rf_wd = alu_result[31:0];
  end

  // "Write back" the instruction
  always @(posedge clk) begin
    if (nreset && rf_we)
      if (rf_ws != r15)
        rf[rf_ws] <= rf_wd;
  end

  always @(posedge clk) begin
    data_mem_wd <= 0; //added this in from lab 1 starter from here to
    data_addr <= 0;
  //   code_addr <= 0;
    data_mem_we <= 0; //HERE. made this note just in case anything breaks
    if (!nreset)
        pc <= 32'd0;
    else begin
      // default behavior
      pc <= pc + 4;

      if (inst_type(inst) == inst_type_branch) begin
        if (inst_branch_islink(inst) == inst_type_branchLink) begin
          rf[r14] <= pc + 4; // loads LR with next instruction
        end
        case (inst_cond(inst))
          cond_eq: if (cpsr[cpsr_z] == 1'b1) pc <= branch_target;
          cond_ne: if (~cpsr[cpsr_z]) pc <= branch_target;
          cond_cs: if (cpsr[cpsr_c]) pc <= branch_target;
          cond_cc: if (~cpsr[cpsr_c]) pc <= branch_target;
          cond_ns: if (cpsr[cpsr_n]) pc <= branch_target;
          cond_nc: if (~cpsr[cpsr_n]) pc <= branch_target;
          cond_vs: if (cpsr[cpsr_v]) pc <= branch_target;
          cond_vc: if (~cpsr[cpsr_v]) pc <= branch_target;
          cond_hi: if (cpsr[cpsr_c] && ~cpsr[cpsr_z]) pc <= branch_target;
          cond_ls: if (~cpsr[cpsr_c] || cpsr[cpsr_z]) pc <= branch_target;
          cond_ge: if (cpsr[cpsr_n] == cpsr[cpsr_v]) pc <= branch_target;
          cond_lt: if (cpsr[cpsr_n] != cpsr[cpsr_v]) pc <= branch_target;
          cond_gt: if (~cpsr[cpsr_z] && cpsr[cpsr_n] == cpsr[cpsr_v]) pc <= branch_target;
          cond_le: if (cpsr[cpsr_z] || cpsr[cpsr_n] != cpsr[cpsr_v]) pc <= branch_target;
          cond_al: pc <= branch_target;
        endcase
          // pc <= branch_target; marks comment
      end
      else if (inst_type(inst) == inst_type_ldr_str) begin //
        //  if (inst_branch_isLoad(inst) == inst_type_load) begin
        //   case (inst_cond(inst))
        //     cond_eq: if (cpsr[cpsr_z] == 1'b1) rf[inst_rd] <= data_mem[rf[inst_rn]];??????  rf[inst_rn] = address?
        //     cond_ne: if (~cpsr[cpsr_z]) ;
        //     cond_cs: if (cpsr[cpsr_c]) pc <= branch_target;
        //     cond_cc: if (~cpsr[cpsr_c]) pc <= branch_target;
        //     cond_ns: if (cpsr[cpsr_n]) pc <= branch_target;
        //     cond_nc: if (~cpsr[cpsr_n]) pc <= branch_target;
        //     cond_vs: if (cpsr[cpsr_v]) pc <= branch_target;
        //     cond_vc: if (~cpsr[cpsr_v]) pc <= branch_target;
        //     cond_hi: if (cpsr[cpsr_c] && ~cpsr[cpsr_z]) pc <= branch_target;
        //     cond_ls: if (~cpsr[cpsr_c] || cpsr[cpsr_z]) pc <= branch_target;
        //     cond_ge: if (cpsr[cpsr_n] == cpsr[cpsr_v]) pc <= branch_target;
        //     cond_lt: if (cpsr[cpsr_n] != cpsr[cpsr_v]) pc <= branch_target;
        //     cond_gt: if (~cpsr[cpsr_z] && cpsr[cpsr_n] == cpsr[cpsr_v]) pc <= branch_target;
        //     cond_le: if (cpsr[cpsr_z] || cpsr[cpsr_n] != cpsr[cpsr_v]) pc <= branch_target;
        //     cond_al: pc <= branch_target;
        //   endcase
        //  end
        //  else begin //STORE to mem
        //   case (inst_cond(inst))
        //     cond_eq: if (cpsr[cpsr_z] == 1'b1) ; data_mem[rf[inst_rn]] <= rf[inst_rd]  ??????
        //     cond_ne: if (~cpsr[cpsr_z]) ;
        //     cond_cs: if (cpsr[cpsr_c]) pc <= branch_target;
        //     cond_cc: if (~cpsr[cpsr_c]) pc <= branch_target;
        //     cond_ns: if (cpsr[cpsr_n]) pc <= branch_target;
        //     cond_nc: if (~cpsr[cpsr_n]) pc <= branch_target;
        //     cond_vs: if (cpsr[cpsr_v]) pc <= branch_target;
        //     cond_vc: if (~cpsr[cpsr_v]) pc <= branch_target;
        //     cond_hi: if (cpsr[cpsr_c] && ~cpsr[cpsr_z]) pc <= branch_target;
        //     cond_ls: if (~cpsr[cpsr_c] || cpsr[cpsr_z]) pc <= branch_target;
        //     cond_ge: if (cpsr[cpsr_n] == cpsr[cpsr_v]) pc <= branch_target;
        //     cond_lt: if (cpsr[cpsr_n] != cpsr[cpsr_v]) pc <= branch_target;
        //     cond_gt: if (~cpsr[cpsr_z] && cpsr[cpsr_n] == cpsr[cpsr_v]) pc <= branch_target;
        //     cond_le: if (cpsr[cpsr_z] || cpsr[cpsr_n] != cpsr[cpsr_v]) pc <= branch_target;
        //     cond_al: pc <= branch_target;
        //   endcase
        //  end
       end
      end
    end
endmodule
