`timescale 1ns/1ps

// Self-checking testbench for the AXI4-Lite wrapper (aes128_axil).
//
// A simple task-based AXI4-Lite master programs the key and plaintext
// registers, starts the core, polls STATUS and reads the ciphertext back. It
// reruns the known-answer vectors through the bus, then checks the register
// map (write-only key, WSTRB, CLEAR, irq) and the channel handshakes.
//
// Like aes128_tb.sv, stimulus is driven on the falling edge. The slave's
// ready signals are registered, so a ready seen at a falling edge means the
// handshake completes on the next rising edge.

module aes128_axil_tb;

  localparam logic [5:0] CTRL   = 6'h00;
  localparam logic [5:0] STATUS = 6'h04;
  localparam logic [5:0] KEY0   = 6'h10;
  localparam logic [5:0] PT0    = 6'h20;
  localparam logic [5:0] CT0    = 6'h30;

  localparam logic [31:0] CTRL_START  = 32'h1;
  localparam logic [31:0] CTRL_CLEAR  = 32'h2;
  localparam logic [31:0] CTRL_IRQ_EN = 32'h4;

  logic clk = 1'b0;
  logic rst_n = 1'b0;

  logic [5:0]  awaddr = '0;
  logic        awvalid = 1'b0;
  logic        awready;
  logic [31:0] wdata = '0;
  logic [3:0]  wstrb = '0;
  logic        wvalid = 1'b0;
  logic        wready;
  logic [1:0]  bresp;
  logic        bvalid;
  logic        bready = 1'b0;
  logic [5:0]  araddr = '0;
  logic        arvalid = 1'b0;
  logic        arready;
  logic [31:0] rdata;
  logic [1:0]  rresp;
  logic        rvalid;
  logic        rready = 1'b0;
  logic        irq;

  aes128_axil dut (
    .s_axi_aclk    (clk),
    .s_axi_aresetn (rst_n),
    .s_axi_awaddr  (awaddr),
    .s_axi_awprot  (3'b000),
    .s_axi_awvalid (awvalid),
    .s_axi_awready (awready),
    .s_axi_wdata   (wdata),
    .s_axi_wstrb   (wstrb),
    .s_axi_wvalid  (wvalid),
    .s_axi_wready  (wready),
    .s_axi_bresp   (bresp),
    .s_axi_bvalid  (bvalid),
    .s_axi_bready  (bready),
    .s_axi_araddr  (araddr),
    .s_axi_arprot  (3'b000),
    .s_axi_arvalid (arvalid),
    .s_axi_arready (arready),
    .s_axi_rdata   (rdata),
    .s_axi_rresp   (rresp),
    .s_axi_rvalid  (rvalid),
    .s_axi_rready  (rready),
    .irq           (irq)
  );

  always #5 clk = ~clk;

  int errors = 0;

  task automatic check(input string name, input logic [127:0] got, exp);
    if (got === exp) begin
      $display("  ok   %-26s %h", name, got);
    end else begin
      $display("  FAIL %-26s", name);
      $display("       got %h", got);
      $display("       exp %h", exp);
      errors++;
    end
  endtask

  task automatic check32(input string name, input logic [31:0] got, exp);
    if (got === exp) begin
      $display("  ok   %-26s %h", name, got);
    end else begin
      $display("  FAIL %-26s got %h, exp %h", name, got, exp);
      errors++;
    end
  endtask

  task automatic check_bit(input string name, input logic got, exp);
    if (got === exp) begin
      $display("  ok   %s", name);
    end else begin
      $display("  FAIL %s (got %b, exp %b)", name, got, exp);
      errors++;
    end
  endtask

  task automatic axi_write(input logic [5:0] addr, input logic [31:0] data,
                           input logic [3:0] strb = 4'hF);
    @(negedge clk);
    awaddr  = addr;
    awvalid = 1'b1;
    wdata   = data;
    wstrb   = strb;
    wvalid  = 1'b1;
    bready  = 1'b1;
    do @(negedge clk); while (!(awready && wready));
    @(negedge clk);
    awvalid = 1'b0;
    wvalid  = 1'b0;
    while (!bvalid) @(negedge clk);
    if (bresp !== 2'b00) begin
      $display("  FAIL write to %02h got BRESP %b", addr, bresp);
      errors++;
    end
    @(negedge clk);
    bready = 1'b0;
  endtask

  task automatic axi_read(input logic [5:0] addr, output logic [31:0] data);
    @(negedge clk);
    araddr  = addr;
    arvalid = 1'b1;
    rready  = 1'b1;
    do @(negedge clk); while (!arready);
    @(negedge clk);
    arvalid = 1'b0;
    while (!rvalid) @(negedge clk);
    data = rdata;
    if (rresp !== 2'b00) begin
      $display("  FAIL read from %02h got RRESP %b", addr, rresp);
      errors++;
    end
    @(negedge clk);
    rready = 1'b0;
  endtask

  task automatic write_block(input logic [5:0] base, input logic [127:0] val);
    axi_write(base + 6'h0, val[127:96]);
    axi_write(base + 6'h4, val[95:64]);
    axi_write(base + 6'h8, val[63:32]);
    axi_write(base + 6'hC, val[31:0]);
  endtask

  task automatic read_block(input logic [5:0] base, output logic [127:0] val);
    axi_read(base + 6'h0, val[127:96]);
    axi_read(base + 6'h4, val[95:64]);
    axi_read(base + 6'h8, val[63:32]);
    axi_read(base + 6'hC, val[31:0]);
  endtask

  task automatic wait_done();
    logic [31:0] status;
    do axi_read(STATUS, status); while (!status[1]);   // STATUS.DONE
  endtask

  task automatic encrypt(input logic [127:0] k, pt, output logic [127:0] ct);
    write_block(KEY0, k);
    write_block(PT0, pt);
    axi_write(CTRL, CTRL_START);
    wait_done();
    read_block(CT0, ct);
  endtask

  logic [127:0] ct, blk;
  logic [31:0]  word;

  initial begin
    $dumpfile("aes128_axil_tb.vcd");
    $dumpvars(0, aes128_axil_tb);

    repeat (3) @(negedge clk);
    rst_n = 1'b1;

    $display("AES-128 known-answer vectors over AXI4-Lite:");
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

    $display("Register map:");

    // The key is write-only; it must never read back.
    read_block(KEY0, blk);
    check("KEY reads as zero", blk, '0);

    read_block(PT0, blk);
    check("PT readback", blk, 128'hae2d8a571e03ac9c9eb76fac45af8e51);

    // Byte strobes: only bytes 3 and 0 of PT0 should change.
    axi_write(PT0, 32'h11223344, 4'b1001);
    axi_read(PT0, word);
    check32("WSTRB partial write", word, 32'h112d8a44);

    axi_read(6'h08, word);
    check32("unmapped reads zero", word, 32'd0);

    axi_write(CT0, 32'hdeadbeef);
    axi_read(CT0, word);
    check32("CT is read-only", word, 32'hf5d3d585);

    // A CTRL write without WSTRB[0] doesn't reach the START bit.
    axi_write(CTRL, CTRL_START, 4'b1110);
    axi_read(STATUS, word);
    check32("CTRL needs WSTRB[0]", word, 32'h2);

    // Writing START while busy must not restart the block. Each write takes
    // about four clocks, so the second START lands well inside the 11-clock
    // run.
    write_block(KEY0, 128'h000102030405060708090a0b0c0d0e0f);
    write_block(PT0,  128'h00112233445566778899aabbccddeeff);
    axi_write(CTRL, CTRL_START);
    axi_write(PT0, 32'hdeadbeef);
    axi_write(CTRL, CTRL_START);
    wait_done();
    read_block(CT0, ct);
    check("START ignored while busy", ct, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);

    $display("Interrupt:");
    check_bit("irq low while disabled", irq, 1'b0);
    write_block(PT0, 128'h00112233445566778899aabbccddeeff);
    axi_write(CTRL, CTRL_IRQ_EN | CTRL_START);
    axi_read(STATUS, word);
    check_bit("STATUS.BUSY after START", word[0], 1'b1);
    check_bit("irq low while busy", irq, 1'b0);
    while (!irq) @(negedge clk);
    axi_read(STATUS, word);
    check_bit("irq with STATUS.DONE", word[1], 1'b1);
    axi_write(CTRL, CTRL_IRQ_EN | CTRL_START);
    check_bit("irq drops on START", irq, 1'b0);
    wait_done();

    $display("Clear:");
    axi_write(CTRL, CTRL_CLEAR);
    read_block(CT0, blk);
    check("CLEAR wipes ciphertext", blk, '0);
    read_block(PT0, blk);
    check("CLEAR wipes plaintext", blk, '0);
    axi_read(STATUS, word);
    check32("CLEAR drops DONE", word, 32'd0);

    $display("Handshakes:");

    // Address without data: the slave must wait for WVALID.
    @(negedge clk);
    awaddr  = PT0;
    awvalid = 1'b1;
    repeat (3) @(negedge clk);
    check_bit("AWREADY waits for WVALID", awready, 1'b0);
    wdata  = 32'hcafef00d;
    wstrb  = 4'hF;
    wvalid = 1'b1;
    while (!awready) @(negedge clk);
    @(negedge clk);
    awvalid = 1'b0;
    wvalid  = 1'b0;

    // Response held until BREADY.
    repeat (3) @(negedge clk);
    check_bit("BVALID held until BREADY", bvalid, 1'b1);
    bready = 1'b1;
    @(negedge clk);
    bready = 1'b0;
    check_bit("BVALID drops after BREADY", bvalid, 1'b0);

    // Read data held until RREADY.
    araddr  = PT0;
    arvalid = 1'b1;
    while (!arready) @(negedge clk);
    @(negedge clk);
    arvalid = 1'b0;
    repeat (3) @(negedge clk);
    check_bit("RVALID held until RREADY", rvalid, 1'b1);
    check32("RDATA stable", rdata, 32'hcafef00d);
    rready = 1'b1;
    @(negedge clk);
    rready = 1'b0;
    check_bit("RVALID drops after RREADY", rvalid, 1'b0);

    $display("");
    if (errors == 0) $display("PASS: all checks passed");
    else             $display("FAIL: %0d check(s) failed", errors);
    $finish;
  end

  // Watchdog.
  initial begin
    #200000;
    $display("FAIL: timeout");
    $finish;
  end

endmodule : aes128_axil_tb
