`timescale 1ns/1ps

// ShiftRows rotates row r of the state left by r bytes, so row 0 is unchanged,
// row 1 moves left by one, and so on. Bytes are stored column-major, so byte i
// sits at row i%4, column i/4. That makes it a fixed byte permutation, written
// out below and grouped by output column.
module aes_shift_rows (
  input  logic [127:0] state_in,
  output logic [127:0] state_out
);

  // Name the 16 state bytes, big-endian: byte 0 is state_in[127:120].
  logic [7:0] b [0:15];
  always_comb begin
    for (int i = 0; i < 16; i++) b[i] = state_in[127 - 8*i -: 8];

    // Row 0 stays put, row 1 shifts left 1, row 2 by 2, row 3 by 3.
    state_out = {b[0],  b[5],  b[10], b[15],    // column 0
                 b[4],  b[9],  b[14], b[3],     // column 1
                 b[8],  b[13], b[2],  b[7],     // column 2
                 b[12], b[1],  b[6],  b[11]};   // column 3
  end

endmodule : aes_shift_rows
