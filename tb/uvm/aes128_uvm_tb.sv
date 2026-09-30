`timescale 1ns/1ps

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
