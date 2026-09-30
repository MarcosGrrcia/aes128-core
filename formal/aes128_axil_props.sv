`timescale 1ns/1ps

// AXI4-Lite slave-side protocol checks for aes128_axil, bound to the wrapper
// at the bottom of this file. These cover the rules a slave is responsible
// for: once a response is valid it stays valid and stable until the master
// accepts it, and there is never a response without a request.
module aes128_axil_props (
  input logic        s_axi_aclk,
  input logic        s_axi_aresetn,
  input logic        s_axi_awvalid,
  input logic        s_axi_awready,
  input logic        s_axi_wvalid,
  input logic        s_axi_wready,
  input logic [1:0]  s_axi_bresp,
  input logic        s_axi_bvalid,
  input logic        s_axi_bready,
  input logic        s_axi_arvalid,
  input logic        s_axi_arready,
  input logic [31:0] s_axi_rdata,
  input logic [1:0]  s_axi_rresp,
  input logic        s_axi_rvalid,
  input logic        s_axi_rready
);

  // 1. BVALID stays high, with a stable BRESP, until BREADY.
  a_bvalid_hold: assert property (
    @(posedge s_axi_aclk) disable iff (!s_axi_aresetn)
    (s_axi_bvalid && !s_axi_bready) |=> (s_axi_bvalid && $stable(s_axi_bresp))
  );

  // 2. RVALID stays high, with stable RDATA/RRESP, until RREADY.
  a_rvalid_hold: assert property (
    @(posedge s_axi_aclk) disable iff (!s_axi_aresetn)
    (s_axi_rvalid && !s_axi_rready) |=>
      (s_axi_rvalid && $stable(s_axi_rdata) && $stable(s_axi_rresp))
  );

  // 3. A write response only follows an accepted address and data beat.
  a_bvalid_after_write: assert property (
    @(posedge s_axi_aclk) disable iff (!s_axi_aresetn)
    $rose(s_axi_bvalid) |->
      $past(s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready)
  );

  // 4. Read data only follows an accepted read address.
  a_rvalid_after_read: assert property (
    @(posedge s_axi_aclk) disable iff (!s_axi_aresetn)
    $rose(s_axi_rvalid) |-> $past(s_axi_arvalid && s_axi_arready)
  );

  // 5. AWREADY and WREADY are raised together, so the address and data of a
  //    write are always accepted in the same cycle.
  a_aw_w_together: assert property (
    @(posedge s_axi_aclk) disable iff (!s_axi_aresetn)
    s_axi_awready == s_axi_wready
  );

  // 6. All outputs are low while in reset.
  a_reset_outputs: assert property (
    @(posedge s_axi_aclk)
    !s_axi_aresetn |=> !(s_axi_awready || s_axi_wready || s_axi_bvalid ||
                         s_axi_arready || s_axi_rvalid)
  );

endmodule : aes128_axil_props


// Attach the checker to every aes128_axil instance.
bind aes128_axil aes128_axil_props u_aes128_axil_props (
  .s_axi_aclk    (s_axi_aclk),
  .s_axi_aresetn (s_axi_aresetn),
  .s_axi_awvalid (s_axi_awvalid),
  .s_axi_awready (s_axi_awready),
  .s_axi_wvalid  (s_axi_wvalid),
  .s_axi_wready  (s_axi_wready),
  .s_axi_bresp   (s_axi_bresp),
  .s_axi_bvalid  (s_axi_bvalid),
  .s_axi_bready  (s_axi_bready),
  .s_axi_arvalid (s_axi_arvalid),
  .s_axi_arready (s_axi_arready),
  .s_axi_rdata   (s_axi_rdata),
  .s_axi_rresp   (s_axi_rresp),
  .s_axi_rvalid  (s_axi_rvalid),
  .s_axi_rready  (s_axi_rready)
);
