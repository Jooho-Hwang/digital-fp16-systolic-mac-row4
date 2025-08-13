//=======================================================
//  File Name:    tb_fp_mul.v
//  Description:  Unit testbench for fp_mul (pure combinational).
//                - Sanity checks with known FP16 constants
//                - Special cases: zero/inf
//                - Denormal sketch (smallest subnormal)
//=======================================================

`timescale 1ns/1ps
`include "../rtl/fp16_defs.vh"

module tb_fp_mul;

  // DUT I/O
  reg  [`FP16_WIDTH-1:0] a, b;
  wire [`FP16_WIDTH-1:0] y;

  // Device under test
  fp_mul dut (
    .a(a), .b(b), .y(y)
  );

  // Utilities
  task show(input [15:0] _a, input [15:0] _b, input [15:0] _y, input [127:0] note);
    begin
      $display("[%0t] a=%h b=%h -> y=%h   %s", $time, _a, _b, _y, note);
    end
  endtask

  // Known FP16 constants
  localparam [15:0] H_ZERO = `FP16_POS_ZERO;  // +0
  localparam [15:0] H_NEG0 = `FP16_NEG_ZERO;  // -0
  localparam [15:0] H_INF  = `FP16_POS_INF;   // +Inf
  localparam [15:0] H_NINF = `FP16_NEG_INF;   // -Inf
  localparam [15:0] H_1_0  = 16'h3C00;        // 1.0
  localparam [15:0] H_2_0  = 16'h4000;        // 2.0
  localparam [15:0] H_0_5  = 16'h3800;        // 0.5
  localparam [15:0] H_3_0  = 16'h4200;        // 3.0
  localparam [15:0] H_3_5  = 16'h4300;        // 3.5
  localparam [15:0] H_3_75 = 16'h4380;        // 3.75
  // Smallest positive subnormal (denorm): exp=0, man=1
  localparam [15:0] H_MIN_DEN = 16'h0001;

  initial begin
    $display("=== tb_fp_mul: start ===");

    // 1) Basic multiplicative identities
    a = H_1_0; b = H_3_0; #1; show(a,b,y,"1.0 * 3.0 = 3.0");
    a = H_2_0; b = H_0_5; #1; show(a,b,y,"2.0 * 0.5 = 1.0");

    // 2) Zero and signed zero
    a = H_ZERO; b = H_3_5; #1; show(a,b,y,"0 * 3.5 = 0");
    a = H_NEG0; b = H_3_0; #1; show(a,b,y,"-0 * 3.0 = -0");

    // 3) Infinity precedence
    a = H_INF; b = H_3_75; #1; show(a,b,y,"+Inf * 3.75 = +Inf");
    a = H_NINF; b = H_0_5; #1; show(a,b,y,"-Inf * 0.5 = -Inf");

    // 4) Denormal handling (tiny * 2.0)
    a = H_MIN_DEN; b = H_2_0; #1; show(a,b,y,"min_denorm * 2.0 (check normalization) ");

    // 5) Guard-bit rounding edge (3.0 * 1.25 approx via 0x3A00=1.25)
    a = H_3_0; b = 16'h3A00; #1; show(a,b,y,"3.0 * 1.25 = 3.75 (expect ~0x4380)");

    // 6) Presentation vectors (PLACEHOLDER: fill exact FP16 hex)
    //   w = {3.75, 1.76, -0.52, 0.36}
    //   x = {1.52, 2.75, 3.86, -1.47, 8.98, -6.52, 3.61}
    // Example single multiply probe:
    a = 16'h4380; /* 3.75 */ b = 16'h3A00; /* 1.25 as placeholder */ #1;
    show(a,b,y,"presentation probe (replace b with exact 1.76 half)");

    $display("=== tb_fp_mul: done ===");
    $finish;
  end

endmodule