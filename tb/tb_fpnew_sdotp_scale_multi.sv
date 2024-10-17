`timescale 1ns/1ps

module tb_fpnew_sdotp_scale_multi;
  // Simulation inputs
  string stim_file = `STIM_FILE;
  fpnew_pkg::fp_format_e SRC_FMT = (`SRC_FMT == "FP8") ? fpnew_pkg::FP8 : fpnew_pkg::FP8ALT;

  // Parameters for the module
  parameter fpnew_pkg::fmt_logic_t SrcDotpFpFmtConfig = 6'b000101; // Supported source formats (FP8, FP8ALT)
  parameter fpnew_pkg::fmt_logic_t DstDotpFpFmtConfig = 6'b100000; // Supported destination formats (FP32)
  parameter int unsigned NumPipeRegs = 0;
  parameter fpnew_pkg::pipe_config_t PipeConfig = fpnew_pkg::BEFORE;
  parameter type TagType = logic;
  parameter type AuxType = logic;

  localparam int unsigned SRC_WIDTH = fpnew_pkg::max_fp_width(SrcDotpFpFmtConfig);
  localparam int unsigned DST_WIDTH = fpnew_pkg::max_fp_width(DstDotpFpFmtConfig);
  localparam int unsigned SCALE_WIDTH = 8;
  localparam int unsigned NUM_FORMATS = fpnew_pkg::NUM_FP_FORMATS;

  // Clock and reset signals
  logic clk_i;
  logic rst_ni;

  // Input signals
  logic [3:0][SRC_WIDTH-1:0] operands_a_i;
  logic [3:0][SRC_WIDTH-1:0] operands_b_i;
  logic [SCALE_WIDTH-1:0] operand_c_i;
  logic [DST_WIDTH-1:0] operand_d_i;
  logic [NUM_FORMATS-1:0][9:0] is_boxed_i;
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
  int count, fail_count;

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
    .AuxType(AuxType)
  ) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .operands_a_i(operands_a_i),
    .operands_b_i(operands_b_i),
    .operand_c_i(operand_c_i),
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
    forever #5 clk_i = ~clk_i;  // 10ns clock period
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

  // Test vector generator
  initial begin
    $timeformat(-9, 1, " ns", 12);

    // Reset the DUT
    reset_dut();
    @(posedge clk_i);

    // Open the file with input data and expected result
    file = $fopen(stim_file, "r");
    if (file == 0) begin
      $display("Failed to open test data file");
      $finish;
    end

    count = 1;
    fail_count = 0;

    // Read test vectors from the file, process each line
    while (!$feof(file)) begin
      @(posedge clk_i);
      // Read the test vectors from the file (single line)
      line = "";
      r = $fgets(line, file);
      if (line == "") begin
        continue;  // Skip empty lines
      end

      // Parse the string and extract individual values
      r = $sscanf(line, "%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%d,%d,%d,%d,%b,%d", 
                  operands_a_i[0], operands_a_i[1], operands_a_i[2], operands_a_i[3],
                  operands_b_i[0], operands_b_i[1], operands_b_i[2], operands_b_i[3],
                  operand_c_i, operand_d_i, expected_result, sum_prod, shift_acc, 
                  shifted_acc, sum_prod_acc, tb_sum_shifted, tb_final_exponent);

      // Set remaining signals
      is_boxed_i = '1;
      src_fmt_i = SRC_FMT;
      dst_fmt_i = fpnew_pkg::FP32;
      rnd_mode_i = fpnew_pkg::RNE;
      op_i = fpnew_pkg::SDOTP;
      op_mod_i = 0;
      in_valid_i = 1;
      out_ready_i = 1;

      // Wait for the result
      wait (out_valid_o);
      #5;
      
      // Compare result with the expected result from Python
      if (dut.result_is_special != 1'b1) begin
        if (dut.sum_product !== sum_prod) begin
          $display("Sum product test failed! Expected: %h, Got: %h at time %t", sum_prod, dut.sum_product, $realtime);
        end
        if (dut.accumulator_shift_amount !== shift_acc) begin
          $display("Accumlator shift amount test failed! Expected: %h, Got: %h at time %t", shift_acc, dut.accumulator_shift_amount, $realtime);
        end
        if (dut.accumulator_shifted !== shifted_acc) begin
          $display("Shifted accumulator test failed! Expected: %h, Got: %h at time %t", shifted_acc, dut.accumulator_shifted, $realtime);
        end
        if (dut.result_is_accumulator !== 1'b1 && dut.sum_product_accumulator !== sum_prod_acc) begin
          $display("Sum product accumulator test failed! Expected: %h, Got: %h at time %t", sum_prod_acc, dut.sum_product_accumulator, $realtime);
        end
      end

      if (result_o !== expected_result) begin
        $display("Result test FAILED! Vector: [%d], Expected: %h, Got: %h at time %t", count, expected_result, result_o, $realtime);
        fail_count++;
      end

      count++;
    end

    // Stop the simulation
    $fclose(file);
    $display("Simulation finished, number of test vectors tested: %d, failed: %d", count-1, fail_count);
    $stop;
  end
endmodule
