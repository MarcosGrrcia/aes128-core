// Sequence library: directed (known-answer) and constrained-random.
// Directed: fixed known-answer input pairs.
class aes_directed_seq extends uvm_sequence #(aes_seq_item);
  `uvm_object_utils(aes_directed_seq)
  function new(string name = "aes_directed_seq"); super.new(name); endfunction

  task body();
    /* AES CODE BEGIN vectors */
    bit [127:0] keys   [5];
    bit [127:0] plains [5];
    keys[0]   = '0;
    plains[0] = '0;
    keys[1]   = '1;
    plains[1] = '1;
    keys[2]   = 128'h000102030405060708090a0b0c0d0e0f;
    plains[2] = 128'h00112233445566778899aabbccddeeff;
    keys[3]   = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    plains[3] = 128'h6bc1bee22e409f96e93d7e117393172a;
    keys[4]   = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    plains[4] = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
    foreach (keys[i]) begin
      aes_seq_item item = aes_seq_item::type_id::create($sformatf("dir_%0d", i));
      start_item(item);
      item.key       = keys[i];
      item.plaintext = plains[i];
      finish_item(item);
    end
    /* AES CODE END vectors */
  endtask
endclass : aes_directed_seq

// Random: n blocks with random key and plaintext. Add constraints in the
// item (or an extended sequence) to bias coverage.
class aes_random_seq extends uvm_sequence #(aes_seq_item);
  `uvm_object_utils(aes_random_seq)
  int unsigned n = 20;
  function new(string name = "aes_random_seq"); super.new(name); endfunction

  task body();
    /* AES CODE BEGIN random */
    repeat (n) begin
      aes_seq_item item = aes_seq_item::type_id::create("rnd");
      start_item(item);
      if (!item.randomize())
        `uvm_error("SEQ", "randomize failed")
      finish_item(item);
    end
    /* AES CODE END random */
  endtask
endclass : aes_random_seq
