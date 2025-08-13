//=======================================================
//  File Name:    mac_row4.v
//  Description:  Chain of 4 FP16 MAC units (systolic row).
//                Weights are preloaded; input X streams each cycle.
//                Final output updates every cycle after pipeline fill.
//  Author:       Jooho Hwang
//  Created:      2025-08-12
//  Revision:     1.1 (Phase 2: tidy ports/comments)
//=======================================================

`include "fp16_defs.vh"

module mac_row4 (
    input  wire                    clk,
    input  wire                    rst_n,

    // stream control
    input  wire                    enX,       // stream enable for X
    input  wire [3:0]              enW,       // preload enables for each weight

    // data
    input  wire [`FP16_WIDTH-1:0]  X_i,       // streaming input
    input  wire [`FP16_WIDTH-1:0]  W0_i,      // weights to preload
    input  wire [`FP16_WIDTH-1:0]  W1_i,
    input  wire [`FP16_WIDTH-1:0]  W2_i,
    input  wire [`FP16_WIDTH-1:0]  W3_i,

    output wire [`FP16_WIDTH-1:0]  Y_o,       // final output
    output wire                    finish     // valid pulse at last stage
);

//-------------------------------------------------------
// 1) Weight registers
//-------------------------------------------------------
reg [`FP16_WIDTH-1:0] W0, W1, W2, W3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        W0 <= `FP16_POS_ZERO;
        W1 <= `FP16_POS_ZERO;
        W2 <= `FP16_POS_ZERO;
        W3 <= `FP16_POS_ZERO;
    end else begin
        if (enW[0]) W0 <= W0_i;
        if (enW[1]) W1 <= W1_i;
        if (enW[2]) W2 <= W2_i;
        if (enW[3]) W3 <= W3_i;
    end
end

//-------------------------------------------------------
// 2) MAC chain wiring
//-------------------------------------------------------
wire [`FP16_WIDTH-1:0] y0, y1, y2, y3;
wire v0, v1, v2, v3;

fp_mac uMAC0 (
    .clk(clk), .rst_n(rst_n),
    .opA (X_i),  .opB (W0),  .opADD(`FP16_POS_ZERO),
    .enA (enX),  .enB (enX), .enADD(1'b1),              // opADD fixed zero
    .en_Mul_A(enX), .en_Mul_B(enX),
    .en_Add_A(1'b1), .en_Add_B(1'b1),
    .out_o(y0), .val_o(v0)
);

fp_mac uMAC1 (
    .clk(clk), .rst_n(rst_n),
    .opA (X_i),  .opB (W1),  .opADD(y0),
    .enA (enX),  .enB (enX), .enADD(v0),
    .en_Mul_A(enX), .en_Mul_B(enX),
    .en_Add_A(v0), .en_Add_B(v0),
    .out_o(y1), .val_o(v1)
);

fp_mac uMAC2 (
    .clk(clk), .rst_n(rst_n),
    .opA (X_i),  .opB (W2),  .opADD(y1),
    .enA (enX),  .enB (enX), .enADD(v1),
    .en_Mul_A(enX), .en_Mul_B(enX),
    .en_Add_A(v1), .en_Add_B(v1),
    .out_o(y2), .val_o(v2)
);

fp_mac uMAC3 (
    .clk(clk), .rst_n(rst_n),
    .opA (X_i),  .opB (W3),  .opADD(y2),
    .enA (enX),  .enB (enX), .enADD(v2),
    .en_Mul_A(enX), .en_Mul_B(enX),
    .en_Add_A(v2), .en_Add_B(v2),
    .out_o(y3), .val_o(v3)
);

assign Y_o   = y3;
assign finish = v3;

endmodule