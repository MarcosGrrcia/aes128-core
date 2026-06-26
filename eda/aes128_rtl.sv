`timescale 1ns/1ps

// All synthesizable RTL in one file, in dependency order, so it pastes
// into the EDA Playground design pane in one shot. The canonical
// per-module sources are in rtl/.

// AES forward S-box (FIPS-197). One byte in, the substituted byte out.
// Shared substitution primitive: SubBytes uses 16 of these, the key schedule
// uses 4. Maps to a 256x8 ROM/LUT.
module aes_sbox (
  input  logic [7:0] data_in,
  output logic [7:0] data_out
);

  localparam logic [7:0] SBOX [0:255] = '{
    8'h63, 8'h7c, 8'h77, 8'h7b, 8'hf2, 8'h6b, 8'h6f, 8'hc5,
    8'h30, 8'h01, 8'h67, 8'h2b, 8'hfe, 8'hd7, 8'hab, 8'h76,
    8'hca, 8'h82, 8'hc9, 8'h7d, 8'hfa, 8'h59, 8'h47, 8'hf0,
    8'had, 8'hd4, 8'ha2, 8'haf, 8'h9c, 8'ha4, 8'h72, 8'hc0,
    8'hb7, 8'hfd, 8'h93, 8'h26, 8'h36, 8'h3f, 8'hf7, 8'hcc,
    8'h34, 8'ha5, 8'he5, 8'hf1, 8'h71, 8'hd8, 8'h31, 8'h15,
    8'h04, 8'hc7, 8'h23, 8'hc3, 8'h18, 8'h96, 8'h05, 8'h9a,
    8'h07, 8'h12, 8'h80, 8'he2, 8'heb, 8'h27, 8'hb2, 8'h75,
    8'h09, 8'h83, 8'h2c, 8'h1a, 8'h1b, 8'h6e, 8'h5a, 8'ha0,
    8'h52, 8'h3b, 8'hd6, 8'hb3, 8'h29, 8'he3, 8'h2f, 8'h84,
    8'h53, 8'hd1, 8'h00, 8'hed, 8'h20, 8'hfc, 8'hb1, 8'h5b,
    8'h6a, 8'hcb, 8'hbe, 8'h39, 8'h4a, 8'h4c, 8'h58, 8'hcf,
    8'hd0, 8'hef, 8'haa, 8'hfb, 8'h43, 8'h4d, 8'h33, 8'h85,
    8'h45, 8'hf9, 8'h02, 8'h7f, 8'h50, 8'h3c, 8'h9f, 8'ha8,
    8'h51, 8'ha3, 8'h40, 8'h8f, 8'h92, 8'h9d, 8'h38, 8'hf5,
    8'hbc, 8'hb6, 8'hda, 8'h21, 8'h10, 8'hff, 8'hf3, 8'hd2,
    8'hcd, 8'h0c, 8'h13, 8'hec, 8'h5f, 8'h97, 8'h44, 8'h17,
    8'hc4, 8'ha7, 8'h7e, 8'h3d, 8'h64, 8'h5d, 8'h19, 8'h73,
    8'h60, 8'h81, 8'h4f, 8'hdc, 8'h22, 8'h2a, 8'h90, 8'h88,
    8'h46, 8'hee, 8'hb8, 8'h14, 8'hde, 8'h5e, 8'h0b, 8'hdb,
    8'he0, 8'h32, 8'h3a, 8'h0a, 8'h49, 8'h06, 8'h24, 8'h5c,
    8'hc2, 8'hd3, 8'hac, 8'h62, 8'h91, 8'h95, 8'he4, 8'h79,
    8'he7, 8'hc8, 8'h37, 8'h6d, 8'h8d, 8'hd5, 8'h4e, 8'ha9,
    8'h6c, 8'h56, 8'hf4, 8'hea, 8'h65, 8'h7a, 8'hae, 8'h08,
    8'hba, 8'h78, 8'h25, 8'h2e, 8'h1c, 8'ha6, 8'hb4, 8'hc6,
    8'he8, 8'hdd, 8'h74, 8'h1f, 8'h4b, 8'hbd, 8'h8b, 8'h8a,
    8'h70, 8'h3e, 8'hb5, 8'h66, 8'h48, 8'h03, 8'hf6, 8'h0e,
    8'h61, 8'h35, 8'h57, 8'hb9, 8'h86, 8'hc1, 8'h1d, 8'h9e,
    8'he1, 8'hf8, 8'h98, 8'h11, 8'h69, 8'hd9, 8'h8e, 8'h94,
    8'h9b, 8'h1e, 8'h87, 8'he9, 8'hce, 8'h55, 8'h28, 8'hdf,
    8'h8c, 8'ha1, 8'h89, 8'h0d, 8'hbf, 8'he6, 8'h42, 8'h68,
    8'h41, 8'h99, 8'h2d, 8'h0f, 8'hb0, 8'h54, 8'hbb, 8'h16
  };

  assign data_out = SBOX[data_in];

endmodule : aes_sbox

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

// AES-128 block encryption (FIPS-197).
//
// Iterative design: one round per clock, the state recirculates through a
// single register, and round keys are generated on the fly. A block takes 11
// clocks (one to load the input and add the first round key, then ten rounds)
// and only one block is in flight at a time.
//
// Control is just a round counter (0 = idle). Pulse start when busy is low to
// begin; done strobes for one cycle when ciphertext is valid. clear wipes the
// state, key and ciphertext registers and aborts a block in progress.
//
// Bytes are big-endian: plaintext[127:120] is byte 0 of the state.

module aes128_core (
  input  logic         clk,
  input  logic         rst,        // synchronous, active high
  input  logic         clear,      // wipe state and abort (priority over start)
  input  logic         start,      // pulse for one cycle while busy is low
  input  logic [127:0] plaintext,
  input  logic [127:0] key,
  output logic [127:0] ciphertext,
  output logic         busy,
  output logic         done        // one-cycle strobe when ciphertext is valid
);

  localparam int unsigned NUM_ROUNDS = 10;

  // Rcon[i] = x^i in GF(2^8); consumed by the key schedule.
  localparam logic [7:0] RCON [0:NUM_ROUNDS-1] = '{
    8'h01, 8'h02, 8'h04, 8'h08, 8'h10,
    8'h20, 8'h40, 8'h80, 8'h1b, 8'h36
  };

  // round == 0 is idle; 1 through NUM_ROUNDS (10) are the active rounds.
  logic [3:0]   round;
  logic [127:0] state_q;
  logic [127:0] key_q;

  assign busy = (round != 0);

  // Combinational round: the transforms are wired in series and the key
  // schedule runs alongside.
  logic [127:0] state_subbytes, state_shiftrows, state_mixcols, state_next;
  logic [127:0] round_key;
  logic [7:0]   round_const;

  assign round_const = RCON[(round == 0) ? 0 : round - 1];  // idle value unused

  aes_sub_bytes   u_sub_bytes   (.state_in (state_q),         .state_out (state_subbytes));
  aes_shift_rows  u_shift_rows  (.state_in (state_subbytes),  .state_out (state_shiftrows));
  aes_mix_columns u_mix_columns (.state_in (state_shiftrows), .state_out (state_mixcols));
  aes_key_expand  u_key_expand  (.key_in (key_q), .rcon (round_const), .key_out (round_key));

  // The final round skips MixColumns.
  assign state_next =
    ((round == 4'(NUM_ROUNDS)) ? state_shiftrows : state_mixcols) ^ round_key;

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      round      <= '0;
      state_q    <= '0;
      key_q      <= '0;
      ciphertext <= '0;
      done       <= 1'b0;
    end else begin
      done <= 1'b0;                       // default low; set for one cycle below
      if (round == 0) begin
        if (start) begin
          state_q <= plaintext ^ key;     // initial AddRoundKey
          key_q   <= key;
          round   <= 4'd1;
        end
      end else begin
        state_q <= state_next;
        key_q   <= round_key;
        if (round == 4'(NUM_ROUNDS)) begin
          ciphertext <= state_next;
          done       <= 1'b1;
          round      <= 4'd0;
        end else begin
          round <= round + 4'd1;
        end
      end
    end
  end

endmodule : aes128_core
