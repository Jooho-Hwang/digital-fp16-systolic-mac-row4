//=======================================================
//  File Name:    tb_mac_row4.v
//  Description:  Integration testbench for mac_row4 (4-stage systolic row).
//                - Preload weights
//                - Stream X each cycle
//                - Observe continuous outputs after pipeline fill
//                - Includes a placeholder section for the presentation vectors
//=======================================================

`timescale 1ns/1ps
`include "../rtl/fp16_defs.vh"

module tb_mac_row4;

  // Clock / reset
  reg clk = 0;
  reg rst_n = 0;
  always #5 clk = ~clk; // 100 MHz

  // DUT I/O
  reg                   enX;
  reg  [3:0]            enW;
  reg  [`FP16_WIDTH-1:0] X_i, W0_i, W1_i, W2_i, W3_i;
  wire [`FP16_WIDTH-1:0] Y_o;
  wire                   finish;

  mac_row4 dut (
    .clk(clk), .rst_n(rst_n),
    .enX(enX), .enW(enW),
    .X_i(X_i), .W0_i(W0_i), .W1_i(W1_i), .W2_i(W2_i), .W3_i(W3_i),
    .Y_o(Y_o), .finish(finish)
  );

  // Handy constants
  localparam [15:0] H_ZERO = `FP16_POS_ZERO;
  localparam [15:0] H_1_0  = 16'h3C00; // 1.0
  localparam [15:0] H_2_0  = 16'h4000; // 2.0
  localparam [15:0] H_0_5  = 16'h3800; // 0.5
  localparam [15:0] H_3_0  = 16'h4200; // 3.0
  localparam [15:0] H_3_5  = 16'h4300; // 3.5
  localparam [15:0] H_3_75 = 16'h4380; // 3.75 (used for simple known run)
  localparam [15:0] H_INF  = `FP16_POS_INF;

  task tick; begin @(posedge clk); #1; end endtask

  task show;
    $display("[%0t] finish=%0d  Y=%h", $time, finish, Y_o);
  endtask

  // Stream helper
  task stream_x(input [15:0] xh);
    begin
      enX = 1'b1; X_i = xh; tick;
      enX = 1'b0; X_i = H_ZERO; // idle between samples (still 1/cycle rate if needed)
    end
  endtask

  initial begin
    $display("=== tb_mac_row4: start ===");
    // Reset
    rst_n=0; enX=0; enW=4'b0000; X_i=H_ZERO;
    W0_i=H_ZERO; W1_i=H_ZERO; W2_i=H_ZERO; W3_i=H_ZERO;
    repeat(5) tick; rst_n=1; repeat(2) tick;

    // ---------------------------------------------------
    // A) Simple known run: W={1.0, 0.5, 2.0, 3.0}
    //    Stream X: {1.0, 1.0, 1.0, 1.0}
    //    Expected behavior: output accumulates 1.0*w0 + 1.0*w1 + ...
    // ---------------------------------------------------
    enW=4'b1111;
    W0_i=H_1_0; W1_i=H_0_5; W2_i=H_2_0; W3_i=H_3_0; tick;
    enW=4'b0000;

    stream_x(H_1_0); show();
    stream_x(H_1_0); show();
    stream_x(H_1_0); show();
    stream_x(H_1_0); show();
    repeat(6) tick; // allow pipeline to flush a bit

    // ---------------------------------------------------
    // B) Presentation vectors (PLACEHOLDER—fill exact FP16 hex):
    //    w = {3.75, 1.76, -0.52, 0.36}
    //    x = {1.52, 2.75, 3.86, -1.47, 8.98, -6.52, 3.61}
    //    Example below uses 3.75 and simple substitutes for illustration.
    // ---------------------------------------------------
    enW=4'b1111;
    W0_i=16'h4380; /* 3.75         */
    W1_i=16'h3A00; /* ~1.25  (TODO replace with exact 1.76 half) */
    W2_i=16'hB800; /* -0.5   (TODO replace with exact -0.52 half) */
    W3_i=16'h3947; /* ~0.285 (TODO replace with exact 0.36  half) */
    tick; enW=4'b0000;

    stream_x(16'h3C26); /* ~1.52  */ show();
    stream_x(16'h4020); /* ~2.75  */ show();
    stream_x(16'h409C); /* ~3.86  */ show();
    stream_x(16'hBDE0); /* ~-1.47 */ show();
    stream_x(16'h410F); /* ~8.98  */ show();
    stream_x(16'hC1A6); /* ~-6.52 */ show();
    stream_x(16'h4067); /* ~3.61  */ show();
    repeat(10) tick;

    // ---------------------------------------------------
    // C) Overflow-weight scenario (w0 = +Inf)
    // ---------------------------------------------------
    enW=4'b1111;
    W0_i=H_INF; W1_i=H_0_5; W2_i=H_1_0; W3_i=H_3_5; tick;
    enW=4'b0000;

    stream_x(H_1_0); show(); // Any non-zero X with w0=Inf should propagate Inf in accumulation path
    stream_x(H_1_0); show();
    repeat(6) tick;

    $display("=== tb_mac_row4: done ===");
    $finish;
  end

endmodule