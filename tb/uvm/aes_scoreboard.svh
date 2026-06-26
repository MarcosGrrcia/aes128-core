// Scoreboard: predicts from the inputs, compares to the DUT.
class aes_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(aes_scoreboard)

  uvm_analysis_imp #(aes_seq_item, aes_scoreboard) ap_imp;
  int unsigned num_passed;
  int unsigned num_failed;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap_imp = new("ap_imp", this);
  endfunction

  /* AES CODE BEGIN check */
  function void write(aes_seq_item t);
    bit [127:0] expected = aes128_model(t.key, t.plaintext);
    if (t.ciphertext === expected) begin
      num_passed++;
      `uvm_info("SCB", $sformatf("PASS cipher=%032h", t.ciphertext), UVM_LOW)
    end else begin
      num_failed++;
      `uvm_error("SCB", $sformatf("MISMATCH expected=%032h actual=%032h",
                                  expected, t.ciphertext))
    end
  endfunction
  /* AES CODE END check */

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf("DONE: %0d passed, %0d failed",
                               num_passed, num_failed), UVM_NONE)
    if (num_failed != 0 || num_passed == 0)
      `uvm_error("SCB", "test did not pass cleanly")
  endfunction
endclass : aes_scoreboard
