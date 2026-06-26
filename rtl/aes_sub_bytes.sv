`timescale 1ns/1ps

// SubBytes: run all 16 state bytes through the S-box in parallel.
// Byte i occupies bits [127-8*i -: 8].
module aes_sub_bytes (
  input  logic [127:0] state_in,
  output logic [127:0] state_out
);

  for (genvar i = 0; i < 16; i++) begin : g_sbox
    aes_sbox u_sbox (
      .data_in  (state_in[127 - 8*i -: 8]),
      .data_out (state_out[127 - 8*i -: 8])
    );
  end

endmodule : aes_sub_bytes
