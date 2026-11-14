VERILOG_SOURCES := $(wildcard *.v) $(wildcard *.sv)
GOWIN_BOARD ?= tang_nano_20k
GOWIN_DEVICE ?= GW2AR-LV18QN88C8/I7
GOWIN_FAMILY ?= GW2A-18C
GOWIN_FAMILY_YOSYS ?= gw2a

design_gowin.json: $(VERILOG_SOURCES)
	yosys -p "read_verilog -sv $(VERILOG_SOURCES); synth_gowin -family $(GOWIN_FAMILY_YOSYS) -top top_gowin -json design_gowin.json"

pnr_gowin.json: design_gowin.json $(GOWIN_BOARD).cst
	nextpnr-himbaechel --json design_gowin.json \
                   --write pnr_gowin.json \
                   --device $(GOWIN_DEVICE) \
                   --vopt family=$(GOWIN_FAMILY) \
                   --vopt cst=$(GOWIN_BOARD).cst

gowin.fs: pnr_gowin.json
	gowin_pack --device $(GOWIN_FAMILY) pnr_gowin.json --compress --output gowin.fs

build: gowin.fs

debug: build
	openFPGALoader -b tangnano20k gowin.fs

install: build
	openFPGALoader -b tangnano20k gowin.fs -f

lint: $(VERILOG_SOURCES)
	verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-WIDTHEXPAND $(VERILOG_SOURCES)
