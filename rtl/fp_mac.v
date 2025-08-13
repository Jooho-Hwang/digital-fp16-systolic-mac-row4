//=======================================================
//  File Name:    fp_mac.v
//  Description:  FP16 multiply-accumulate with minimal pipeline.
//                MUL/ADD are pure combinational; this module adds
//                input/mid/output registers controlled by enables.
//  Author:       Jooho Hwang
//  Created:      2025-08-12
//  Revision:     1.1 (Phase 2: tidy ports/comments)
//
//  Dependencies: fp16_defs.vh, fp_mul.v, fp_add.v
//=======================================================

`include "fp16_defs.vh"

module fp_mac (
    input  wire                    clk,
    input  wire                    rst_n,

    // Input operands (captured when enA/enB/enADD asserted)
    input  wire [`FP16_WIDTH-1:0] opA,
    input  wire [`FP16_WIDTH-1:0] opB,
    input  wire [`FP16_WIDTH-1:0] opADD,

    input  wire                    enA,
    input  wire                    enB,
    input  wire                    enADD,

    // Pipeline enables
    input  wire                    en_Mul_A,
    input  wire                    en_Mul_B,
    input  wire                    en_Add_A,
    input  wire                    en_Add_B,

    output wire [`FP16_WIDTH-1:0] out_o,
    output wire                    val_o
);

//-------------------------------------------------------
// 1) Input registers
//-------------------------------------------------------
reg [`FP16_WIDTH-1:0] opA_reg, opB_reg, opADD_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        opA_reg   <= `FP16_POS_ZERO;
        opB_reg   <= `FP16_POS_ZERO;
        opADD_reg <= `FP16_POS_ZERO;
    end else begin
        if (enA)   opA_reg   <= opA;
        if (enB)   opB_reg   <= opB;
        if (enADD) opADD_reg <= opADD;
    end
end

//-------------------------------------------------------
// 2) Combinational MUL/ADD instances
//-------------------------------------------------------
wire [`FP16_WIDTH-1:0] mul_y;
wire [`FP16_WIDTH-1:0] add_y;

fp_mul u_mul (
    .a (en_Mul_A ? opA_reg : `FP16_POS_ZERO),
    .b (en_Mul_B ? opB_reg : `FP16_POS_ZERO),
    .y (mul_y)
);

fp_add u_add (
    .a (en_Add_A ? mul_y    : `FP16_POS_ZERO),
    .b (en_Add_B ? opADD_reg: `FP16_POS_ZERO),
    .y (add_y)
);

//-------------------------------------------------------
// 3) Mid/Output registers + valid
//-------------------------------------------------------
reg [`FP16_WIDTH-1:0] mul_reg, out_reg;
reg                   val_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mul_reg <= `FP16_POS_ZERO;
        out_reg <= `FP16_POS_ZERO;
        val_reg <= 1'b0;
    end else begin
        // Store MUL result when both mul enables are high
        if (en_Mul_A && en_Mul_B) begin
            mul_reg <= mul_y;
        end
        // Store ADD result when both add enables are high
        if (en_Add_A && en_Add_B) begin
            out_reg <= add_y;
            val_reg <= 1'b1;
        end else begin
            val_reg <= 1'b0;
        end
    end
end

assign out_o = out_reg;
assign val_o = val_reg;

endmodule