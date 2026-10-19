`timescale 1ns / 1ps
// 4-bit x 4-bit unsigned array multiplier (8-bit product).
//
//   a, b --> [input regs, 8 FF] --> 16 AND + 12 full_adder array --> [output reg, 8 FF] --> p
//
// 16 flip-flops in total, latency = 2 clock cycles, throughput = 1 product per cycle.
// Row connections follow Section 2 of the assignment exactly. The '*' operator is not used.
module mult_array (
    input  wire       clk,     // rising-edge clock
    input  wire       rst_n,   // asynchronous reset, active low: clears all registers to 0
    input  wire [3:0] a,       // multiplicand
    input  wire [3:0] b,       // multiplier
    output reg  [7:0] p        // registered product a x b
);

    // ------------------------------------------------------------------
    // Input registers (2 x 4 = 8 flip-flops)
    // ------------------------------------------------------------------
    reg [3:0] a_r, b_r;

    // ------------------------------------------------------------------
    // Partial products: ppi[j] = a[j] AND b[i]   (4 x 4 = 16 AND gates)
    // ------------------------------------------------------------------
    wire [3:0] pp0, pp1, pp2, pp3;

    assign pp0 = a_r & {4{b_r[0]}};
    assign pp1 = a_r & {4{b_r[1]}};
    assign pp2 = a_r & {4{b_r[2]}};
    assign pp3 = a_r & {4{b_r[3]}};

    // ------------------------------------------------------------------
    // Row 0: no adders. pp0[0] is product bit 0, the rest passes down.
    //   r0 = {0, pp0[3], pp0[2], pp0[1]}
    // ------------------------------------------------------------------
    wire [3:0] r0;
    assign r0 = {1'b0, pp0[3], pp0[2], pp0[1]};

    // ------------------------------------------------------------------
    // Row 1: full adder j adds pp1[j] + r0[j] + c1[j], c1[0] = 0
    //   p[1] = s1[0],  r1 = {c1[4], s1[3], s1[2], s1[1]}
    // ------------------------------------------------------------------
    wire [3:0] s1;
    wire [4:0] c1;
    assign c1[0] = 1'b0;

    full_adder fa1_0 (.a(pp1[0]), .b(r0[0]), .cin(c1[0]), .sum(s1[0]), .cout(c1[1]));
    full_adder fa1_1 (.a(pp1[1]), .b(r0[1]), .cin(c1[1]), .sum(s1[1]), .cout(c1[2]));
    full_adder fa1_2 (.a(pp1[2]), .b(r0[2]), .cin(c1[2]), .sum(s1[2]), .cout(c1[3]));
    full_adder fa1_3 (.a(pp1[3]), .b(r0[3]), .cin(c1[3]), .sum(s1[3]), .cout(c1[4]));

    wire [3:0] r1;
    assign r1 = {c1[4], s1[3], s1[2], s1[1]};

    // ------------------------------------------------------------------
    // Row 2: full adder j adds pp2[j] + r1[j] + c2[j], c2[0] = 0
    //   p[2] = s2[0],  r2 = {c2[4], s2[3], s2[2], s2[1]}
    // ------------------------------------------------------------------
    wire [3:0] s2;
    wire [4:0] c2;
    assign c2[0] = 1'b0;

    full_adder fa2_0 (.a(pp2[0]), .b(r1[0]), .cin(c2[0]), .sum(s2[0]), .cout(c2[1]));
    full_adder fa2_1 (.a(pp2[1]), .b(r1[1]), .cin(c2[1]), .sum(s2[1]), .cout(c2[2]));
    full_adder fa2_2 (.a(pp2[2]), .b(r1[2]), .cin(c2[2]), .sum(s2[2]), .cout(c2[3]));
    full_adder fa2_3 (.a(pp2[3]), .b(r1[3]), .cin(c2[3]), .sum(s2[3]), .cout(c2[4]));

    wire [3:0] r2;
    assign r2 = {c2[4], s2[3], s2[2], s2[1]};

    // ------------------------------------------------------------------
    // Row 3: full adder j adds pp3[j] + r2[j] + c3[j], c3[0] = 0
    //   p[3] = s3[0],  p[7:4] = {c3[4], s3[3], s3[2], s3[1]}
    // ------------------------------------------------------------------
    wire [3:0] s3;
    wire [4:0] c3;
    assign c3[0] = 1'b0;

    full_adder fa3_0 (.a(pp3[0]), .b(r2[0]), .cin(c3[0]), .sum(s3[0]), .cout(c3[1]));
    full_adder fa3_1 (.a(pp3[1]), .b(r2[1]), .cin(c3[1]), .sum(s3[1]), .cout(c3[2]));
    full_adder fa3_2 (.a(pp3[2]), .b(r2[2]), .cin(c3[2]), .sum(s3[2]), .cout(c3[3]));
    full_adder fa3_3 (.a(pp3[3]), .b(r2[3]), .cin(c3[3]), .sum(s3[3]), .cout(c3[4]));

    // ------------------------------------------------------------------
    // Combinational product (input of the output register)
    // ------------------------------------------------------------------
    wire [7:0] prod;
    assign prod = {c3[4], s3[3], s3[2], s3[1],    // p[7:4]
                   s3[0],                         // p[3]
                   s2[0],                         // p[2]
                   s1[0],                         // p[1]
                   pp0[0]};                       // p[0]

    // ------------------------------------------------------------------
    // Registers: 4 (a_r) + 4 (b_r) + 8 (p) = 16 flip-flops.
    // Edge 1 captures a, b into a_r, b_r; edge 2 captures prod into p.
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r <= 4'd0;
            b_r <= 4'd0;
            p   <= 8'd0;
        end else begin
            a_r <= a;
            b_r <= b;
            p   <= prod;
        end
    end

endmodule
