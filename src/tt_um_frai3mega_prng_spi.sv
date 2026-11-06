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
  wire _unused = &{ena, ui_in, 1'b0};
  assign uo_out = 8'b0;
  assign uio_oe = 8'b00001000;  // Enable MISO
  assign {uio_out[7:4], uio_out[2:0]} = 7'b0;


  // Declare SPI connections
  wire CSn, MOSI, MISO, SCK;
  assign CSn = uio_in[0];  // low when chip selected
  assign SCK = uio_in[1];
  assign MOSI = uio_in[2];
  assign uio_out[3] = MISO;


  (* async_reg = "true" *) logic [2:0] SCKr;
  always_ff @(posedge clk) SCKr <= {SCKr[1:0], SCK};
  wire SCK_risingedge = (SCKr[2:1] == 2'b01);  // now we can detect SCK rising edges
  wire SCK_fallingedge = (SCKr[2:1] == 2'b10);  // and falling edges


  (* async_reg = "true" *) logic [2:0] CSr;
  always_ff @(posedge clk) CSr <= {CSr[1:0], CSn};
  wire CS_active = ~CSr[1];
  wire CS_startmessage = CSr[2:1] == 2'b10;
  wire CS_endmessage = CSr[2:1] == 2'b01;

  (* async_reg = "true" *) logic [1:0] MOSIr;
  always_ff @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
  wire MOSI_data = MOSIr[1];


  logic [2:0] bitcnt;  // SPI in 8-bit format

  logic byte_received;
  logic [7:0] byte_data_received;

  always_ff @(posedge clk) begin
    if (~rst_n) bitcnt <= 3'b0;
    else if (~CS_active) begin
      bitcnt <= 3'b000;
    end else if (SCK_risingedge) begin
      bitcnt <= bitcnt + 3'b001;

      byte_data_received <= {byte_data_received[6:0], MOSI_data};
    end
  end


  always_ff @(posedge clk) begin
    if (~rst_n) byte_received <= 0;
    else byte_received <= CS_active && SCK_risingedge && (bitcnt == 3'b111);
  end

  // XORSHIFT
  logic [15:0] state;
  logic [15:0] initial_state;
  logic initialize;


  xorshift16 xs16 (
      .initial_state(initial_state),
      .initialize   (initialize || ~rst_n),
      .clk          (clk),
      .step         (byte_received),
      .state        (state)
  );

  //SEND
  logic [15:0] data_to_send;
  logic [ 7:0] byte_data_sent;

  always_ff @(posedge clk)
    if (~rst_n) begin
      data_to_send <= 16'b0;
      byte_data_sent <= 8'b0;
      initialize <= 1;
      initial_state <= 16'hAAAA;
    end else if (byte_received) begin
      case (byte_data_received)
        8'h01:   data_to_send <= 16'hAA00;
        8'h03:   data_to_send <= state;
        default: ;
      endcase
    end else if (CS_active) begin
      if (SCK_fallingedge) begin
        if (bitcnt == 3'b000) begin
          byte_data_sent <= data_to_send[15:8];  // after that, we send 0s
          data_to_send   <= data_to_send << 8;
        end else byte_data_sent <= {byte_data_sent[6:0], 1'b0};
      end
    end else if (CS_endmessage) begin
      byte_data_sent <= 8'b0;
      data_to_send <= 16'b0;
      initialize <= 0;
    end

  assign MISO = byte_data_sent[7];



endmodule
