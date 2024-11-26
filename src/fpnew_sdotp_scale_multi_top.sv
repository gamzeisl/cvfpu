// Copyright 2019-2024 ETH Zurich and University of Bologna.
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// SPDX-License-Identifier: SHL-0.51

// Author: Gamze Islamoglu <gislamoglu@iis.ee.ethz.ch>

`include "common_cells/registers.svh"
import fpnew_sdotp_scale_multi_pkg::*;

module fpnew_sdotp_scale_multi_top #(
  // One-hot config string: | FP32 | FP64 | FP16 | FP8 | FP16ALT | FP8ALT |
  parameter fpnew_pkg::fmt_logic_t   SrcDotpFpFmtConfig = 6'b000101, // Supported source formats (FP8, FP8ALT)
  parameter fpnew_pkg::fmt_logic_t   DstDotpFpFmtConfig = 6'b100000, // Supported destination formats (FP32)
  parameter int unsigned             NumPipeRegs = 0,
  parameter fpnew_pkg::pipe_config_t PipeConfig  = fpnew_pkg::BEFORE,
  parameter type                     TagType     = logic,
  parameter type                     AuxType     = logic,
  // Do not change
  localparam int unsigned SRC_WIDTH = fpnew_pkg::max_fp_width(SrcDotpFpFmtConfig),
  localparam int unsigned DST_WIDTH = fpnew_pkg::max_fp_width(DstDotpFpFmtConfig),
  localparam int unsigned SCALE_WIDTH = 8,
  localparam int unsigned VECTOR_SIZE = 4,
  localparam int unsigned NUM_FORMATS = fpnew_pkg::NUM_FP_FORMATS
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,
  // Input signals
  input  logic [VECTOR_SIZE-1:0][SRC_WIDTH-1:0]   operands_a_i, // 4 operands
  input  logic [VECTOR_SIZE-1:0][SRC_WIDTH-1:0]   operands_b_i, // 4 operands
  input  logic [SCALE_WIDTH-1:0]      operand_c_i, // 1 operand
  input  logic [DST_WIDTH-1:0]        operand_d_i, // 1 operand, accumulator
  input  logic [NUM_FORMATS-1:0][NUM_OPERANDS-1:0] is_boxed_i,
  input  fpnew_pkg::roundmode_e       rnd_mode_i,
  input  fpnew_pkg::operation_e       op_i,
  input  logic                        op_mod_i,
  input  fpnew_pkg::fp_format_e       src_fmt_i, // format of the multiplicands
  input  fpnew_pkg::fp_format_e       dst_fmt_i, // format of the addend and result
  input  TagType                      tag_i,
  input  logic                        mask_i,
  input  AuxType                      aux_i,
  // Input Handshake
  input  logic                        in_valid_i,
  output logic                        in_ready_o,
  input  logic                        flush_i,
  // Output signals
  output logic [DST_WIDTH-1:0]        result_o,
  output fpnew_pkg::status_t          status_o,
  output logic                        extension_bit_o,
  output TagType                      tag_o,
  output logic                        mask_o,
  output AuxType                      aux_o,
  // Output handshake
  output logic                        out_valid_o,
  input  logic                        out_ready_i,
  // Indication of valid data in flight
  output logic                        busy_o
);



  // ----------------
  // Type definition
  // ----------------
  typedef struct packed {
    logic                      sign;
    logic [SUPER_EXP_BITS-1:0] exponent;
    logic [SUPER_MAN_BITS-1:0] mantissa;
  } fp_src_t;
  typedef struct packed {
    logic                          sign;
    logic [SUPER_DST_EXP_BITS-1:0] exponent;
    logic [SUPER_DST_MAN_BITS-1:0] mantissa;
  } fp_dst_t;

  // ---------------
  // Input pipeline
  // ---------------
  // Selected pipeline output signals as non-arrays
  logic [VECTOR_SIZE-1:0][SRC_WIDTH-1:0] operands_a_q;
  logic [VECTOR_SIZE-1:0][SRC_WIDTH-1:0] operands_b_q;
  logic [SCALE_WIDTH-1:0]    operand_c_q;
  logic [DST_WIDTH-1:0]      operand_d_q;
  fpnew_pkg::fp_format_e src_fmt_q;
  fpnew_pkg::fp_format_e dst_fmt_q;
  fpnew_pkg::roundmode_e rnd_mode_q;

  // Input pipeline signals, index i holds signal after i register stages
  logic                  [0:NUM_INP_REGS][VECTOR_SIZE-1:0][SRC_WIDTH-1:0]   inp_pipe_operands_a_q;
  logic                  [0:NUM_INP_REGS][VECTOR_SIZE-1:0][SRC_WIDTH-1:0]   inp_pipe_operands_b_q;
  logic                  [0:NUM_INP_REGS][SCALE_WIDTH-1:0]      inp_pipe_operand_c_q;
  logic                  [0:NUM_INP_REGS][DST_WIDTH-1:0]        inp_pipe_operand_d_q;
  logic                  [0:NUM_INP_REGS][NUM_FORMATS-1:0][NUM_OPERANDS-1:0] inp_pipe_is_boxed_q;
  fpnew_pkg::roundmode_e [0:NUM_INP_REGS]                       inp_pipe_rnd_mode_q;
  fpnew_pkg::operation_e [0:NUM_INP_REGS]                       inp_pipe_op_q;
  logic                  [0:NUM_INP_REGS]                       inp_pipe_op_mod_q;
  fpnew_pkg::fp_format_e [0:NUM_INP_REGS]                       inp_pipe_src_fmt_q;
  fpnew_pkg::fp_format_e [0:NUM_INP_REGS]                       inp_pipe_dst_fmt_q;
  TagType                [0:NUM_INP_REGS]                       inp_pipe_tag_q;
  logic                  [0:NUM_INP_REGS]                       inp_pipe_mask_q;
  AuxType                [0:NUM_INP_REGS]                       inp_pipe_aux_q;
  logic                  [0:NUM_INP_REGS]                       inp_pipe_valid_q;
  // Ready signal is combinatorial for all stages
  logic [0:NUM_INP_REGS] inp_pipe_ready;

  // Input stage: First element of pipeline is taken from inputs
  assign inp_pipe_operands_a_q[0]   = operands_a_i;
  assign inp_pipe_operands_b_q[0]   = operands_b_i;
  assign inp_pipe_operand_c_q[0]    = operand_c_i;
  assign inp_pipe_operand_d_q[0]    = operand_d_i;
  assign inp_pipe_is_boxed_q[0]     = is_boxed_i;
  assign inp_pipe_rnd_mode_q[0]     = rnd_mode_i;
  assign inp_pipe_op_q[0]           = op_i;
  assign inp_pipe_op_mod_q[0]       = op_mod_i;
  assign inp_pipe_src_fmt_q[0]      = src_fmt_i;
  assign inp_pipe_dst_fmt_q[0]      = dst_fmt_i;
  assign inp_pipe_tag_q[0]          = tag_i;
  assign inp_pipe_mask_q[0]         = mask_i;
  assign inp_pipe_aux_q[0]          = aux_i;
  assign inp_pipe_valid_q[0]        = in_valid_i;
  // Input stage: Propagate pipeline ready signal to updtream circuitry
  assign in_ready_o = inp_pipe_ready[0];
  // Generate the register stages
  for (genvar i = 0; i < NUM_INP_REGS; i++) begin : gen_input_pipeline
    // Internal register enable for this stage
    logic reg_ena;
    // Determine the ready signal of the current stage - advance the pipeline:
    // 1. if the next stage is ready for our data
    // 2. if the next stage only holds a bubble (not valid) -> we can pop it
    assign inp_pipe_ready[i] = inp_pipe_ready[i+1] | ~inp_pipe_valid_q[i+1];
    // Valid: enabled by ready signal, synchronous clear with the flush signal
    `FFLARNC(inp_pipe_valid_q[i+1], inp_pipe_valid_q[i], inp_pipe_ready[i], flush_i, 1'b0, clk_i, rst_ni)
    // Enable register if pipleine ready and a valid data item is present
    assign reg_ena = inp_pipe_ready[i] & inp_pipe_valid_q[i];
    // Generate the pipeline registers within the stages, use enable-registers
    `FFL(inp_pipe_operands_a_q[i+1],   inp_pipe_operands_a_q[i],   reg_ena, '0)
    `FFL(inp_pipe_operands_b_q[i+1],   inp_pipe_operands_b_q[i],   reg_ena, '0)
    `FFL(inp_pipe_operand_c_q[i+1],    inp_pipe_operand_c_q[i],    reg_ena, '0)
    `FFL(inp_pipe_operand_d_q[i+1],    inp_pipe_operand_d_q[i],    reg_ena, '0)
    `FFL(inp_pipe_is_boxed_q[i+1],     inp_pipe_is_boxed_q[i],     reg_ena, '0)
    `FFL(inp_pipe_rnd_mode_q[i+1],     inp_pipe_rnd_mode_q[i],     reg_ena, fpnew_pkg::RNE)
    `FFL(inp_pipe_op_q[i+1],           inp_pipe_op_q[i],           reg_ena, fpnew_pkg::SDOTP)
    `FFL(inp_pipe_op_mod_q[i+1],       inp_pipe_op_mod_q[i],       reg_ena, '0)
    `FFL(inp_pipe_src_fmt_q[i+1],      inp_pipe_src_fmt_q[i],      reg_ena, fpnew_pkg::fp_format_e'(0))
    `FFL(inp_pipe_dst_fmt_q[i+1],      inp_pipe_dst_fmt_q[i],      reg_ena, fpnew_pkg::fp_format_e'(0))
    `FFL(inp_pipe_tag_q[i+1],          inp_pipe_tag_q[i],          reg_ena, TagType'('0))
    `FFL(inp_pipe_mask_q[i+1],         inp_pipe_mask_q[i],         reg_ena, '0)
    `FFL(inp_pipe_aux_q[i+1],          inp_pipe_aux_q[i],          reg_ena, AuxType'('0))
  end
  // Output stage: assign selected pipe outputs to signals for later use
  assign operands_a_q   = inp_pipe_operands_a_q[NUM_INP_REGS];
  assign operands_b_q   = inp_pipe_operands_b_q[NUM_INP_REGS];
  assign operand_c_q    = inp_pipe_operand_c_q[NUM_INP_REGS];
  assign operand_d_q    = inp_pipe_operand_d_q[NUM_INP_REGS];
  assign src_fmt_q      = inp_pipe_src_fmt_q[NUM_INP_REGS];
  assign dst_fmt_q      = inp_pipe_dst_fmt_q[NUM_INP_REGS];
  assign rnd_mode_q     = inp_pipe_rnd_mode_q[NUM_INP_REGS];

  logic [7:0][SRC_WIDTH-1:0] operands_post_inp_pipe;
  assign operands_post_inp_pipe = {operands_b_q, operands_a_q};

  // -----------------
  // Input processing
  // -----------------

  fp_src_t [VECTOR_SIZE-1:0] operands_a, operands_b;
  logic [SCALE_WIDTH-1:0] operand_c;
  fp_dst_t             operand_d;
  fpnew_pkg::fp_info_t [VECTOR_SIZE-1:0] info_a, info_b;
  fpnew_pkg::fp_info_t info_c, info_d;

  classifier #(
  ) i_classifier (
    .operands_post_inp_pipe(operands_post_inp_pipe),
    .operand_c_q(operand_c_q),
    .operand_d_q(operand_d_q),
    .inp_pipe_is_boxed_q(inp_pipe_is_boxed_q),
    .src_fmt_q(src_fmt_q),
    .dst_fmt_q(dst_fmt_q),
    .inp_pipe_op_mod_q(inp_pipe_op_mod_q),
    .info_a(info_a),
    .info_b(info_b),
    .info_c(info_c),
    .info_d(info_d),
    .operands_a(operands_a),
    .operands_b(operands_b),
    .operand_c(operand_c),
    .operand_d(operand_d)
  );

  // ---------------------
  // Special case handling
  // ---------------------

  logic [DST_WIDTH-1:0] special_result;
  fpnew_pkg::status_t   special_status;
  logic                 result_is_special;

  special_cases #(
  ) i_special_cases (
    .operands_a(operands_a),
    .operands_b(operands_b),
    .operand_c(operand_c),
    .operand_d(operand_d),
    .info_a(info_a),
    .info_b(info_b),
    .info_c(info_c),
    .info_d(info_d),
    .src_fmt_q(src_fmt_q),
    .dst_fmt_q(dst_fmt_q),
    .special_result(special_result),
    .special_status(special_status),
    .result_is_special(result_is_special)
  );

  // ------------------
  // Product data path
  // ------------------
  logic signed [VECTOR_SIZE-1:0][2*PRECISION_BITS  :0] product_signed;  // two's complement product

  multiplier #(
  ) i_multiplier (
    .operands_a(operands_a),
    .operands_b(operands_b),
    .info_a(info_a),
    .info_b(info_b),
    .product_signed(product_signed)
  );

  // ------------------
  // Shift data path
  // ------------------
  logic signed [VECTOR_SIZE-1:0][SOP_FIXED_WIDTH-1:0] shifted_product;
  logic [VECTOR_SIZE-1:0][  5:0] shift_amount; // max shift can be 58 (28 + exp-max(30)), min shift is 0 (28 + exp-min(-28))

  shifter #(
  ) i_shifter (
    .operands_a(operands_a),
    .operands_b(operands_b),
    .info_a(info_a),
    .info_b(info_b),
    .product_signed(product_signed),
    .src_fmt_q(src_fmt_q),
    .shift_amount(shift_amount),
    .shifted_product(shifted_product)
  );

  // ------------------
  // Adder data path
  // ------------------
  logic signed [FIXED_SUM_WIDTH-1:0] sum_product;

  adder #(
  ) i_adder (
    .shifted_product(shifted_product),
    .sum_product(sum_product)
  );

  // -----------------------------
  // Accumulator shift data path
  // -----------------------------
  logic result_is_accumulator;
  logic accumulator_is_right_shifted;

  logic signed [9:0] accumulator_right_shift_amount;
  logic signed [LZC_SUM_WIDTH-1:0] sum_product_accumulator_extended;
  logic signed [DST_PRECISION_BITS :0] signed_mantissa_d;
  logic accumulator_sticky;

  accumulator_shift #(
  ) i_accumulator_shift (
    .sum_product(sum_product),
    .operand_c(operand_c),
    .operand_d(operand_d),
    .info_d(info_d),
    .dst_fmt_q(dst_fmt_q),
    .accumulator_is_right_shifted(accumulator_is_right_shifted),
    .accumulator_right_shift_amount(accumulator_right_shift_amount),
    .sum_product_accumulator_extended(sum_product_accumulator_extended),
    .result_is_accumulator(result_is_accumulator),
    .accumulator_sticky(accumulator_sticky),
    .signed_mantissa_d(signed_mantissa_d)
  );

  // --------------
  // Normalization
  // --------------
  logic        [LZC_SUM_WIDTH-1:0]  sum_magnitude;
  logic                                 final_sign;
  logic        [DST_PRECISION_BITS-1:0] final_mantissa;
  logic                                 sticky_after_norm;
  logic signed [DST_EXP_WIDTH-1:0]      final_exponent;

  normalizer #(
  ) i_normalizer (
    .sum_product_accumulator_extended(sum_product_accumulator_extended),
    .accumulator_sticky(accumulator_sticky),
    .accumulator_is_right_shifted(accumulator_is_right_shifted),
    .accumulator_right_shift_amount(accumulator_right_shift_amount),
    .signed_mantissa_d(signed_mantissa_d),
    .operand_c_q(operand_c_q),
    .dst_fmt_q(dst_fmt_q),
    .final_sign(final_sign),
    .final_mantissa(final_mantissa),
    .sticky_after_norm(sticky_after_norm),
    .final_exponent(final_exponent),
    .sum_magnitude(sum_magnitude)
  );


  // ----------------------------
  // Rounding and classification
  // ----------------------------
  logic [1:0]                                       round_sticky_bits;
  logic [NUM_FORMATS-1:0][DST_WIDTH-1:0] fmt_result;

  logic of_before_round, of_after_round; // overflow
  logic uf_before_round, uf_after_round; // underflow

  rounder #(
  ) i_rounder (
    .final_sign(final_sign),
    .final_mantissa(final_mantissa),
    .final_exponent(final_exponent),
    .sticky_after_norm(sticky_after_norm),
    .sum_magnitude(sum_magnitude),
    .dst_fmt_q(dst_fmt_q),
    .rnd_mode_q(rnd_mode_q),
    .round_sticky_bits(round_sticky_bits),
    .fmt_result(fmt_result),
    .of_before_round(of_before_round),
    .of_after_round(of_after_round),
    .uf_after_round(uf_after_round)
  );

  // -----------------
  // Result selection
  // -----------------
  logic [DST_WIDTH-1:0] regular_result;
  fpnew_pkg::status_t   regular_status;

  // Assemble regular result
  assign regular_result    = fmt_result[dst_fmt_q];
  assign regular_status.NV = 1'b0; // only valid cases are handled in regular path
  assign regular_status.DZ = 1'b0; // no divisions
  assign regular_status.OF = of_before_round | of_after_round;   // rounding can introduce overflow
  assign regular_status.UF = uf_after_round & regular_status.NX; // only inexact results raise UF
  assign regular_status.NX = (| round_sticky_bits) | of_before_round | of_after_round;

  // Final results for output pipeline
  logic [DST_WIDTH-1:0] result_d;
  fpnew_pkg::status_t   status_d;

  // Select output depending on special case detection
  // TODO: Add output pipeline
  assign result_o = result_is_special ? special_result : ((result_is_accumulator | sum_magnitude == '0) ? operand_d_q : regular_result);
  assign status_o = result_is_special ? special_status : ((result_is_accumulator | sum_magnitude == '0) ? fpnew_pkg::status_t'(0) : regular_status);
  assign out_valid_o = 1'b1;


endmodule
