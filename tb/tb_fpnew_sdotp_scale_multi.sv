`timescale 1ns/1ps

module tb_fpnew_sdotp_scale_multi;
  // Simulation inputs
  string stim_file = `STIM_FILE;
  fpnew_pkg::fp_format_e SRC_FMT = (`SRC_FMT == "FP8") ? fpnew_pkg::FP8 : fpnew_pkg::FP8ALT;
  parameter int unsigned VECTOR_SIZE = `ifdef VECTOR_SIZE `VECTOR_SIZE `else 8 `endif;
  parameter int unsigned PROB_STALL = `ifdef PROB_STALL `PROB_STALL `else 2 `endif;
  parameter int unsigned NumPipeRegs = `ifdef NUM_PIPE_REGS `NUM_PIPE_REGS `else 3 `endif;
  parameter int unsigned NUM_VECTORS = `NUM_VECTORS;

  // Parameters for the module
  parameter fpnew_pkg::pipe_config_t PipeConfig = fpnew_pkg::DISTRIBUTED;
  parameter fpnew_pkg::fmt_logic_t SrcDotpFpFmtConfig = 6'b000101; // Supported source formats (FP8, FP8ALT)
  parameter fpnew_pkg::fmt_logic_t DstDotpFpFmtConfig = 6'b100000; // Supported destination formats (FP32)

  parameter type TagType = logic;
  parameter type AuxType = logic;

  localparam int unsigned SRC_WIDTH = fpnew_pkg::max_fp_width(SrcDotpFpFmtConfig);
  localparam int unsigned DST_WIDTH = fpnew_pkg::max_fp_width(DstDotpFpFmtConfig);
  localparam int unsigned SCALE_WIDTH = 8;
  localparam int unsigned NUM_OPERANDS = 2*VECTOR_SIZE+1;
  localparam int unsigned NUM_FORMATS = fpnew_pkg::NUM_FP_FORMATS;

  localparam int unsigned TCP = 10;  // Clock period in ns
  localparam int unsigned T_APP = TCP/5;  // Apply time in ns
  localparam int unsigned T_TEST = TCP-T_APP;  // Test time in ns

  // Clock and reset signals
  logic clk_i;
  logic rst_ni;

  // Input signals
  logic [VECTOR_SIZE-1:0][SRC_WIDTH-1:0] operands_a_i;
  logic [VECTOR_SIZE-1:0][SRC_WIDTH-1:0] operands_b_i;
  logic [1:0][SCALE_WIDTH-1:0] operands_c_i;
  logic [DST_WIDTH-1:0] operand_d_i;
  logic [NUM_FORMATS-1:0][NUM_OPERANDS-1:0] is_boxed_i;
  fpnew_pkg::roundmode_e rnd_mode_i;
  fpnew_pkg::operation_e op_i;
  logic op_mod_i;
  fpnew_pkg::fp_format_e src_fmt_i;
  fpnew_pkg::fp_format_e dst_fmt_i;
  TagType tag_i;
  logic mask_i;
  AuxType aux_i;

  // Input handshake
  logic in_valid_i;
  logic flush_i;
  logic out_ready_i;

  // Output signals
  logic [DST_WIDTH-1:0] result_o;
  fpnew_pkg::status_t status_o;
  logic extension_bit_o;
  TagType tag_o;
  logic mask_o;
  AuxType aux_o;
  logic in_ready_o;
  logic out_valid_o;
  logic busy_o;

  // File handle for reading input data
  integer file, r;
  string line;

  // Test vector counter
  int count_applied, count_checked, fail_count;

  // Declare a queue to store expected results
  logic [31:0] expected_results[$];
  int vector_indices[$];  // Optional: track input vector indices for easier debugging

  // Expected results
  logic [31:0] expected_result;
  logic [93:0] sum_prod, shifted_acc, sum_prod_acc, tb_sum_shifted;
  logic  [9:0] shift_acc;
  logic  [8:0] tb_final_exponent;

  // Instantiate the DUT (Device Under Test)
  fpnew_sdotp_scale_multi #(
    .SrcDotpFpFmtConfig(SrcDotpFpFmtConfig),
    .DstDotpFpFmtConfig(DstDotpFpFmtConfig),
    .NumPipeRegs(NumPipeRegs),
    .PipeConfig(PipeConfig),
    .TagType(TagType),
    .AuxType(AuxType),
    .VECTOR_SIZE(VECTOR_SIZE)
  ) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .operands_a_i(operands_a_i),
    .operands_b_i(operands_b_i),
    .operands_c_i(operands_c_i),
    .operand_d_i(operand_d_i),
    .is_boxed_i(is_boxed_i),
    .rnd_mode_i(rnd_mode_i),
    .op_i(op_i),
    .op_mod_i(op_mod_i),
    .src_fmt_i(src_fmt_i),
    .dst_fmt_i(dst_fmt_i),
    .tag_i(tag_i),
    .mask_i(mask_i),
    .aux_i(aux_i),
    .in_valid_i(in_valid_i),
    .in_ready_o(in_ready_o),
    .flush_i(flush_i),
    .out_valid_o(out_valid_o),
    .out_ready_i(out_ready_i),
    .result_o(result_o),
    .status_o(status_o),
    .extension_bit_o(extension_bit_o),
    .tag_o(tag_o),
    .mask_o(mask_o),
    .aux_o(aux_o),
    .busy_o(busy_o)
  );

  // Clock generation
  initial begin
    clk_i = 1;
    forever #(TCP/2) clk_i = ~clk_i;  // 10ns clock period
  end

  // Reset task
  task reset_dut();
    begin
      rst_ni = 0;
      in_valid_i = 0;
      out_ready_i = 0;
      #20;
      rst_ni = 1;
      #20;
    end
  endtask

  initial begin : supply_input
    $timeformat(-9, 1, " ns", 12);

    // Reset the DUT
    reset_dut();
    @(posedge clk_i);

    // Set constant input signals
    is_boxed_i = '1;
    src_fmt_i = SRC_FMT;
    dst_fmt_i = fpnew_pkg::FP32;
    rnd_mode_i = fpnew_pkg::RNE;
    op_i = fpnew_pkg::SDOTP;
    op_mod_i = 0;
    flush_i = 0;
    tag_i = '0;
    mask_i = '0;
    aux_i = '0;

    // Open the file with input data and expected result
    file = $fopen(stim_file, "r");
    if (file == 0) begin
      $display("Failed to open test data file");
      $finish;
    end

    count_applied = 0;

    // Modified loop for pipelined execution
    while (!$feof(file)) begin
      @(posedge clk_i);
      #(T_APP);

      // Randomize `in_valid_i` with PROB_STALL% chance of being low
      in_valid_i = ($urandom() % 100) >= PROB_STALL;
      if (in_valid_i) begin
        line = "";
        r = $fgets(line, file);
        if (line == "") begin
          continue;  // Skip empty lines
        end

        for (int i = 0; i < VECTOR_SIZE; i++) begin
          r = $sscanf(line, "%b,", operands_a_i[i]);
          line = line.substr(SRC_WIDTH + 1, line.len()-1);
        end
        for (int i = 0; i < VECTOR_SIZE; i++) begin
          r = $sscanf(line, "%b,", operands_b_i[i]);
          line = line.substr(SRC_WIDTH + 1, line.len()-1);
        end

        r = $sscanf(line, "%b,%b,%b,%b,%d,%d,%d,%d,%b,%d", 
                    operands_c_i[0], operands_c_i[1], operand_d_i, expected_result, sum_prod, shift_acc, 
                    shifted_acc, sum_prod_acc, tb_sum_shifted, tb_final_exponent);

        count_applied++;

        // Store expected result and vector index for later checking
        expected_results.push_back(expected_result);
        vector_indices.push_back(count_applied); // start from 1

        #(T_TEST-T_APP);
        wait (in_ready_o); // Wait for handshake
      end
    end

    @(posedge clk_i);
    #(T_APP);
    in_valid_i = 0;

    $fclose(file);
  end

  initial begin : check_output
    count_checked = 0;
    fail_count = 0;
    out_ready_i = 0;

    // Wait for remaining outputs to complete
    while (count_checked < NUM_VECTORS) begin
      @(posedge clk_i);
      #(T_APP);

      // Randomize `out_ready_i` with PROB_STALL% chance of being low
      out_ready_i = ($urandom() % 100) >= PROB_STALL;
      #(T_TEST-T_APP);

      if (out_valid_o && out_ready_i) begin
        if (result_o !== expected_results[0]) begin
          $display("Result test FAILED! Vector: [%d], Expected: %h, Got: %h at time %t", 
                    vector_indices[0], expected_results[0], result_o, $realtime);
          fail_count++;
        end
        expected_results.pop_front();
        vector_indices.pop_front();
        count_checked++;
      end
    end

    $display("Simulation finished, number of test vectors tested: %d, failed: %d", count_checked, fail_count);
    $finish;
  end
endmodule
