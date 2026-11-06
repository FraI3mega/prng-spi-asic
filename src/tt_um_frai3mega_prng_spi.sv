/*
 * Copyright (c) 2026 FraI3mega
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
module tt_um_frai3mega_prng_spi (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};
  assign uio_oe = 8'b00001000;  // Enable MISO
  assign {uio_out[7:4], uio_out[2:0]} = 8'b0;


  // Declare SPI connections
  wire CSn, MOSI, MISO, SCK;
  assign CSn  = uio_in[0];  // low when chip selected
  assign SCK  = uio_in[1];
  assign MOSI = uio_in[2];
  assign MISO = uio_out[3];


  (* async_reg = "true" *) logic [2:0] SCKr;
  always_ff @(posedge clk) SCKr <= {SCKr[1:0], SCK};
  logic SCK_risingedge = (SCKr[2:1] == 2'b01);  // now we can detect SCK rising edges
  logic SCK_fallingedge = (SCKr[2:1] == 2'b10);  // and falling edges


  (* async_reg = "true" *) logic [2:0] CSr;
  always_ff @(posedge clk) CSr <= {CSr[1:0], CSn};
  logic CS_active = ~CSr[1];
  logic CS_startmessage = CSr[2:1] == 2'b10;
  logic CS_endmessage = CSr[2:1] == 2'b01;

  (* async_reg = "true" *) logic [1:0] MOSIr;
  always_ff @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
  logic MOSI_data = MOSIr[1];


  // XORSHIFT
  logic [15:0] state;
  logic [15:0] initial_state;
  logic initialize;
  assign initialize = ~rst_n;

  xorshift16 xs16 (
      .initial_state(initial_state),
      .initialize   (initialize),
      .clk          (clk),
      .state        (state)
  );

endmodule
