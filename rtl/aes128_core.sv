`timescale 1ns/1ps

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
