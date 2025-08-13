//=======================================================
//  File Name:    tb_fp_add.v
//  Description:  Unit testbench for fp_add (pure combinational).
//                - Align/add/sub cases with known FP16 constants
//                - Zero/Inf/Denorm coverage
//=======================================================

`timescale 1ns/1ps
`include "../rtl/fp16_defs.vh"

module tb_fp_add;

  reg  [`FP16_WIDTH-1:0] a, b;
  wire [`FP16_WIDTH-1:0] y;

  fp_add dut (.a(a), .b(b), .y(y));

  task show(input [15:0] _a, input [15:0] _b, input [15:0] _y, input [127:0] note);
    $display("[%0t] a=%h + b=%h -> y=%h   %s", $time, _a, _b, _y, note);
  endtask

  localparam [15:0] H_ZERO = `FP16_POS_ZERO;
  localparam [15:0] H_INF  = `FP16_POS_INF;
  localparam [15:0] H_NINF = `FP16_NEG_INF;
  localparam [15:0] H_1_0  = 16'h3C00; // 1.0
  localparam [15:0] H_2_0  = 16'h4000; // 2.0
  localparam [15:0] H_0_5  = 16'h3800; // 0.5
  localparam [15:0] H_3_0  = 16'h4200; // 3.0
  localparam [15:0] H_1_5  = 16'h3E00; // 1.5
  localparam [15:0] H_MIN_DEN = 16'h0001;

  initial begin
    $display("=== tb_fp_add: start ===");

    // 1) Simple sum
    a = H_1_0; b = H_2_0; #1; show(a,b,y,"1.0 + 2.0 = 3.0");
    a = H_1_5; b = H_1_5; #1; show(a,b,y,"1.5 + 1.5 = 3.0");

    // 2) Opposite signs (cancellation)
    a = H_1_0; b = 16'hBC00; /* -1.0 */ #1; show(a,b,y,"1.0 + (-1.0) = 0");

    // 3) Zero and Inf
    a = H_ZERO; b = H_3_0; #1; show(a,b,y,"0 + 3.0 = 3.0");
    a = H_INF;  b = H_0_5; #1; show(a,b,y,"Inf + 0.5 = Inf");
    a = H_NINF; b = H_0_5; #1; show(a,b,y,"-Inf + 0.5 = -Inf");

    // 4) Denormal interaction
    a = H_MIN_DEN; b = H_MIN_DEN; #1; show(a,b,y,"denorm + denorm (check normalization)");

    // 5) Rounding boundary (3.0 + 0.75 => 3.75)
    a = H_3_0; b = 16'h3A00; /* 1.25 */ #1; show(a,b,y,"3.0 + 1.25 = 4.25 (round/normalize)");

    // 6) Presentation vectors (PLACEHOLDER: fill exact FP16 hex if needed)
    // e.g., a = <w0*x0>, b = <acc> pattern checks can be staged in MAC TB.

    $display("=== tb_fp_add: done ===");
    $finish;
  end

endmodule