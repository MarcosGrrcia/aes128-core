`timescale 1ns/1ps

// UVM testbench for aes128_core, a single-file mirror for EDA Playground. The
// canonical one-class-per-file version is in tb/uvm/; this is the same
// environment combined into one file for EDA Playground's editor.
// One environment serves multiple tests, selected at run time with
// +UVM_TESTNAME (no recompile):
//
//   aes_directed_test  five known-answer vectors (FIPS-197 C.1, two SP 800-38A,
//                      plus all-zero and all-ones)
//   aes_random_test    constrained-random key/plaintext blocks
//
// The scoreboard does not carry golden values. It predicts the expected
// ciphertext with a behavioral AES-128 reference model, so it can check any
// stimulus, random included. The model is independent of the RTL and matches
// the published vectors.
//
// Needs a UVM-capable simulator (Questa/VCS/Xcelium/Riviera).
//
// Blocks wrapped in /* AES CODE BEGIN x */ and /* AES CODE END x */ are the
// AES-specific parts. Everything else is stock UVM skeleton.

interface aes_if (input logic clk);
  /* AES CODE BEGIN pins */
  logic         rst;
  logic         clear;
  logic         start;
  logic         busy;
  logic         done;
  logic [127:0] plaintext;
  logic [127:0] key;
  logic [127:0] ciphertext;
  /* AES CODE END pins */
endinterface : aes_if


package aes_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ------------------------------------------------------------------------
  // Behavioral AES-128 reference model (scoreboard oracle)
  // ------------------------------------------------------------------------
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

  // ------------------------------------------------------------------------
  // Transaction
  // ------------------------------------------------------------------------
  class aes_seq_item extends uvm_sequence_item;
    /* AES CODE BEGIN fields */
    rand bit [127:0] key;
    rand bit [127:0] plaintext;
    bit [127:0]      ciphertext;   // observed (filled by monitor)
    /* AES CODE END fields */

    `uvm_object_utils(aes_seq_item)

    function new(string name = "aes_seq_item");
      super.new(name);
    endfunction
  endclass : aes_seq_item

  typedef uvm_sequencer #(aes_seq_item) aes_sequencer;

  // ------------------------------------------------------------------------
  // Driver: pulses start while busy is low, then waits for done.
  // ------------------------------------------------------------------------
  class aes_driver extends uvm_driver #(aes_seq_item);
    `uvm_component_utils(aes_driver)

    virtual aes_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual aes_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "virtual interface not set for driver")
    endfunction

    task run_phase(uvm_phase phase);
      vif.start     <= 1'b0;
      vif.plaintext <= '0;
      vif.key       <= '0;
      forever begin
        seq_item_port.get_next_item(req);
        drive(req);
        seq_item_port.item_done();
      end
    endtask

    /* AES CODE BEGIN handshake */
    task drive(aes_seq_item tr);
      do @(posedge vif.clk); while (vif.rst || vif.busy);
      vif.plaintext <= tr.plaintext;
      vif.key       <= tr.key;
      vif.start     <= 1'b1;
      @(posedge vif.clk);
      vif.start     <= 1'b0;
      do @(posedge vif.clk); while (!vif.done);
      `uvm_info("DRV", $sformatf("key=%032h plain=%032h", tr.key, tr.plaintext),
                UVM_HIGH)
    endtask
    /* AES CODE END handshake */
  endclass : aes_driver

  // ------------------------------------------------------------------------
  // Monitor: at done, samples the inputs and ciphertext into one transaction.
  // ------------------------------------------------------------------------
  class aes_monitor extends uvm_monitor;
    `uvm_component_utils(aes_monitor)

    virtual aes_if vif;
    uvm_analysis_port #(aes_seq_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual aes_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "virtual interface not set for monitor")
    endfunction

    task run_phase(uvm_phase phase);
      /* AES CODE BEGIN sample */
      forever begin
        @(posedge vif.clk);
        if (vif.done) begin
          aes_seq_item tr = aes_seq_item::type_id::create("mon_tr");
          tr.key        = vif.key;
          tr.plaintext  = vif.plaintext;
          tr.ciphertext = vif.ciphertext;
          ap.write(tr);
        end
      end
      /* AES CODE END sample */
    endtask
  endclass : aes_monitor

  // ------------------------------------------------------------------------
  // Scoreboard: predicts with the reference model, compares to the DUT.
  // ------------------------------------------------------------------------
  class aes_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(aes_scoreboard)

    uvm_analysis_imp #(aes_seq_item, aes_scoreboard) ap_imp;
    int unsigned num_passed;
    int unsigned num_failed;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap_imp = new("ap_imp", this);
    endfunction

    /* AES CODE BEGIN check */
    function void write(aes_seq_item t);
      bit [127:0] expected = aes128_model(t.key, t.plaintext);
      if (t.ciphertext === expected) begin
        num_passed++;
        `uvm_info("SCB", $sformatf("PASS cipher=%032h", t.ciphertext), UVM_LOW)
      end else begin
        num_failed++;
        `uvm_error("SCB", $sformatf("MISMATCH expected=%032h actual=%032h",
                                    expected, t.ciphertext))
      end
    endfunction
    /* AES CODE END check */

    function void report_phase(uvm_phase phase);
      `uvm_info("SCB", $sformatf("DONE: %0d passed, %0d failed",
                                 num_passed, num_failed), UVM_NONE)
      if (num_failed != 0 || num_passed == 0)
        `uvm_error("SCB", "test did not pass cleanly")
    endfunction
  endclass : aes_scoreboard

  // ------------------------------------------------------------------------
  // Environment
  // ------------------------------------------------------------------------
  class aes_env extends uvm_env;
    `uvm_component_utils(aes_env)

    aes_sequencer  sequencer;
    aes_driver     driver;
    aes_monitor    monitor;
    aes_scoreboard scoreboard;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer  = aes_sequencer ::type_id::create("sequencer",  this);
      driver     = aes_driver    ::type_id::create("driver",     this);
      monitor    = aes_monitor   ::type_id::create("monitor",    this);
      scoreboard = aes_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      monitor.ap.connect(scoreboard.ap_imp);
    endfunction
  endclass : aes_env

  // ------------------------------------------------------------------------
  // Sequences
  // ------------------------------------------------------------------------
  // Directed: fixed known-answer input pairs.
  class aes_directed_seq extends uvm_sequence #(aes_seq_item);
    `uvm_object_utils(aes_directed_seq)
    function new(string name = "aes_directed_seq"); super.new(name); endfunction

    task body();
      /* AES CODE BEGIN vectors */
      bit [127:0] keys   [5];
      bit [127:0] plains [5];
      keys[0]   = '0;
      plains[0] = '0;
      keys[1]   = '1;
      plains[1] = '1;
      keys[2]   = 128'h000102030405060708090a0b0c0d0e0f;
      plains[2] = 128'h00112233445566778899aabbccddeeff;
      keys[3]   = 128'h2b7e151628aed2a6abf7158809cf4f3c;
      plains[3] = 128'h6bc1bee22e409f96e93d7e117393172a;
      keys[4]   = 128'h2b7e151628aed2a6abf7158809cf4f3c;
      plains[4] = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
      foreach (keys[i]) begin
        aes_seq_item item = aes_seq_item::type_id::create($sformatf("dir_%0d", i));
        start_item(item);
        item.key       = keys[i];
        item.plaintext = plains[i];
        finish_item(item);
      end
      /* AES CODE END vectors */
    endtask
  endclass : aes_directed_seq

  // Random: n blocks with random key and plaintext. Add constraints in the
  // item (or an extended sequence) to bias coverage.
  class aes_random_seq extends uvm_sequence #(aes_seq_item);
    `uvm_object_utils(aes_random_seq)
    int unsigned n = 20;
    function new(string name = "aes_random_seq"); super.new(name); endfunction

    task body();
      /* AES CODE BEGIN random */
      repeat (n) begin
        aes_seq_item item = aes_seq_item::type_id::create("rnd");
        start_item(item);
        if (!item.randomize())
          `uvm_error("SEQ", "randomize failed")
        finish_item(item);
      end
      /* AES CODE END random */
    endtask
  endclass : aes_random_seq

  // ------------------------------------------------------------------------
  // Tests: one environment, selected at run time with +UVM_TESTNAME.
  // ------------------------------------------------------------------------
  class aes_base_test extends uvm_test;
    `uvm_component_utils(aes_base_test)
    aes_env env;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = aes_env::type_id::create("env", this);
    endfunction
  endclass : aes_base_test

  class aes_directed_test extends aes_base_test;
    `uvm_component_utils(aes_directed_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      aes_directed_seq seq = aes_directed_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.sequencer);
      phase.drop_objection(this);
    endtask
  endclass : aes_directed_test

  class aes_random_test extends aes_base_test;
    `uvm_component_utils(aes_random_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      aes_random_seq seq = aes_random_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.sequencer);
      phase.drop_objection(this);
    endtask
  endclass : aes_random_test

