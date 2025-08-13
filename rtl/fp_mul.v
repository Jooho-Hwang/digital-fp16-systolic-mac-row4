//=======================================================
//  File Name:    fp_mul.v
//  Description:  IEEE 754 half-precision (FP16) floating-point multiplier.
//                • Pure combinational (no clock)
//                • Supports zero, denormalized, normalized, overflow/Inf
//                • Guard-bit rounding: (LSB-1 == 1) → round up, else truncate
//
//  Conventions:
//    - Exponent bias = `FP16_BIAS` (15)
//    - Denormal exponent treated as -14 with implicit leading 0
//    - If any operand is Inf/overflow (or NaN) → result is Inf (sign = a^b)
//    - If any operand is Zero and no overflow present → result is signed Zero
//
//  Dependencies: fp16_defs.vh
//=======================================================

`include "fp16_defs.vh"

module fp_mul (
    input  wire [`FP16_WIDTH-1:0] a,   // Operand A (FP16)
    input  wire [`FP16_WIDTH-1:0] b,   // Operand B (FP16)
    output wire [`FP16_WIDTH-1:0] y    // Result (FP16)
);

//-------------------------------------------------------
// 1) Quick classification & basic fields
//-------------------------------------------------------
wire        s_a = `FP16_SIGN(a);
wire [4:0]  e_a = `FP16_EXP(a);
wire [9:0]  m_a = `FP16_MAN(a);

wire        s_b = `FP16_SIGN(b);
wire [4:0]  e_b = `FP16_EXP(b);
wire [9:0]  m_b = `FP16_MAN(b);

wire is_zero_a = `FP16_IS_ZERO(a);
wire is_zero_b = `FP16_IS_ZERO(b);
wire is_den_a  = `FP16_IS_DENORM(a);
wire is_den_b  = `FP16_IS_DENORM(b);
wire is_inf_a  = `FP16_IS_INF(a);
wire is_inf_b  = `FP16_IS_INF(b);
wire is_nan_a  = `FP16_IS_NAN(a);
wire is_nan_b  = `FP16_IS_NAN(b);

wire special_overflow = is_inf_a || is_inf_b || is_nan_a || is_nan_b;
wire special_zero     = (is_zero_a || is_zero_b) && !special_overflow;
wire sign             = s_a ^ s_b;

//-------------------------------------------------------
// 2) Decode to signed exponent and implicit mantissas
//    Denormal: exponent = -14, implicit leading = 0
//-------------------------------------------------------
wire [10:0] ma_imp = is_den_a ? `FP16_IMP_DEN(m_a) : `FP16_IMP_NORM(m_a); // 11 bits
wire [10:0] mb_imp = is_den_b ? `FP16_IMP_DEN(m_b) : `FP16_IMP_NORM(m_b); // 11 bits

