// Behavioral AES-128 reference model, the scoreboard oracle.
// Package-scope params/functions, independent of the RTL.
/* AES CODE BEGIN model */
localparam bit [7:0] REF_SBOX [0:255] = '{
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

localparam bit [7:0] REF_RCON [0:9] = '{
  8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80, 8'h1b, 8'h36
};

function automatic bit [7:0] ref_xtime(input bit [7:0] b);
  return (b << 1) ^ (b[7] ? 8'h1b : 8'h00);
endfunction

// advance rk (16 bytes = 4 words) to the next round key, in place
function automatic void ref_next_key(ref bit [7:0] rk [0:15], input bit [7:0] rc);
  bit [7:0] t0, t1, t2, t3;
  t0 = REF_SBOX[rk[13]] ^ rc;
  t1 = REF_SBOX[rk[14]];
  t2 = REF_SBOX[rk[15]];
  t3 = REF_SBOX[rk[12]];
  rk[0]  ^= t0;    rk[1]  ^= t1;    rk[2]  ^= t2;    rk[3]  ^= t3;
  rk[4]  ^= rk[0]; rk[5]  ^= rk[1]; rk[6]  ^= rk[2]; rk[7]  ^= rk[3];
  rk[8]  ^= rk[4]; rk[9]  ^= rk[5]; rk[10] ^= rk[6]; rk[11] ^= rk[7];
  rk[12] ^= rk[8]; rk[13] ^= rk[9]; rk[14] ^= rk[10]; rk[15] ^= rk[11];
endfunction

// Each AES step as a named operation on the 16-byte state, so the round loop
// in aes128_model below reads like the FIPS-197 spec.
function automatic void ref_sub_bytes(ref bit [7:0] s [0:15]);
  for (int i = 0; i < 16; i++) s[i] = REF_SBOX[s[i]];
endfunction

function automatic void ref_shift_rows(ref bit [7:0] s [0:15]);
  bit [7:0] t [0:15];
  t = '{s[0],  s[5],  s[10], s[15],   // column 0  (row r rotates left by r)
        s[4],  s[9],  s[14], s[3],    // column 1
        s[8],  s[13], s[2],  s[7],    // column 2
        s[12], s[1],  s[6],  s[11]};  // column 3
  s = t;
endfunction

function automatic void ref_mix_columns(ref bit [7:0] s [0:15]);
  bit [7:0] t [0:15], a0, a1, a2, a3;
  for (int col = 0; col < 4; col++) begin
    a0 = s[4*col+0]; a1 = s[4*col+1]; a2 = s[4*col+2]; a3 = s[4*col+3];
    t[4*col+0] = ref_xtime(a0) ^ (ref_xtime(a1) ^ a1) ^ a2 ^ a3;
    t[4*col+1] = a0 ^ ref_xtime(a1) ^ (ref_xtime(a2) ^ a2) ^ a3;
    t[4*col+2] = a0 ^ a1 ^ ref_xtime(a2) ^ (ref_xtime(a3) ^ a3);
    t[4*col+3] = (ref_xtime(a0) ^ a0) ^ a1 ^ a2 ^ ref_xtime(a3);
  end
  s = t;
endfunction

function automatic void ref_add_round_key(ref bit [7:0] s [0:15],
                                          input bit [7:0] rk [0:15]);
  for (int i = 0; i < 16; i++) s[i] ^= rk[i];
endfunction

function automatic bit [127:0] aes128_model(input bit [127:0] key, pt);
  bit [7:0] s  [0:15];   // state, byte i is plaintext[127 - 8*i -: 8]
  bit [7:0] rk [0:15];   // running round key, starts as the cipher key
  bit [127:0] ct;
  for (int i = 0; i < 16; i++) begin
    s[i]  = pt [127 - 8*i -: 8];
    rk[i] = key[127 - 8*i -: 8];
  end

  ref_add_round_key(s, rk);                // initial AddRoundKey (round 0)
  for (int r = 1; r <= 10; r++) begin
    ref_next_key(rk, REF_RCON[r-1]);       // round key for round r
    ref_sub_bytes(s);
    ref_shift_rows(s);
    if (r != 10) ref_mix_columns(s);       // the final round skips MixColumns
    ref_add_round_key(s, rk);
  end

  for (int i = 0; i < 16; i++) ct[127 - 8*i -: 8] = s[i];
  return ct;
endfunction
/* AES CODE END model */
