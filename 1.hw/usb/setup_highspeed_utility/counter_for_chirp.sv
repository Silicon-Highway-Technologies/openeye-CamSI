module counter_for_chirp(
    input clk,
    input rst,
    input counter_active,
    output done
);

logic [16:0] counter;

always @(posedge clk) begin

    if (!rst) counter <= 17'b0;

    else if (counter_active) counter <= counter + 1'b1;

end

assign done = (counter == 17'b1_0111_1111_1111_1111); // ~1.5ms


endmodule