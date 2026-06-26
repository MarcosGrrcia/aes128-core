// Monitor: at done, samples the inputs and ciphertext into one item.
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
