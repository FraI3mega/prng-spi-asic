/*
 * Copyright (c) 2026 FraI3mega
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module xorshift16 (
    input logic [15:0] initial_state,
    input wire initialize,
    input wire clk,
    input logic step,
    output logic [15:0] state
);

  always @(posedge clk) begin
    if (initialize) begin
      state <= initial_state;
    end else if (step) begin
      logic [15:0] next_state;
      next_state = state;
      next_state ^= next_state << 7;
      next_state ^= next_state >> 9;
      next_state ^= next_state << 8;
      state <= next_state;
    end
  end

endmodule
