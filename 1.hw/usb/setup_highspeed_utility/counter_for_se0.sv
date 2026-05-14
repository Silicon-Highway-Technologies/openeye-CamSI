module counter_for_se0(
    input clk,
    input rst,
    input counter_active,
    output logic done
);

// must measure 2.5us //

logic [11:0] counter;

always @(posedge clk) begin

    if (!rst || !counter_active) counter <= 12'b0;

    else if (counter_active) counter <= counter + 1'b1;

end

logic countermax;

assign countermax = (counter == 8'd151); // ~2.5us //

always @(posedge clk) begin

    if (!rst || !counter_active) done <= 0;

    else if (countermax) done <= 1'b1;

end


endmodule