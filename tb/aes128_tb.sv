`timescale 1ns/1ps

// Standalone self-checking testbench for aes128_core (no UVM required).
//
// Runs the FIPS-197 and SP 800-38A known-answer vectors, then checks the
// start/busy/done/clear handshake. Stimulus is driven on the falling edge so
// the DUT (clocked on the rising edge) sees stable inputs and there are no
// sampling races. Dumps a VCD for waveform viewing.

module aes128_tb;

  logic         clk = 1'b0;
  logic         rst = 1'b1;
  logic         clear = 1'b0;
  logic         start = 1'b0;
  logic [127:0] plaintext = '0;
  logic [127:0] key = '0;
  logic [127:0] ciphertext;
  logic         busy;
  logic         done;

  aes128_core dut (.*);

  always #5 clk = ~clk;

  int errors = 0;

  task automatic check(input string name, input logic [127:0] got, exp);
    if (got === exp) begin
      $display("  ok   %-16s %032h", name, got);
    end else begin
      $display("  FAIL %-16s", name);
      $display("       got %032h", got);
      $display("       exp %032h", exp);
      errors++;
    end
  endtask

  // Drive one block through the core and return its ciphertext.
  task automatic encrypt(input logic [127:0] k, pt, output logic [127:0] ct);
    @(negedge clk);
    while (busy) @(negedge clk);     // honour the handshake: wait until ready
    key       = k;
    plaintext = pt;
    start     = 1'b1;
    @(negedge clk);
    start     = 1'b0;
    while (!done) @(negedge clk);
    ct = ciphertext;
  endtask

  logic [127:0] ct;

  initial begin
    $dumpfile("aes128_tb.vcd");
    $dumpvars(0, aes128_tb);

    repeat (3) @(negedge clk);
    rst = 1'b0;

    $display("AES-128 known-answer vectors:");
    encrypt(128'h000102030405060708090a0b0c0d0e0f,
            128'h00112233445566778899aabbccddeeff, ct);
    check("FIPS-197 C.1", ct, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);

    encrypt(128'h00000000000000000000000000000000,
            128'h00000000000000000000000000000000, ct);
    check("all-zero", ct, 128'h66e94bd4ef8a2c3b884cfa59ca342b2e);

    encrypt(128'hffffffffffffffffffffffffffffffff,
            128'hffffffffffffffffffffffffffffffff, ct);
    check("all-ones", ct, 128'hbcbf217cb280cf30b2517052193ab979);

    encrypt(128'h2b7e151628aed2a6abf7158809cf4f3c,
            128'h6bc1bee22e409f96e93d7e117393172a, ct);
    check("SP800-38A.1", ct, 128'h3ad77bb40d7a3660a89ecaf32466ef97);

    encrypt(128'h2b7e151628aed2a6abf7158809cf4f3c,
            128'hae2d8a571e03ac9c9eb76fac45af8e51, ct);
    check("SP800-38A.2", ct, 128'hf5d3d58503b9699de785895a96fdbaaf);

    $display("Handshake / control:");
    @(negedge clk);
    if (busy) begin $display("  FAIL busy asserted while idle"); errors++; end
    else      $display("  ok   busy low when idle");

    // clear must wipe a stored result.
    encrypt(128'h000102030405060708090a0b0c0d0e0f,
            128'h00112233445566778899aabbccddeeff, ct);
    @(negedge clk);
    clear = 1'b1;
    @(negedge clk);
    clear = 1'b0;
    @(negedge clk);
    if (ciphertext !== '0) begin $display("  FAIL clear left ciphertext intact"); errors++; end
    else                        $display("  ok   clear wipes ciphertext");

    $display("");
    if (errors == 0) $display("PASS: all checks passed");
    else             $display("FAIL: %0d check(s) failed", errors);
    $finish;
  end

  // Watchdog.
  initial begin
    #5000;
    $display("FAIL: timeout");
    $finish;
  end

endmodule : aes128_tb
