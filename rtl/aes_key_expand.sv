`timescale 1ns/1ps

// One step of the AES-128 key schedule: next round key from the current one.
//   temp   = SubWord(RotWord(w3)) ^ Rcon
//   new_wi = wi ^ (i == 0 ? temp : new_w(i-1))
// SubWord reuses the same S-box as SubBytes.
module aes_key_expand (
  input  logic [127:0] key_in,
  input  logic [7:0]   rcon,
  output logic [127:0] key_out
);

  // Split the key into its four 32-bit words (w0 = most significant).
  logic [31:0] w0, w1, w2, w3;
  assign {w0, w1, w2, w3} = key_in;

  // SubWord(RotWord(w3)): RotWord rotates the word left one byte, then each
  // byte is passed through the S-box.
  logic [7:0] sub0, sub1, sub2, sub3;
  aes_sbox u_sub0 (.data_in (w3[23:16]), .data_out (sub0));
  aes_sbox u_sub1 (.data_in (w3[15: 8]), .data_out (sub1));
  aes_sbox u_sub2 (.data_in (w3[ 7: 0]), .data_out (sub2));
  aes_sbox u_sub3 (.data_in (w3[31:24]), .data_out (sub3));

  logic [31:0] temp;
  assign temp = {sub0, sub1, sub2, sub3} ^ {rcon, 24'h00_0000};

  logic [31:0] new_w0, new_w1, new_w2, new_w3;
  assign new_w0 = w0 ^ temp;
  assign new_w1 = w1 ^ new_w0;
  assign new_w2 = w2 ^ new_w1;
  assign new_w3 = w3 ^ new_w2;

  assign key_out = {new_w0, new_w1, new_w2, new_w3};

endmodule : aes_key_expand
