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

module fpnew_sdotp_scale_multi #(
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
  input  logic [3:0][SRC_WIDTH-1:0]   operands_a_i, // 4 operands
  input  logic [3:0][SRC_WIDTH-1:0]   operands_b_i, // 4 operands
  input  logic [SCALE_WIDTH-1:0]      operand_c_i, // 1 operand
  input  logic [DST_WIDTH-1:0]        operand_d_i, // 1 operand, accumulator
  input  logic [NUM_FORMATS-1:0][9:0] is_boxed_i,  // 10 operands
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

  // ----------
  // Constants
  // ----------
  // The super-format that can hold all formats
  localparam fpnew_pkg::fp_encoding_t SUPER_FORMAT = fpnew_pkg::super_format(SrcDotpFpFmtConfig);
  localparam fpnew_pkg::fp_encoding_t SUPER_DST_FORMAT = fpnew_pkg::super_format(DstDotpFpFmtConfig);

  localparam int unsigned SUPER_EXP_BITS = SUPER_FORMAT.exp_bits;
  localparam int unsigned SUPER_MAN_BITS = SUPER_FORMAT.man_bits;
  localparam int unsigned SUPER_DST_EXP_BITS = SUPER_DST_FORMAT.exp_bits;
  localparam int unsigned SUPER_DST_MAN_BITS = SUPER_DST_FORMAT.man_bits;

  // Precision bits 'p' include the implicit bit
  localparam int unsigned PRECISION_BITS = SUPER_MAN_BITS + 1;
  // Destination precision bits 'p_dst' include the implicit bit
  localparam int unsigned DST_PRECISION_BITS = SUPER_DST_MAN_BITS + 1;
  // TODO: The leading-zero counter operates on LZC_SUM_WIDTH bits
  localparam int unsigned LOWER_SUM_WIDTH  = 94;
  localparam int unsigned LZC_RESULT_WIDTH = $clog2(LOWER_SUM_WIDTH);

  // Internal exponent width of FMA must accomodate all meaningful exponent values in order to avoid
  // datapath leakage. This is either given by the exponent bits or the width of the LZC result.
  // In most reasonable FP formats the internal exponent will be wider than the LZC result.
  localparam int unsigned EXP_WIDTH = fpnew_pkg::maximum(SUPER_EXP_BITS + 2, LZC_RESULT_WIDTH);
  localparam int unsigned DST_EXP_WIDTH = unsigned'(fpnew_pkg::maximum(SUPER_DST_EXP_BITS + 2, LZC_RESULT_WIDTH));
  // TODO: Shift amount width: maximum internal mantissa size is 2*DST_PRECISION_BITS+3 bits
  localparam int unsigned SHIFT_AMOUNT_WIDTH = $clog2(2*DST_PRECISION_BITS+PRECISION_BITS+4);
  localparam int unsigned DST_SHIFT_AMOUNT_WIDTH = $clog2(2*DST_PRECISION_BITS+PRECISION_BITS+5);
  // Pipelines
  localparam NUM_INP_REGS = PipeConfig == fpnew_pkg::BEFORE
                            ? NumPipeRegs
                            : (PipeConfig == fpnew_pkg::DISTRIBUTED
                               ? ((NumPipeRegs + 1) / 3) // Second to get distributed regs
                               : 0); // no regs here otherwise
  localparam NUM_MID_REGS = PipeConfig == fpnew_pkg::INSIDE
                          ? NumPipeRegs
                          : (PipeConfig == fpnew_pkg::DISTRIBUTED
                             ? ((NumPipeRegs + 2) / 3) // First to get distributed regs
                             : 0); // no regs here otherwise
  localparam NUM_OUT_REGS = PipeConfig == fpnew_pkg::AFTER
                            ? NumPipeRegs
                            : (PipeConfig == fpnew_pkg::DISTRIBUTED
                               ? (NumPipeRegs / 3) // Last to get distributed regs
                               : 0); // no regs here otherwise


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
  logic [3:0][SRC_WIDTH-1:0] operands_a_q;
  logic [3:0][SRC_WIDTH-1:0] operands_b_q;
  logic [SCALE_WIDTH-1:0]    operand_c_q;
  logic [DST_WIDTH-1:0]      operand_d_q;
  fpnew_pkg::fp_format_e src_fmt_q;
  fpnew_pkg::fp_format_e dst_fmt_q;

  // Input pipeline signals, index i holds signal after i register stages
  logic                  [0:NUM_INP_REGS][3:0][SRC_WIDTH-1:0]   inp_pipe_operands_a_q;
  logic                  [0:NUM_INP_REGS][3:0][SRC_WIDTH-1:0]   inp_pipe_operands_b_q;
  logic                  [0:NUM_INP_REGS][SCALE_WIDTH-1:0]      inp_pipe_operand_c_q;
  logic                  [0:NUM_INP_REGS][DST_WIDTH-1:0]        inp_pipe_operand_d_q;
  logic                  [0:NUM_INP_REGS][NUM_FORMATS-1:0][9:0] inp_pipe_is_boxed_q;
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

  logic [7:0][SRC_WIDTH-1:0] operands_post_inp_pipe;
  assign operands_post_inp_pipe = {operands_b_q, operands_a_q};

  // -----------------
  // Input processing
  // -----------------

  // -----------------
  // Source operands
  // -----------------
  logic        [NUM_FORMATS-1:0][7:0]                     fmt_sign;
  logic signed [NUM_FORMATS-1:0][7:0][SUPER_EXP_BITS-1:0] fmt_exponent;
  logic        [NUM_FORMATS-1:0][7:0][SUPER_MAN_BITS-1:0] fmt_mantissa;

  fpnew_pkg::fp_info_t [NUM_FORMATS-1:0][9:0] info_q;

  // FP Input initialization (Src)
  for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : fmt_src_init_inputs
    // Set up some constants
    localparam int unsigned FP_WIDTH = fpnew_pkg::fp_width(fpnew_pkg::fp_format_e'(fmt));
    localparam int unsigned EXP_BITS = fpnew_pkg::exp_bits(fpnew_pkg::fp_format_e'(fmt));
    localparam int unsigned MAN_BITS = fpnew_pkg::man_bits(fpnew_pkg::fp_format_e'(fmt));

    if (SrcDotpFpFmtConfig[fmt]) begin : active_src_format
      logic [7:0][FP_WIDTH-1:0] trimmed_ops;

      // Classify input
      fpnew_classifier #(
        .FpFormat    ( fpnew_pkg::fp_format_e'(fmt) ),
        .NumOperands ( 8                           )
      ) i_fpnew_classifier (
        .operands_i  ( trimmed_ops                                 ),
        .is_boxed_i  ( inp_pipe_is_boxed_q[NUM_INP_REGS][fmt][7:0] ),
        .info_o      ( info_q[fmt][7:0]                            )
      );
      for (genvar op = 0; op < 8; op++) begin : gen_operands
        assign trimmed_ops[op]       = operands_post_inp_pipe[op][FP_WIDTH-1:0];
        assign fmt_sign[fmt][op]     = operands_post_inp_pipe[op][FP_WIDTH-1];
        assign fmt_exponent[fmt][op] = signed'({1'b0, operands_post_inp_pipe[op][MAN_BITS+:EXP_BITS]});
        assign fmt_mantissa[fmt][op] = {info_q[fmt][op].is_normal, operands_post_inp_pipe[op][MAN_BITS-1:0]} <<
                                       (SUPER_MAN_BITS - MAN_BITS); // move to left of mantissa
      end
    end else begin : inactive_src_format
      assign info_q[fmt][7:0]  = '{default: fpnew_pkg::DONT_CARE}; // format disabled
      assign fmt_sign[fmt]     = fpnew_pkg::DONT_CARE;             // format disabled
      assign fmt_exponent[fmt] = '{default: fpnew_pkg::DONT_CARE}; // format disabled
      assign fmt_mantissa[fmt] = '{default: fpnew_pkg::DONT_CARE}; // format disabled
    end
  end

  // ----------------------------
  // Destination operand
  // ----------------------------
  logic        [NUM_FORMATS-1:0][1:0]                         fmt_dst_sign;
  logic signed [NUM_FORMATS-1:0][1:0][SUPER_DST_EXP_BITS-1:0] fmt_dst_exponent;
  logic        [NUM_FORMATS-1:0][1:0][SUPER_DST_MAN_BITS-1:0] fmt_dst_mantissa;

  // FP Input initialization (Src)
  for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : fmt_dst_init_inputs
    // Set up some constants
    localparam int unsigned FP_WIDTH = fpnew_pkg::fp_width(fpnew_pkg::fp_format_e'(fmt));
    localparam int unsigned EXP_BITS = fpnew_pkg::exp_bits(fpnew_pkg::fp_format_e'(fmt));
    localparam int unsigned MAN_BITS = fpnew_pkg::man_bits(fpnew_pkg::fp_format_e'(fmt));

    if (DstDotpFpFmtConfig[fmt]) begin : active_dst_format
      logic [FP_WIDTH-1:0] trimmed_dst_ops;
      logic                dst_ops_is_boxed;

      assign dst_ops_is_boxed = inp_pipe_is_boxed_q[NUM_INP_REGS][fmt][9];

      // Classify input
      fpnew_classifier #(
        .FpFormat    ( fpnew_pkg::fp_format_e'(fmt) ),
        .NumOperands ( 1                            )
      ) i_fpnew_classifier (
        .operands_i  ( trimmed_dst_ops  ),
        .is_boxed_i  ( dst_ops_is_boxed ),
        .info_o      ( info_q[fmt][9]   )
      );
      assign trimmed_dst_ops          = operand_d_q[FP_WIDTH-1:0];
      assign fmt_dst_sign[fmt]        = operand_d_q[FP_WIDTH-1];
      assign fmt_dst_exponent[fmt]    = signed'({1'b0, operand_d_q[MAN_BITS+:EXP_BITS]});
      assign fmt_dst_mantissa[fmt]    = {info_q[fmt][9].is_normal, operand_d_q[MAN_BITS-1:0]}
                                         << (SUPER_DST_MAN_BITS - MAN_BITS);
    end else begin : inactive_dst_format
      assign info_q[fmt][9]        = '{default: fpnew_pkg::DONT_CARE}; // format disabled
      assign fmt_dst_sign[fmt]     = fpnew_pkg::DONT_CARE;             // format disabled
      assign fmt_dst_exponent[fmt] = '{default: fpnew_pkg::DONT_CARE}; // format disabled
      assign fmt_dst_mantissa[fmt] = '{default: fpnew_pkg::DONT_CARE}; // format disabled
    end
  end

  // -------------------
  // TODO: Scale operand (can be nan)
  // -------------------


  // -------------------------------------------
  // Operation selection and operand adjustment
  // -------------------------------------------
  fp_src_t [VECTOR_SIZE-1:0] operands_a, operands_b;
  logic [SCALE_WIDTH-1:0] operand_c;
  fp_dst_t             operand_d;
  fpnew_pkg::fp_info_t [VECTOR_SIZE-1:0] info_a, info_b;
  fpnew_pkg::fp_info_t info_c, info_d;

  // | \c op_q  | \c op_mod_q | Operation Adjustment
  // |:--------:|:-----------:|---------------------
  // | SDOTPS    | \c 0       | SDOTPS:  none
  // | SDOTPS    | \c 1       | SDOTPSN: Invert the sign of the product (accumulator - dotp)
  // | *others*  | \c -       | *invalid*
  // \note \c op_mod_q always inverts the sign of the addend.
  always_comb begin : op_select
    // Default assignments - packing-order-agnostic
    for (int i = 0; i < VECTOR_SIZE; i++) begin : gen_default_assignments
      operands_a[i] = {fmt_sign[src_fmt_q][i], fmt_exponent[src_fmt_q][i], fmt_mantissa[src_fmt_q][i]};
      operands_b[i] = {fmt_sign[src_fmt_q][i+VECTOR_SIZE], fmt_exponent[src_fmt_q][i+VECTOR_SIZE], fmt_mantissa[src_fmt_q][i+VECTOR_SIZE]};
      info_a[i]     = info_q[src_fmt_q][i];
      info_b[i]     = info_q[src_fmt_q][i+VECTOR_SIZE];
    end
    operand_c = '0;
    operand_d = {fmt_dst_sign[dst_fmt_q], fmt_dst_exponent[dst_fmt_q], fmt_dst_mantissa[dst_fmt_q]};
    info_c    = '{is_normal: 1'b1, is_boxed: 1'b1, default: 1'b0}; //normal, boxed value.
    info_d    = info_q[dst_fmt_q][9];

    // op_mod_q inverts sign of operand A, thus inverting the sign of the dot product
    for (int i = 0; i < VECTOR_SIZE; i++) begin : gen_op_mod_q
      operands_a[i].sign = operands_a[i].sign ^ inp_pipe_op_mod_q[NUM_INP_REGS];
    end
  end

  // ---------------------
  // Input classification
  // ---------------------
  logic any_operand_inf;
  logic any_operand_nan;
  logic signalling_nan;
  logic any_produced_nan;
  logic any_pos_inf;
  logic any_neg_inf;

  // Reduction for special case handling
  assign any_operand_inf = (| {info_a[0].is_inf, info_a[1].is_inf, info_a[2].is_inf, info_a[3].is_inf,
                             info_b[0].is_inf, info_b[1].is_inf, info_b[2].is_inf, info_b[3].is_inf,
                             info_d.is_inf});
  assign any_operand_nan = (| {info_a[0].is_nan, info_a[1].is_nan, info_a[2].is_nan, info_a[3].is_nan,
                             info_b[0].is_nan, info_b[1].is_nan, info_b[2].is_nan, info_b[3].is_nan,
                             info_c.is_nan, info_d.is_nan});
  assign signalling_nan  = (| {info_a[0].is_signalling, info_a[1].is_signalling, 
                             info_a[2].is_signalling, info_a[3].is_signalling,
                             info_b[0].is_signalling, info_b[1].is_signalling,
                             info_b[2].is_signalling, info_b[3].is_signalling,
                             info_c.is_signalling, info_d.is_signalling});
  // Any produced nan, positive or negative infinity
  // 0 * inf = NaN, inf * 0 = NaN
  assign any_produced_nan = (| {info_a[0].is_inf && info_b[0].is_zero,
                             info_a[1].is_inf && info_b[1].is_zero,
                             info_a[2].is_inf && info_b[2].is_zero,
                             info_a[3].is_inf && info_b[3].is_zero,
                             info_b[0].is_inf && info_a[0].is_zero,
                             info_b[1].is_inf && info_a[1].is_zero,
                             info_b[2].is_inf && info_a[2].is_zero,
                             info_b[3].is_inf && info_a[3].is_zero});
  assign any_pos_inf = (| {info_a[0].is_inf && ~(operands_a[0].sign ^ operands_b[0].sign),
                         info_a[1].is_inf && ~(operands_a[1].sign ^ operands_b[1].sign),
                         info_a[2].is_inf && ~(operands_a[2].sign ^ operands_b[2].sign),
                         info_a[3].is_inf && ~(operands_a[3].sign ^ operands_b[3].sign),
                         info_b[0].is_inf && ~(operands_a[0].sign ^ operands_b[0].sign),
                         info_b[1].is_inf && ~(operands_a[1].sign ^ operands_b[1].sign),
                         info_b[2].is_inf && ~(operands_a[2].sign ^ operands_b[2].sign),
                         info_b[3].is_inf && ~(operands_a[3].sign ^ operands_b[3].sign),
                         info_d.is_inf && operand_d.sign});
  assign any_neg_inf = (| {info_a[0].is_inf && (operands_a[0].sign ^ operands_b[0].sign),
                         info_a[1].is_inf && (operands_a[1].sign ^ operands_b[1].sign),
                         info_a[2].is_inf && (operands_a[2].sign ^ operands_b[2].sign),
                         info_a[3].is_inf && (operands_a[3].sign ^ operands_b[3].sign),
                         info_b[0].is_inf && (operands_a[0].sign ^ operands_b[0].sign),
                         info_b[1].is_inf && (operands_a[1].sign ^ operands_b[1].sign),
                         info_b[2].is_inf && (operands_a[2].sign ^ operands_b[2].sign),
                         info_b[3].is_inf && (operands_a[3].sign ^ operands_b[3].sign),
                         info_d.is_inf && ~operand_d.sign});

  // ----------------------
  // Special case handling
  // ----------------------
  logic [DST_WIDTH-1:0] special_result;
  fpnew_pkg::status_t   special_status;
  logic                 result_is_special;

  logic               [NUM_FORMATS-1:0][DST_WIDTH-1:0] fmt_special_result;
  fpnew_pkg::status_t [NUM_FORMATS-1:0]                fmt_special_status;
  logic               [NUM_FORMATS-1:0]                fmt_result_is_special;

  for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : gen_special_results
    // Set up some constants
    localparam int unsigned FP_WIDTH = fpnew_pkg::fp_width(fpnew_pkg::fp_format_e'(fmt));
    localparam int unsigned EXP_BITS = fpnew_pkg::exp_bits(fpnew_pkg::fp_format_e'(fmt));
    localparam int unsigned MAN_BITS = fpnew_pkg::man_bits(fpnew_pkg::fp_format_e'(fmt));

    localparam logic [EXP_BITS-1:0] QNAN_EXPONENT = '1;
    localparam logic [MAN_BITS-1:0] QNAN_MANTISSA = 2**(MAN_BITS-1);
    localparam logic [MAN_BITS-1:0] ZERO_MANTISSA = '0;

    if (DstDotpFpFmtConfig[fmt]) begin : active_format
      always_comb begin : special_cases
        logic [FP_WIDTH-1:0] special_res;

        // Default assignment
        special_res                = {1'b0, QNAN_EXPONENT, QNAN_MANTISSA}; // qNaN
        fmt_special_status[fmt]    = '0;
        fmt_result_is_special[fmt] = 1'b0;

        // Handle potentially mixed nan & infinity input => important for the case where infinity and
        // zero are multiplied and added to a qNaN.
        // RISC-V mandates raising the NV exception in these cases:
        // (inf * 0) + c or (0 * inf) + c INVALID, no matter c (even quiet NaNs)
        if (any_produced_nan) begin
          fmt_result_is_special[fmt] = 1'b1; // bypass OP, output is the canonical qNaN
          fmt_special_status[fmt].NV = 1'b1; // invalid operation
        // NaN Inputs cause canonical quiet NaN at the output and maybe invalid OP
        end else if (any_operand_nan) begin
          fmt_result_is_special[fmt] = 1'b1;           // bypass OP, output is the canonical qNaN
          fmt_special_status[fmt].NV = signalling_nan; // raise the invalid operation flag if signalling
        // Special cases involving infinity
        end else if (any_operand_inf) begin
          fmt_result_is_special[fmt] = 1'b1; // bypass OP
          // Effective addition of opposite infinities (±inf - ±inf) is invalid!
          if (any_pos_inf && any_neg_inf) begin
            fmt_special_status[fmt].NV = 1'b1; // invalid operation
          // Handle cases where output will be inf because of inf product input
          end else if (any_pos_inf) begin
            // Result is infinity with the positive sign
            special_res = {1'b0, QNAN_EXPONENT, ZERO_MANTISSA};
          // Handle cases where the second product is inf
          end else if (any_neg_inf) begin
            // Result is infinity with the negative sign
            special_res = {1'b1, QNAN_EXPONENT, ZERO_MANTISSA};
          end
        end
        // Initialize special result with ones (NaN-box)
        fmt_special_result[fmt]               = '1;
        fmt_special_result[fmt][FP_WIDTH-1:0] = special_res;
      end
    end else begin : inactive_format
      assign fmt_special_result[fmt] = '{default: fpnew_pkg::DONT_CARE};
      assign fmt_special_status[fmt] = '0;
      assign fmt_result_is_special[fmt] = 1'b0;
    end
  end

  // Detect special case from source format
  assign result_is_special = fmt_result_is_special[dst_fmt_q];
  // Signalling input NaNs raise invalid flag, otherwise no flags set
  assign special_status = fmt_special_status[dst_fmt_q];
  // Assemble result according to destination format
  assign special_result = fmt_special_result[dst_fmt_q];

  // TEMPORARY: Assign special result to output
  assign result_o = special_result;
  assign out_valid_o = 1'b1;
endmodule
