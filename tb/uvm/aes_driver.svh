// Driver: pulses start while busy is low, then waits for done.
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
