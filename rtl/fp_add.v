//=======================================================
//  File Name:    fp_add.v
//  Description:  IEEE 754 half-precision (FP16) floating point adder.
//                Pure combinational logic (no clock).
//                Supports denormalized numbers, zero, overflow.
//  Author:       Jooho Hwang
//  Created:      2025-08-12
//  Revision:     1.1 (Phase 2: defs.vh macros applied)
//
//  Dependencies: fp16_defs.vh
//
//  Notes:
//    - Align smaller exponent to larger one, guard-bit rounding
//    - Overflow dominance: if any operand is Inf → Inf
//=======================================================

`include "fp16_defs.vh"

module fp_add (
    input  wire [`FP16_WIDTH-1:0] a,   // Operand A (FP16)
    input  wire [`FP16_WIDTH-1:0] b,   // Operand B (FP16)
    output wire [`FP16_WIDTH-1:0] y    // Result (FP16)
);

//-------------------------------------------------------
// 1) Quick classify / special cases
//-------------------------------------------------------
wire s_a = `FP16_SIGN(a);
wire s_b = `FP16_SIGN(b);
wire [4:0] e_a = `FP16_EXP(a);
wire [4:0] e_b = `FP16_EXP(b);
wire [9:0] m_a = `FP16_MAN(a);
wire [9:0] m_b = `FP16_MAN(b);

wire is_zero_a = `FP16_IS_ZERO(a);
wire is_zero_b = `FP16_IS_ZERO(b);
wire is_den_a  = `FP16_IS_DENORM(a);
wire is_den_b  = `FP16_IS_DENORM(b);
wire is_inf_a  = `FP16_IS_INF(a);
wire is_inf_b  = `FP16_IS_INF(b);
wire is_nan_a  = `FP16_IS_NAN(a);
wire is_nan_b  = `FP16_IS_NAN(b);

wire special_overflow = is_inf_a || is_inf_b || is_nan_a || is_nan_b;

wire same_sign = (s_a == s_b);

//-------------------------------------------------------
// 2) Decode to aligned significands (with hidden bit)
//    Denorm exponent fixed to -14, hidden=0
//-------------------------------------------------------
wire [10:0] ma_imp = is_den_a ? `FP16_IMP_DEN(m_a) : `FP16_IMP_NORM(m_a);
wire [10:0] mb_imp = is_den_b ? `FP16_IMP_DEN(m_b) : `FP16_IMP_NORM(m_b);

wire signed [6:0] Ea = is_den_a ? -7'sd14 : $signed({2'b00,e_a}) - $signed(7'd`FP16_BIAS);
wire signed [6:0] Eb = is_den_b ? -7'sd14 : $signed({2'b00,e_b}) - $signed(7'd`FP16_BIAS);

// choose larger exponent as base
wire use_a = (Ea > Eb) || ((Ea==Eb) && (ma_imp >= mb_imp));
wire signed [6:0] E_big  = use_a ? Ea : Eb;
wire signed [6:0] E_sml  = use_a ? Eb : Ea;
wire [10:0] M_big  = use_a ? ma_imp : mb_imp;
wire [10:0] M_sml  = use_a ? mb_imp : ma_imp;
wire S_big = use_a ? s_a : s_b;
wire S_sml = use_a ? s_b : s_a;

// align smaller mantissa
wire [5:0] shift = (E_big - E_sml); // up to ~30 safe
wire [21:0] M_big_ext = {M_big, 11'd0}; // headroom for later normalization
wire [21:0] M_sml_ext = ({M_sml, 11'd0} >> (shift>21 ? 21 : shift));

//-------------------------------------------------------
// 3) Add/Sub according to signs
//-------------------------------------------------------
wire [21:0] add_res = same_sign ? (M_big_ext + M_sml_ext)
                                : (M_big_ext - M_sml_ext);

wire res_sign = same_sign ? S_big : (M_big_ext >= M_sml_ext ? S_big : ~S_big);

//-------------------------------------------------------
// 4) Normalize result (like MUL path), base exponent = E_big
//-------------------------------------------------------
function [4:0] lzc22;
    input [21:0] x;
    integer i;
    begin
        lzc22 = 0;
        for (i=21; i>=0; i=i-1) begin
            if (x[i]==1'b1) begin
                lzc22 = 21 - i;
                disable for_loop_end;
            end
        end
        for_loop_end: ;
    end
endfunction

wire [4:0] lead_zeros = lzc22(add_res);
wire [21:0] norm_shifted = (lead_zeros<=21) ? (add_res << lead_zeros) : 22'd0;
wire [21:0] norm_frac    = norm_shifted[21] ? (norm_shifted >> 1) : norm_shifted;

wire signed [7:0] Eadj =
    norm_shifted[21] ? (E_big - $signed({3'b000,lead_zeros}) + 1)
                     : (E_big - $signed({3'b000,lead_zeros}));

//-------------------------------------------------------
// 5) Rounding (guard bit)
//-------------------------------------------------------
wire [9:0] mant_trunc  = norm_frac[19:10];
wire       guard_bit   = norm_frac[9];

wire [10:0] mant_rounded_ext = {1'b0, mant_trunc} + (guard_bit ? 11'd1 : 11'd0);
wire        mant_carry = mant_rounded_ext[10];
wire [9:0]  mant_rounded = mant_rounded_ext[9:0];
wire signed [7:0] Eround = Eadj + (mant_carry ? 1 : 0);

//-------------------------------------------------------
// 6) Special cases + encode
//-------------------------------------------------------
reg [15:0] y_r;

always @* begin
    if (special_overflow) begin
        y_r = res_sign ? `FP16_NEG_INF : `FP16_POS_INF;
    end else if (is_zero_a && is_zero_b) begin
        y_r = res_sign ? `FP16_NEG_ZERO : `FP16_POS_ZERO;
    end else begin
        if (Eround + `FP16_BIAS >= 8'sd31) begin
            y_r = res_sign ? `FP16_NEG_INF : `FP16_POS_INF;
        end else if (Eround + `FP16_BIAS <= 8'sd0) begin
            // Denorm / underflow
            integer shift_amt;
            reg [20:0] den_src;
            reg [9:0]  den_man;
            shift_amt = (1 - (Eround + `FP16_BIAS));
            if (shift_amt >= 21) begin
                y_r = res_sign ? `FP16_NEG_ZERO : `FP16_POS_ZERO;
            end else begin
                den_src = {1'b1, mant_rounded, 10'd0};
                den_man = (den_src >> shift_amt)[20:11];
                if (den_man==10'd0) y_r = res_sign ? `FP16_NEG_ZERO : `FP16_POS_ZERO;
                else                y_r = `FP16_PACK(res_sign, 5'd0, den_man);
            end
        end else begin
            wire [4:0] Efield = Eround[4:0] + `FP16_BIAS[4:0];
            y_r = `FP16_PACK(res_sign, Efield, mant_rounded);
        end
    end
end

assign y = y_r;

endmodule