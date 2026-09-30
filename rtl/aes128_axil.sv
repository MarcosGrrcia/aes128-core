`timescale 1ns/1ps

// AXI4-Lite slave wrapper around aes128_core.
//
// Software writes the key and plaintext into registers, sets CTRL.START, then
// either polls STATUS.DONE or waits for irq, and reads the ciphertext back.
//
// Register map (32-bit registers, byte offsets):
//
//   0x00  CTRL     W   [0] START      write 1 to start a block (self-clearing,
//                                     ignored while BUSY)
//                      [1] CLEAR      write 1 to wipe key/data and abort
//                  RW  [2] IRQ_EN     drive irq while STATUS.DONE is set
//   0x04  STATUS   R   [0] BUSY       a block is in flight
//                      [1] DONE       result ready; cleared by START or CLEAR
//   0x10  KEY0     W   key[127:96]    (write-only, reads as 0)
//   0x14  KEY1     W   key[95:64]
//   0x18  KEY2     W   key[63:32]
//   0x1C  KEY3     W   key[31:0]
//   0x20  PT0      RW  plaintext[127:96]
//   0x24  PT1      RW  plaintext[95:64]
//   0x28  PT2      RW  plaintext[63:32]
//   0x2C  PT3      RW  plaintext[31:0]
//   0x30  CT0      R   ciphertext[127:96]
//   0x34  CT1      R   ciphertext[95:64]
//   0x38  CT2      R   ciphertext[63:32]
//   0x3C  CT3      R   ciphertext[31:0]
//
// Word 0 is the most significant, so a test vector is written in the order
// it's printed. The port decodes a 64-byte window; the interconnect decodes
// the base address. 0x08 and 0x0C read as 0 and ignore writes. All responses
// are OKAY. WSTRB is honored on the KEY and PT registers.
//
// Writes wait for both AWVALID and WVALID, which the AXI spec allows. One
// transaction is handled at a time.

module aes128_axil (
  input  logic        s_axi_aclk,
  input  logic        s_axi_aresetn,

  // Write address channel
  input  logic [5:0]  s_axi_awaddr,
  input  logic [2:0]  s_axi_awprot,  // unused
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,

  // Write data channel
  input  logic [31:0] s_axi_wdata,
  input  logic [3:0]  s_axi_wstrb,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,

  // Write response channel
  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready,

  // Read address channel
  input  logic [5:0]  s_axi_araddr,
  input  logic [2:0]  s_axi_arprot,  // unused
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,

  // Read data channel
  output logic [31:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rvalid,
  input  logic        s_axi_rready,

  output logic        irq
);

  // Word offsets (byte address >> 2)
  localparam logic [3:0] REG_CTRL   = 4'h0;
  localparam logic [3:0] REG_STATUS = 4'h1;
  localparam logic [3:0] REG_KEY0   = 4'h4;
  localparam logic [3:0] REG_KEY1   = 4'h5;
  localparam logic [3:0] REG_KEY2   = 4'h6;
  localparam logic [3:0] REG_KEY3   = 4'h7;
  localparam logic [3:0] REG_PT0    = 4'h8;
  localparam logic [3:0] REG_PT1    = 4'h9;
  localparam logic [3:0] REG_PT2    = 4'hA;
  localparam logic [3:0] REG_PT3    = 4'hB;
  localparam logic [3:0] REG_CT0    = 4'hC;
  localparam logic [3:0] REG_CT1    = 4'hD;
  localparam logic [3:0] REG_CT2    = 4'hE;
  localparam logic [3:0] REG_CT3    = 4'hF;

  localparam logic [1:0] RESP_OKAY = 2'b00;

  logic rst;
  assign rst = !s_axi_aresetn;

  // Registers visible to software
  logic [127:0] key_reg;
  logic [127:0] pt_reg;
  logic         irq_en;
  logic         done_flag;

  // Pulses to the core
  logic         core_start;
  logic         core_clear;

  // Core outputs
  logic [127:0] core_ct;
  logic         core_busy;
  logic         core_done;

  aes128_core u_core (
    .clk        (s_axi_aclk),
    .rst        (rst),
    .clear      (core_clear),
    .start      (core_start),
    .plaintext  (pt_reg),
    .key        (key_reg),
    .ciphertext (core_ct),
    .busy       (core_busy),
    .done       (core_done)
  );

  // Merge a 32-bit write into an existing register, one byte per strobe bit.
  function automatic logic [31:0] apply_wstrb(input logic [31:0] old_val,
                                               input logic [31:0] new_val,
                                               input logic [3:0]  strb);
    for (int i = 0; i < 4; i++) begin
      if (strb[i]) old_val[8*i +: 8] = new_val[8*i +: 8];
    end
    return old_val;
  endfunction

  logic wr_en;
  assign wr_en = s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready;

  // Accept address and data together, then hold BVALID until the master takes
  // the response.
  always_ff @(posedge s_axi_aclk) begin
    if (rst) begin
      s_axi_awready <= 1'b0;
      s_axi_wready  <= 1'b0;
      s_axi_bvalid  <= 1'b0;
    end else begin
      s_axi_awready <= !s_axi_awready && s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid;
      s_axi_wready  <= !s_axi_awready && s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid;

      if (wr_en) begin
        s_axi_bvalid <= 1'b1;
      end else if (s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end

  assign s_axi_bresp = RESP_OKAY;

  // Register writes. START and CLEAR are one-cycle pulses to the core.
  always_ff @(posedge s_axi_aclk) begin
    if (rst) begin
      key_reg    <= '0;
      pt_reg     <= '0;
      irq_en     <= 1'b0;
      core_start <= 1'b0;
      core_clear <= 1'b0;
    end else begin
      core_start <= 1'b0;
      core_clear <= 1'b0;

      if (wr_en) begin
        case (s_axi_awaddr[5:2])
          REG_CTRL: begin
            if (s_axi_wstrb[0]) begin
              irq_en <= s_axi_wdata[2];
              if (s_axi_wdata[1]) begin
                // Clear wins over start, same as in the core.
                core_clear <= 1'b1;
                key_reg    <= '0;
                pt_reg     <= '0;
              end else if (s_axi_wdata[0] && !core_busy) begin
                core_start <= 1'b1;
              end
            end
          end

          REG_KEY0: key_reg[127:96] <= apply_wstrb(key_reg[127:96], s_axi_wdata, s_axi_wstrb);
          REG_KEY1: key_reg[95:64]  <= apply_wstrb(key_reg[95:64],  s_axi_wdata, s_axi_wstrb);
          REG_KEY2: key_reg[63:32]  <= apply_wstrb(key_reg[63:32],  s_axi_wdata, s_axi_wstrb);
          REG_KEY3: key_reg[31:0]   <= apply_wstrb(key_reg[31:0],   s_axi_wdata, s_axi_wstrb);

          REG_PT0:  pt_reg[127:96]  <= apply_wstrb(pt_reg[127:96],  s_axi_wdata, s_axi_wstrb);
          REG_PT1:  pt_reg[95:64]   <= apply_wstrb(pt_reg[95:64],   s_axi_wdata, s_axi_wstrb);
          REG_PT2:  pt_reg[63:32]   <= apply_wstrb(pt_reg[63:32],   s_axi_wdata, s_axi_wstrb);
          REG_PT3:  pt_reg[31:0]    <= apply_wstrb(pt_reg[31:0],    s_axi_wdata, s_axi_wstrb);

          default: ;  // read-only or unmapped
        endcase
      end
    end
  end

  // DONE is sticky: set when the core finishes, cleared by the next START or
  // by CLEAR.
  always_ff @(posedge s_axi_aclk) begin
    if (rst || core_clear || core_start) begin
      done_flag <= 1'b0;
    end else if (core_done) begin
      done_flag <= 1'b1;
    end
  end

  assign irq = done_flag && irq_en;

  // Read data. KEY0-KEY3 fall into the default and read as 0.
  logic [31:0] rd_mux;

  always_comb begin
    case (s_axi_araddr[5:2])
      REG_CTRL:   rd_mux = {29'd0, irq_en, 2'b00};
      REG_STATUS: rd_mux = {30'd0, done_flag, core_busy};
      REG_PT0:    rd_mux = pt_reg[127:96];
      REG_PT1:    rd_mux = pt_reg[95:64];
      REG_PT2:    rd_mux = pt_reg[63:32];
      REG_PT3:    rd_mux = pt_reg[31:0];
      REG_CT0:    rd_mux = core_ct[127:96];
      REG_CT1:    rd_mux = core_ct[95:64];
      REG_CT2:    rd_mux = core_ct[63:32];
      REG_CT3:    rd_mux = core_ct[31:0];
      default:    rd_mux = 32'd0;
    endcase
  end

  // Accept one read address, then hold RVALID until the master takes the data.
  always_ff @(posedge s_axi_aclk) begin
    if (rst) begin
      s_axi_arready <= 1'b0;
      s_axi_rvalid  <= 1'b0;
      s_axi_rdata   <= '0;
    end else begin
      s_axi_arready <= !s_axi_arready && s_axi_arvalid && !s_axi_rvalid;

      if (s_axi_arvalid && s_axi_arready) begin
        s_axi_rvalid <= 1'b1;
        s_axi_rdata  <= rd_mux;
      end else if (s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

  assign s_axi_rresp = RESP_OKAY;

endmodule : aes128_axil
