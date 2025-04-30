force -freeze {sim:/tb_fpnew_mxdotp_multi/operands_a_i[3]} 8'h0 0
force -freeze {sim:/tb_fpnew_mxdotp_multi/operands_a_i[2]} 8'h0 0
force -freeze {sim:/tb_fpnew_mxdotp_multi/operands_a_i[1]} 8'h0 0
force -freeze {sim:/tb_fpnew_mxdotp_multi/dut/operands_a_i[0]} 8'h3c 0
force -freeze {sim:/tb_fpnew_mxdotp_multi/dut/operands_b_i[0]} 8'hbc 0
force -freeze sim:/tb_fpnew_mxdotp_multi/dut/operand_c_i 8'd127 0
force -freeze sim:/tb_fpnew_mxdotp_multi/dut/operand_d_i 32'h3f800000 0
force -freeze sim:/tb_fpnew_mxdotp_multi/dut/in_valid_i 1'h1 0
run 10ns
force -freeze sim:/tb_fpnew_mxdotp_multi/dut/in_valid_i 1'h0 0
