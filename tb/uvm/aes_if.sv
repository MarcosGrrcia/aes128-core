`timescale 1ns/1ps

// DUT pin interface for aes128_core, sampled by the UVM testbench.
interface aes_if (input logic clk);
  /* AES CODE BEGIN pins */
  logic         rst;
  logic         clear;
  logic         start;
  logic         busy;
  logic         done;
  logic [127:0] plaintext;
  logic [127:0] key;
  logic [127:0] ciphertext;
  /* AES CODE END pins */
endinterface : aes_if
