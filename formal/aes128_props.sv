`timescale 1ns/1ps

// Assertion checks for aes128_core, bound to the core at the bottom of this
// file. They use only the ports plus one helper flop, so they run in plain
// simulation (verilator --assert) and under a formal tool.
module aes128_props (
  input logic         clk,
  input logic         rst,
  input logic         clear,
  input logic         start,
  input logic         done,
  input logic [127:0] ciphertext
);

  // Helper: has at least one `start` been seen since the last reset/clear?
  logic started;
  always_ff @(posedge clk) begin
    if (rst || clear) started <= 1'b0;
    else if (start)   started <= 1'b1;
  end

  // 1. done is never produced without a prior start (no spurious completion).
  a_done_needs_start: assert property (
    @(posedge clk) disable iff (rst)
    done |-> started
  );

  // 2. ciphertext changes only when a new result lands (done) or one cycle
  //    after a clear (the zeroizing wipe is registered).
  a_ciphertext_stable: assert property (
    @(posedge clk) disable iff (rst)
    $changed(ciphertext) |-> (done || $past(clear))
  );

  // 3. done is exactly one cycle wide.
  a_done_single_pulse: assert property (
    @(posedge clk) disable iff (rst)
    done |=> !done
  );

  // 4. a synchronous reset deasserts done on the next cycle.
  a_rst_clears_done: assert property (
    @(posedge clk)
    rst |=> !done
  );

  // 5. clear wipes the result and drops done on the next cycle.
  a_clear_zeroizes: assert property (
    @(posedge clk) disable iff (rst)
    clear |=> (ciphertext == '0 && !done)
  );

  // 6. reachability: an accepted start reaches done 11 cycles later (1 load +
  //    10 rounds). Guarded out for Verilator 5.020, which lacks ##N delays.
`ifndef VERILATOR
  c_start_to_done: cover property (
    @(posedge clk) disable iff (rst || clear)
    start ##11 done
  );
`endif

endmodule : aes128_props


// Attach the checker to every aes128_core instance.
bind aes128_core aes128_props u_aes128_props (
  .clk        (clk),
  .rst        (rst),
  .clear      (clear),
  .start      (start),
  .done       (done),
  .ciphertext (ciphertext)
);
