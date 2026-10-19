`timescale 1ns / 1ps
// 1-bit full adder: sum = a + b + cin (2-bit result {cout, sum}).
// Purely combinational, written with continuous assignments.
module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);

    assign sum  = a ^ b ^ cin;                       // odd number of 1s
    assign cout = (a & b) | (a & cin) | (b & cin);   // majority: at least two 1s

endmodule