// Signed exponents in 7 bits: E = exp - bias (or -14 for denorm)
wire signed [6:0] Ea = is_den_a ? -7'sd14 : $signed({2'b00, e_a}) - $signed(7'd`FP16_BIAS);
wire signed [6:0] Eb = is_den_b ? -7'sd14 : $signed({2'b00, e_b}) - $signed(7'd`FP16_BIAS);

//-------------------------------------------------------
// 3) Multiply significands and add exponents
//    11b x 11b → 22b product; exponent pre-sum in 8 bits
//-------------------------------------------------------
wire [21:0]           prod = ma_imp * mb_imp;     // 22-bit product
wire signed [7:0]     Esum = Ea + Eb;             // pre-normalization exponent

//-------------------------------------------------------
// 4) Normalization support
//    Goal: normalize so that the leading '1' is at bit [20]
//          (i.e., value looks like 1.xxx in fixed-point)
//    Strategy:
//      - If prod[21] == 1 → shift right by 1, exponent++
//      - Else find MSB index (0..21), shift left so that it lands at 20
//        and decrement exponent accordingly
//-------------------------------------------------------

// Find index of the most-significant '1' in a 22-bit vector.
// If none (should not happen unless inputs are zero), msb_valid=0.
function automatic [5:0] msb_index22; // returns 0..21, or 63 if none
    input [21:0] x;
    integer i;
    begin
        msb_index22 = 6'd63; // sentinel = "none found"
        for (i = 21; i >= 0; i = i - 1) begin
            if (x[i]) begin
                msb_index22 = i[5:0];
                // break
                i = -1;
            end
        end
    end
endfunction

wire [5:0] msb_idx = msb_index22(prod);
wire       msb_valid = (msb_idx != 6'd63);

// Compute normalized fraction (22b) and adjusted exponent (signed 8b)
reg  [21:0] frac_norm;
reg  signed [7:0] Eadj;

always @* begin
    // Default to zeros (safe)
    frac_norm = 22'd0;
    Eadj      = Esum;

    if (msb_valid) begin
        if (prod[21]) begin
            // Leading '1' already at 21 → shift right by 1 to target 20
            frac_norm = prod >> 1;
            Eadj      = Esum + 1;
        end else begin
            // Shift left so that MSB goes to bit 20
            // Shift amount = 20 - msb_idx  (msb_idx <= 20 here)
            integer shl;
            shl  = 20 - msb_idx;
            frac_norm = prod << shl;
            Eadj      = Esum - shl;
        end
    end
end

//-------------------------------------------------------
// 5) Rounding (guard-bit only, as specified)
//    Keep mantissa[19:10]; guard = bit[9]
//    If guard==1 → add 1; handle carry into exponent
//-------------------------------------------------------
wire [9:0] mant_trunc     = frac_norm[19:10];
wire       guard_bit      = frac_norm[9];
wire [10:0] mant_rounded_ext = {1'b0, mant_trunc} + (guard_bit ? 11'd1 : 11'd0);
wire        mant_carry    = mant_rounded_ext[10];
wire [9:0]  mant_rounded  = mant_rounded_ext[9:0];

wire signed [7:0] Eround   = Eadj + (mant_carry ? 1 : 0);

//-------------------------------------------------------
// 6) Final encode with special cases and range checks
//-------------------------------------------------------
reg [15:0] y_r;

always @* begin
    // Priority: overflow/Inf/NaN → Inf (signed), then Zero, else normal path
    if (special_overflow) begin
        y_r = sign ? `FP16_NEG_INF : `FP16_POS_INF;
    end else if (special_zero || !msb_valid) begin
        // !msb_valid is defensive; normally covered by special_zero
        y_r = sign ? `FP16_NEG_ZERO : `FP16_POS_ZERO;
    end else begin
        // Convert signed exponent back to FP16 exponent field with bias
        // Check overflow (to ±Inf) and underflow/denorm
        // Thresholds: Efield = Eround + BIAS
        //   - If Efield >= 31 → Inf
        //   - If Efield <= 0   → denorm or zero
        wire signed [8:0] Efield_signed = $signed({1'b0, Eround}) + $signed(8'd`FP16_BIAS);
        if (Efield_signed >= 9'sd31) begin
            // Overflow → Inf
            y_r = sign ? `FP16_NEG_INF : `FP16_POS_INF;
        end else if (Efield_signed <= 9'sd0) begin
            // Denormal (or underflow to zero):
            // Build a 21-bit source like 1.mant_rounded << 10, then right shift
            // by (1 - Efield_signed) to create a denorm mantissa.
            integer shift_amt;
            reg [20:0] den_src;
            reg [9:0]  den_man;

            shift_amt = (1 - Efield_signed); // >= 1
            if (shift_amt >= 21) begin
                y_r = sign ? `FP16_NEG_ZERO : `FP16_POS_ZERO;
            end else begin
                den_src = {1'b1, mant_rounded, 10'd0};    // "1.mant" as 21 bits
                den_man = (den_src >> shift_amt)[20:11];  // pick 10 bits
                if (den_man == 10'd0)
                    y_r = sign ? `FP16_NEG_ZERO : `FP16_POS_ZERO;
                else
                    y_r = `FP16_PACK(sign, 5'd0, den_man); // exp=0 → denorm
            end
        } else begin
            // Normalized encode
            wire [4:0] Efield = Efield_signed[4:0]; // 1..30 guaranteed here
            y_r = `FP16_PACK(sign, Efield, mant_rounded);
        end
    end
end

assign y = y_r;

endmodule