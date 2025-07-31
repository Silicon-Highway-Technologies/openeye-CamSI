
// detects the rising edge of a signal //

module edge_detector (
    input clk,
    input rst,
    input in,
    output logic out
);

    logic tmp;

    always @(posedge clk) begin
        if (rst) begin
            tmp <= 0;
            out <= 0;
        end else begin
            tmp <= in;
            out <= in & ~tmp;
        end
    end

endmodule
