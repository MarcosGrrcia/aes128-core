// Environment: wires sequencer, driver, monitor, scoreboard together.
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
