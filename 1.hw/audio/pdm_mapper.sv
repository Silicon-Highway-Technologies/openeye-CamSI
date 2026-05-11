module pdm_mapper (
  input clk,
  input rst,
  input pdm_pulse,
  input mdata,
  output logic [23:0] pdm_mapped
);

// increments pdm sum for 1'b1, decrements for 1'b0 //

always@(posedge clk) begin

  if (!rst) begin
    pdm_mapped <= 24'sd0;
  end 

  else if (pdm_pulse) begin
    if (mdata == 1'b1) pdm_mapped <= 24'h1; // +1 //
    else pdm_mapped <= 24'hFF_FF_FF;        // -1 //
  end

end

endmodule