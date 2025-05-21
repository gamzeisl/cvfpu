# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

SHELL = /usr/bin/env bash
ROOT_DIR := $(patsubst %/,%, $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

INSTALL_PREFIX       ?= install
INSTALL_DIR           = ${ROOT_DIR}/${INSTALL_PREFIX}
BENDER_INSTALL_DIR    = ${INSTALL_DIR}/bender
STIM_DIR			 ?= ${ROOT_DIR}/../../mx_fp/testvectors

VENV_BIN=venv/bin/

BENDER_VERSION = 0.28.1
SIM_PATH   ?= sim/build

BENDER_TARGETS = -t tb

target ?= tb_fpnew_mxdotp_multi
ALL_FORMATS := FP8 FP8ALT FP6 FP6ALT FP4
enabled_formats ?= FP8 FP8ALT FP6 FP6ALT FP4

src_fmt ?= FP8
dst_fmt ?= FP32
vector_size ?= 8
num_pipe_regs ?= 3
prob_stall ?= 10 # 10% stall probability
num_vectors ?= 100
stim_file ?= test_data_${src_fmt}_${dst_fmt}_${num_vectors}.csv

vlog_defs := $(foreach fmt,$(ALL_FORMATS), \
  -DEN_$(fmt)=$(if $(filter $(fmt),$(enabled_formats)),1,0) )
vlog_defs += -DSTIM_FILE="\"$(STIM_DIR)/$(stim_file)\"" -DSRC_FMT="\"$(src_fmt)\"" -DDST_FMT="\"$(dst_fmt)\"" -DVECTOR_SIZE=$(vector_size) -DNUM_PIPE_REGS=$(num_pipe_regs) -DPROB_STALL=$(prob_stall) -DNUM_VECTORS=$(num_vectors)

VLOG_FLAGS += -svinputport=compat
VLOG_FLAGS += -timescale 1ns/1ps

.PHONY: clean-sim sim-script sim
all: sim

clean-sim:
	rm -rf $(SIM_PATH)/work
	rm -rf $(SIM_PATH)/compile.tcl
	rm -rf $(SIM_PATH)/wlft*
	rm -rf $(SIM_PATH)/transcript
	rm -rf $(SIM_PATH)/modelsim.ini
	rm -rf $(SIM_PATH)/vsim.wlf

sim-script: clean-sim bender
	mkdir -p $(SIM_PATH)
	$(BENDER_INSTALL_DIR)/bender script vsim $(BENDER_TARGETS) $(vlog_defs) --vlog-arg="$(VLOG_FLAGS)" >> $(SIM_PATH)/compile.tcl

sim: sim-script
	cd sim && \
	$(MAKE) $(target)

# Bender
bender: check-bender
	$(BENDER_INSTALL_DIR)/bender update
	$(BENDER_INSTALL_DIR)/bender vendor init

check-bender:
	@if [ -x $(BENDER_INSTALL_DIR)/bender ]; then \
		req="bender $(BENDER_VERSION)"; \
		current="$$($(BENDER_INSTALL_DIR)/bender --version)"; \
		if [ "$$(printf '%s\n' "$${req}" "$${current}" | sort -V | head -n1)" != "$${req}" ]; then \
			rm -rf $(BENDER_INSTALL_DIR); \
		fi \
	fi
	@$(MAKE) -C $(ROOT_DIR) $(BENDER_INSTALL_DIR)/bender

$(BENDER_INSTALL_DIR)/bender:
	mkdir -p $(BENDER_INSTALL_DIR) && cd $(BENDER_INSTALL_DIR) && \
	curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh -s -- $(BENDER_VERSION)