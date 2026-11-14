module top_gowin (
    input wire clk,
    SCK,
    input logic MOSI,
    CS,
    output logic MISO,
    output logic [5:0] leds
);

  wire internal_15_6_mhz;

  OSC #(.FREQ_DIV(16)) u_osc (.OSCOUT(internal_15_6_mhz));

  assign leds = {1'b1, MISO, MOSI, SCK, CS, internal_15_6_mhz};
  logic [7:0] uio_in, uio_out;
  assign uio_in = {5'b0, MOSI, SCK, CS};
  assign MISO   = uio_out[3];

  tt_um_frai3mega_prng_spi tt_um_frai3mega_prng_spi (
      .uio_in (uio_in),
      .uio_out(uio_out),
      .clk    (internal_15_6_mhz),
      .rst_n  (1'b1)
  );

endmodule
