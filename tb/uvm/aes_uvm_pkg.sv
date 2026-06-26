`timescale 1ns/1ps

// UVM package for the aes128_core environment. Imports UVM, then includes the
// env one class per file. The include order is the dependency order. Each
// class must follow what it uses.
//
// Blocks wrapped in /* AES CODE BEGIN x */ ... /* AES CODE END x */ in the
// included files are the AES-specific parts; everything else is stock UVM.
package aes_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "aes_ref_model.svh"
  `include "aes_seq_item.svh"
  `include "aes_sequencer.svh"
  `include "aes_driver.svh"
  `include "aes_monitor.svh"
  `include "aes_scoreboard.svh"
  `include "aes_env.svh"
  `include "aes_seq_lib.svh"
  `include "aes_test.svh"
endpackage : aes_uvm_pkg
