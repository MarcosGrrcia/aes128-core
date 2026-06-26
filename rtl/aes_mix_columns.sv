`timescale 1ns/1ps

// MixColumns: multiply each state column by the fixed AES matrix over GF(2^8).
module aes_mix_columns (
  input  logic [127:0] state_in,
  output logic [127:0] state_out
);

  // Multiply by 2 in GF(2^8) (reduction polynomial 0x11b).
  function automatic logic [7:0] xtime(input logic [7:0] b);
    return {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
  endfunction

  always_comb begin
    logic [7:0] a0, a1, a2, a3;        // column bytes
    logic [7:0] x0, x1, x2, x3;        // their xtime() products (computed once)
    for (int col = 0; col < 4; col++) begin
      a0 = state_in[127 - 8*(4*col + 0) -: 8];
      a1 = state_in[127 - 8*(4*col + 1) -: 8];
      a2 = state_in[127 - 8*(4*col + 2) -: 8];
      a3 = state_in[127 - 8*(4*col + 3) -: 8];
      x0 = xtime(a0);
      x1 = xtime(a1);
      x2 = xtime(a2);
      x3 = xtime(a3);
      // out = 2*a0 + 3*a1 + a2 + a3, etc. (3*x = xtime(x) ^ x), all in GF(2^8)
      state_out[127 - 8*(4*col + 0) -: 8] =  x0       ^ (x1 ^ a1) ^  a2        ^  a3;
      state_out[127 - 8*(4*col + 1) -: 8] =  a0       ^  x1       ^ (x2 ^ a2)  ^  a3;
      state_out[127 - 8*(4*col + 2) -: 8] =  a0       ^  a1       ^  x2        ^ (x3 ^ a3);
      state_out[127 - 8*(4*col + 3) -: 8] = (x0 ^ a0) ^  a1       ^  a2        ^  x3;
    end
  end

endmodule : aes_mix_columns
