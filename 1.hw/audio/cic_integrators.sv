module cic_integrators (
  input clk,
  input rst,
  input pdm_pulse,
  input [23:0] din,
  output logic [23:0] dout
);

logic [23:0] int1, int2, int3;

always@(posedge clk) begin
  if (!rst) begin
    int1 <= 24'b0;
    int2 <= 24'b0;
    int3 <= 24'b0;
  end 
  else if (pdm_pulse) begin
    int1 <= int1 + din;
    int2 <= int2 + int1;
    int3 <= int3 + int2;
  end
end

assign dout = int3;

endmodule