endpackage : aes_uvm_pkg


// Top: clock, reset, DUT, run_test.
module aes128_uvm_tb;
  import uvm_pkg::*;
  import aes_uvm_pkg::*;
  `include "uvm_macros.svh"

  logic clk = 1'b0;
  always #5 clk = ~clk;

  aes_if vif (.clk(clk));

  aes128_core dut (
    .clk        (vif.clk),
    .rst        (vif.rst),
    .clear      (vif.clear),
    .start      (vif.start),
    .plaintext  (vif.plaintext),
    .key        (vif.key),
    .ciphertext (vif.ciphertext),
    .busy       (vif.busy),
    .done       (vif.done)
  );

  // EDA Playground's EPWave viewer opens dump.vcd by default.
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, aes128_uvm_tb);
  end

  // run_test must be called at time 0. The default below runs the directed
  // test; override it with +UVM_TESTNAME=aes_random_test on the command line.
  initial begin
    uvm_config_db#(virtual aes_if)::set(null, "*", "vif", vif);
    run_test("aes_directed_test");
  end

  // Power-on reset, driven concurrently. The driver waits for rst to deassert.
  initial begin
    vif.rst   = 1'b1;
    vif.clear = 1'b0;
    repeat (3) @(posedge clk);
    vif.rst   = 1'b0;
  end
endmodule : aes128_uvm_tb
