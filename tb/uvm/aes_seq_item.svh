// Transaction: one AES block (key, plaintext, observed ciphertext).
class aes_seq_item extends uvm_sequence_item;
  /* AES CODE BEGIN fields */
  rand bit [127:0] key;
  rand bit [127:0] plaintext;
  bit [127:0]      ciphertext;   // observed (filled by monitor)
  /* AES CODE END fields */

  `uvm_object_utils(aes_seq_item)

  function new(string name = "aes_seq_item");
    super.new(name);
  endfunction
endclass : aes_seq_item
