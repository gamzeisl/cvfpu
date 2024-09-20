onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_fpnew_sdotp_scale_multi/clk_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/rst_ni
add wave -noupdate -radix binary -childformat {{{/tb_fpnew_sdotp_scale_multi/operands_a_i[3]} -radix binary} {{/tb_fpnew_sdotp_scale_multi/operands_a_i[2]} -radix binary} {{/tb_fpnew_sdotp_scale_multi/operands_a_i[1]} -radix binary} {{/tb_fpnew_sdotp_scale_multi/operands_a_i[0]} -radix binary}} -expand -subitemconfig {{/tb_fpnew_sdotp_scale_multi/operands_a_i[3]} {-height 17 -radix binary} {/tb_fpnew_sdotp_scale_multi/operands_a_i[2]} {-height 17 -radix binary} {/tb_fpnew_sdotp_scale_multi/operands_a_i[1]} {-height 17 -radix binary} {/tb_fpnew_sdotp_scale_multi/operands_a_i[0]} {-height 17 -radix binary}} /tb_fpnew_sdotp_scale_multi/operands_a_i
add wave -noupdate -radix binary -childformat {{{/tb_fpnew_sdotp_scale_multi/operands_b_i[3]} -radix binary} {{/tb_fpnew_sdotp_scale_multi/operands_b_i[2]} -radix binary} {{/tb_fpnew_sdotp_scale_multi/operands_b_i[1]} -radix binary} {{/tb_fpnew_sdotp_scale_multi/operands_b_i[0]} -radix binary}} -expand -subitemconfig {{/tb_fpnew_sdotp_scale_multi/operands_b_i[3]} {-height 17 -radix binary} {/tb_fpnew_sdotp_scale_multi/operands_b_i[2]} {-height 17 -radix binary} {/tb_fpnew_sdotp_scale_multi/operands_b_i[1]} {-height 17 -radix binary} {/tb_fpnew_sdotp_scale_multi/operands_b_i[0]} {-height 17 -radix binary}} /tb_fpnew_sdotp_scale_multi/operands_b_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/operand_c_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/operand_d_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/is_boxed_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/rnd_mode_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/op_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/op_mod_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/src_fmt_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dst_fmt_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/tag_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/mask_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/aux_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/in_valid_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/flush_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/out_ready_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/result_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/status_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/extension_bit_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/tag_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/mask_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/aux_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/in_ready_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/out_valid_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/busy_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/file
add wave -noupdate /tb_fpnew_sdotp_scale_multi/r
add wave -noupdate /tb_fpnew_sdotp_scale_multi/expected_result
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/clk_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/rst_ni
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operands_a_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operands_b_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operand_c_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operand_d_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/is_boxed_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/rnd_mode_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/op_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/op_mod_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/src_fmt_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/dst_fmt_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/tag_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/mask_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/aux_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/in_valid_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/in_ready_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/flush_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/result_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/status_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/extension_bit_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/tag_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/mask_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/aux_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/out_valid_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/out_ready_i
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/busy_o
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operands_a_q
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operands_b_q
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operand_c_q
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operand_d_q
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/src_fmt_q
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/dst_fmt_q
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operands_post_inp_pipe
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/fmt_sign
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/fmt_exponent
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/fmt_mantissa
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/info_q
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/fmt_dst_sign
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/fmt_dst_exponent
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/fmt_dst_mantissa
add wave -noupdate -radix unsigned -childformat {{{/tb_fpnew_sdotp_scale_multi/dut/operands_a[3]} -radix unsigned} {{/tb_fpnew_sdotp_scale_multi/dut/operands_a[2]} -radix unsigned} {{/tb_fpnew_sdotp_scale_multi/dut/operands_a[1]} -radix unsigned} {{/tb_fpnew_sdotp_scale_multi/dut/operands_a[0]} -radix unsigned}} -expand -subitemconfig {{/tb_fpnew_sdotp_scale_multi/dut/operands_a[3]} {-height 17 -radix unsigned} {/tb_fpnew_sdotp_scale_multi/dut/operands_a[2]} {-height 17 -radix unsigned} {/tb_fpnew_sdotp_scale_multi/dut/operands_a[1]} {-height 17 -radix unsigned} {/tb_fpnew_sdotp_scale_multi/dut/operands_a[0]} {-height 17 -radix unsigned}} /tb_fpnew_sdotp_scale_multi/dut/operands_a
add wave -noupdate -radix unsigned -childformat {{{/tb_fpnew_sdotp_scale_multi/dut/operands_b[3]} -radix unsigned} {{/tb_fpnew_sdotp_scale_multi/dut/operands_b[2]} -radix unsigned} {{/tb_fpnew_sdotp_scale_multi/dut/operands_b[1]} -radix unsigned} {{/tb_fpnew_sdotp_scale_multi/dut/operands_b[0]} -radix unsigned}} -expand -subitemconfig {{/tb_fpnew_sdotp_scale_multi/dut/operands_b[3]} {-height 17 -radix unsigned} {/tb_fpnew_sdotp_scale_multi/dut/operands_b[2]} {-height 17 -radix unsigned} {/tb_fpnew_sdotp_scale_multi/dut/operands_b[1]} {-height 17 -radix unsigned} {/tb_fpnew_sdotp_scale_multi/dut/operands_b[0]} {-height 17 -radix unsigned}} /tb_fpnew_sdotp_scale_multi/dut/operands_b
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/info_a
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/info_b
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/info_c
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/info_d
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/any_operand_inf
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/any_operand_nan
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/signalling_nan
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/any_produced_nan
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/any_pos_inf
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/any_neg_inf
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operand_inf_conditions
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/operand_nan_conditions
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/signalling_nan_conditions
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/nan_conditions
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/pos_inf_conditions
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/neg_inf_conditions
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/special_result
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/special_status
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/result_is_special
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/fmt_special_result
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/fmt_special_status
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/fmt_result_is_special
add wave -noupdate -radix unsigned /tb_fpnew_sdotp_scale_multi/dut/mantissa_a
add wave -noupdate -radix unsigned /tb_fpnew_sdotp_scale_multi/dut/mantissa_b
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/product
add wave -noupdate -radix decimal /tb_fpnew_sdotp_scale_multi/dut/product_signed
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/exponent_product
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/shifted_product
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/sum_product
add wave -noupdate -radix decimal /tb_fpnew_sdotp_scale_multi/dut/operand_c
add wave -noupdate -childformat {{/tb_fpnew_sdotp_scale_multi/dut/operand_d.exponent -radix unsigned}} -expand -subitemconfig {/tb_fpnew_sdotp_scale_multi/dut/operand_d.exponent {-height 17 -radix unsigned}} /tb_fpnew_sdotp_scale_multi/dut/operand_d
add wave -noupdate -radix decimal /tb_fpnew_sdotp_scale_multi/dut/accumulator_shift_amount
add wave -noupdate -radix decimal /tb_fpnew_sdotp_scale_multi/shift_acc
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/accumulator_shifted
add wave -noupdate /tb_fpnew_sdotp_scale_multi/shifted_acc
add wave -noupdate /tb_fpnew_sdotp_scale_multi/dut/sum_product_accumulator
add wave -noupdate /tb_fpnew_sdotp_scale_multi/sum_prod_acc
add wave -noupdate {/tb_fpnew_sdotp_scale_multi/dut/gen_special_results[0]/active_format/special_cases/special_res}
add wave -noupdate {/tb_fpnew_sdotp_scale_multi/dut/fmt_dst_init_inputs[0]/active_dst_format/trimmed_dst_ops}
add wave -noupdate {/tb_fpnew_sdotp_scale_multi/dut/fmt_dst_init_inputs[0]/active_dst_format/dst_ops_is_boxed}
add wave -noupdate {/tb_fpnew_sdotp_scale_multi/dut/fmt_dst_init_inputs[0]/active_dst_format/i_fpnew_classifier/operands_i}
add wave -noupdate {/tb_fpnew_sdotp_scale_multi/dut/fmt_dst_init_inputs[0]/active_dst_format/i_fpnew_classifier/is_boxed_i}
add wave -noupdate {/tb_fpnew_sdotp_scale_multi/dut/fmt_dst_init_inputs[0]/active_dst_format/i_fpnew_classifier/info_o}
add wave -noupdate {/tb_fpnew_sdotp_scale_multi/dut/fmt_dst_init_inputs[0]/active_dst_format/i_fpnew_classifier/gen_num_values[0]/value}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {43887 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {30142 ps} {64630 ps}
