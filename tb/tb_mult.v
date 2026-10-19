`timescale 1ns / 1ps
// Exhaustive, self-checking testbench for mult_array.
//
// * 10 ns clock, rst_n held low for the first 2 cycles (0-20 ns).
// * Applies all 256 (a, b) pairs, one new pair every clock cycle.
// * Vector k is applied on a falling edge, captured into the input registers on
//   the next rising edge (edge 1) and into p on the rising edge after that (edge 2).
//   The checker compares p with a * b exactly LATENCY = 2 cycles later, so a design
//   with the wrong latency fails.
// * Prints one line per mismatch and a single PASS/FAIL summary line.
// * Writes the waveform to mult.vcd.
//
// Works unchanged for the RTL and for the synthesized gate-level netlist.
module tb_mult;

    localparam LATENCY = 2;      // clock cycles from input to registered product
    localparam NVEC    = 256;    // a = 0..15, b = 0..15

    reg        clk;
    reg        rst_n;
    reg  [3:0] a;
    reg  [3:0] b;
    wire [7:0] p;

    mult_array dut (
        .clk   (clk),
        .rst_n (rst_n),
        .a     (a),
        .b     (b),
        .p     (p)
    );

    // 10 ns period: rising edges at 5, 15, 25, ... ns; falling edges at 10, 20, ...
    initial clk = 1'b0;
    always #5 clk = ~clk;

    integer   i;                  // index of the vector being applied
    integer   k;                  // index of the vector being checked (i - LATENCY)
    integer   errors  = 0;
    integer   checked = 0;
    reg [3:0] ea, eb;             // a and b of the vector being checked
    reg [7:0] expected;

    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);
        $timeformat(-9, 0, " ns", 0);                 // print %t values in ns

        // ---------------- reset: low for the first 2 clock cycles ----------------
        rst_n = 1'b0;
        a     = 4'd0;
        b     = 4'd0;
        repeat (2) @(posedge clk);
        @(negedge clk);                               // t = 20 ns
        if (p !== 8'd0) begin
            errors = errors + 1;
            $display("MISMATCH: p = %b while rst_n = 0, expected 0", p);
        end
        rst_n = 1'b1;

        // ---------------- apply and check all 256 vectors ----------------
        // Inputs change on the falling edge, half a cycle away from the rising
        // edge the DUT samples on, so there is no race between TB and DUT.
        for (i = 0; i < NVEC + LATENCY; i = i + 1) begin
            @(negedge clk);

            // check the vector applied LATENCY cycles ago
            if (i >= LATENCY) begin
                k        = i - LATENCY;
                {ea, eb} = k[7:0];                    // a = k[7:4], b = k[3:0]
                expected = ea * eb;                   // '*' allowed in the testbench only
                checked  = checked + 1;
                if (p !== expected) begin             // !== also flags X/Z as errors
                    errors = errors + 1;
                    $display("MISMATCH at %0t: a=%0d b=%0d expected p=%0d got p=%0d",
                             $time, ea, eb, expected, p);
                end
            end

            // apply the next vector: a = i[7:4], b = i[3:0]
            if (i < NVEC)
                {a, b} = i[7:0];
        end

        // ---------------- single summary line ----------------
        if (errors == 0)
            $display("PASS: %0d vectors checked, %0d errors", checked, errors);
        else
            $display("FAIL: %0d vectors checked, %0d errors", checked, errors);

        $finish;
    end

endmodule
