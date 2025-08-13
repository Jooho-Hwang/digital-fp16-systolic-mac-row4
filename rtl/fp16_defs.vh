//=======================================================
//  File Name:    fp16_defs.vh
//  Description:  Common defines for IEEE 754 half-precision (FP16).
//                Used by fp_mul.v / fp_add.v / fp_mac.v / mac_row4.v.
//  Author:       Jooho Hwang
//  Created:      2025-08-12
//  Revision:     1.0
//
//  Notes:
//    - Exponent bias = 15
//    - Overflow is represented as ±Inf (Exp=31, Man=0)
//    - Denormalized numbers: Exp=0, Man!=0 (implicit leading 0)
//=======================================================

`ifndef __FP16_DEFS_VH__
`define __FP16_DEFS_VH__

//-------------------------------------------------------
// Widths & positions
//-------------------------------------------------------
`define FP16_SIGN_W   1
`define FP16_EXP_W    5
`define FP16_MAN_W    10
`define FP16_WIDTH    16

`define FP16_SIGN_MSB 15
`define FP16_EXP_MSB  14
`define FP16_EXP_LSB  10
`define FP16_MAN_MSB  9
`define FP16_MAN_LSB  0

// Bias and exponent limits
`define FP16_BIAS       15
`define FP16_EXP_MAX    31
`define FP16_EXP_MIN     0
`define FP16_EXP_DENORM  0
`define FP16_EXP_INF     31

//-------------------------------------------------------
// Field extractors
//-------------------------------------------------------
`define FP16_SIGN(x)  ( (x)[`FP16_SIGN_MSB] )
`define FP16_EXP(x)   ( (x)[`FP16_EXP_MSB:`FP16_EXP_LSB] )
`define FP16_MAN(x)   ( (x)[`FP16_MAN_MSB:`FP16_MAN_LSB] )

//-------------------------------------------------------
// Pack / Unpack helpers
//-------------------------------------------------------
`define FP16_PACK(s,e,m)  { (s)[0], (e)[`FP16_EXP_W-1:0], (m)[`FP16_MAN_W-1:0] }

//-------------------------------------------------------
// Canonical constants
//-------------------------------------------------------
`define FP16_POS_ZERO   16'h0000
`define FP16_NEG_ZERO   16'h8000
`define FP16_POS_INF    16'h7C00   // Exp=31, Man=0
`define FP16_NEG_INF    16'hFC00   // Exp=31, Man=0

//-------------------------------------------------------
// Classification
//-------------------------------------------------------
// Zero:     exp==0 && man==0
// Denorm:   exp==0 && man!=0
// Inf:      exp==31 && man==0
// NaN:      exp==31 && man!=0  (not expected here; treat as Inf if appears)
`define FP16_IS_ZERO(x)   ( (`FP16_EXP(x)==`FP16_EXP_DENORM) && (`FP16_MAN(x)==0) )
`define FP16_IS_DENORM(x) ( (`FP16_EXP(x)==`FP16_EXP_DENORM) && (`FP16_MAN(x)!=0) )
`define FP16_IS_INF(x)    ( (`FP16_EXP(x)==`FP16_EXP_INF)    && (`FP16_MAN(x)==0) )
`define FP16_IS_NAN(x)    ( (`FP16_EXP(x)==`FP16_EXP_INF)    && (`FP16_MAN(x)!=0) )

//-------------------------------------------------------
// Implicit leading bit
//-------------------------------------------------------
// For normalized: 1.mant → {1'b1, mant}
// For denormal:   0.mant → {1'b0, mant}
`define FP16_IMP_NORM(man)  {1'b1, (man)}
`define FP16_IMP_DEN(man)   {1'b0, (man)}

//-------------------------------------------------------
// Rounding (guide)
//-------------------------------------------------------
// Guard bit = bit just below LSB of mantissa to be kept.
// If guard==1 → round up (add 1 to mantissa), else truncate.
// Handle mantissa overflow by incrementing exponent; if exponent
// reaches 31, clamp to ±Inf.
// Implementation is left to module logic (see fp_mul.v / fp_add.v).
//-------------------------------------------------------

`endif // __FP16_DEFS_VH__