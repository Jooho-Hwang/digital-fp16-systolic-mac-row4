//=======================================================
//  File Name:    tb_fp_mac.v
//  Description:  Unit testbench for fp_mac (pipelined).
//                - Minimal clock/reset
//                - Enable sequencing
//                - Observes val_o timing
//=======================================================

`timescale 1ns/1ps
`include "../rtl/fp16_defs.vh"

module tb_fp_mac;

  // Clock / reset
  reg clk = 0;
  reg rst_n = 0;
  always #5 clk = ~clk; // 100 MHz

  // DUT I/O
  reg  [`FP16_WIDTH-1:0] opA, opB, opADD;
  reg enA, enB, enADD;
  reg en_Mul_A, en_Mul_B, en_Add_A, en_Add_B;
  wire [`FP16_WIDTH-1:0] out_o;
  wire val_o;

  fp_mac dut (
    .clk(clk), .rst_n(rst_n),
    .opA(opA), .opB(opB), .opADD(opADD),
    .enA(enA), .enB(enB), .enADD(enADD),
    .en_Mul_A(en_Mul_A), .en_Mul_B(en_Mul_B),
    .en_Add_A(en_Add_A), .en_Add_B(en_Add_B),
    .out_o(out_o), .val_o(val_o)
  );

  // Constants
  localparam [15:0] H_ZERO = `FP16_POS_ZERO;
  localparam [15:0] H_1_0  = 16'h3C00; // 1.0
  localparam [15:0] H_2_0  = 16'h4000; // 2.0
  localparam [15:0] H_3_0  = 16'h4200; // 3.0
  localparam [15:0] H_0_5  = 16'h3800; // 0.5

  // Print helper
  task tick;
    begin @(posedge clk); #1; end
  endtask

  task show(input [127:0] note);
    $display("[%0t] out=%h val=%0d   %s", $time, out_o, val_o, note);
  endtask

  initial begin
    $display("=== tb_fp_mac: start ===");
    // Reset
    rst_n = 0;
    enA=0; enB=0; enADD=0;
    en_Mul_A=0; en_Mul_B=0; en_Add_A=0; en_Add_B=0;
    opA=H_ZERO; opB=H_ZERO; opADD=H_ZERO;
    repeat(4) tick;
    rst_n = 1;
    repeat(2) tick;

    // Case: out = (2.0 * 3.0) + 0.5 = 6.5
    // 1) Latch operands
    enA=1; opA=H_2_0;
    enB=1; opB=H_3_0;
    enADD=1; opADD=H_0_5;
    tick;
    enA=0; enB=0; enADD=0;

    // 2) Enable MUL, then ADD
    en_Mul_A=1; en_Mul_B=1; en_Add_A=0; en_Add_B=0; tick; // MUL_reg captures
    en_Mul_A=0; en_Mul_B=0; en_Add_A=1; en_Add_B=1; tick; // out_reg captures
    show("expect ~6.5"); tick;

    // Another run: out = (1.0 * 2.0) + 3.0 = 5.0
    enA=1; opA=H_1_0;
    enB=1; opB=H_2_0;
    enADD=1; opADD=H_3_0; tick;
    enA=0; enB=0; enADD=0;

    en_Mul_A=1; en_Mul_B=1; en_Add_A=0; en_Add_B=0; tick;
    en_Mul_A=0; en_Mul_B=0; en_Add_A=1; en_Add_B=1; tick;
    show("expect ~5.0"); tick;

    $display("=== tb_fp_mac: done ===");
    $finish;
  end

endmodule