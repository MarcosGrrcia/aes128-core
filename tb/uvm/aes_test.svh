// Tests: one environment, picked at run time with +UVM_TESTNAME.
class aes_base_test extends uvm_test;
  `uvm_component_utils(aes_base_test)
  aes_env env;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = aes_env::type_id::create("env", this);
  endfunction
endclass : aes_base_test

class aes_directed_test extends aes_base_test;
  `uvm_component_utils(aes_directed_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    aes_directed_seq seq = aes_directed_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.sequencer);
    phase.drop_objection(this);
  endtask
endclass : aes_directed_test

class aes_random_test extends aes_base_test;
  `uvm_component_utils(aes_random_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    aes_random_seq seq = aes_random_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.sequencer);
    phase.drop_objection(this);
  endtask
endclass : aes_random_test
