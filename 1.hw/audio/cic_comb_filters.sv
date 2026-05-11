module cic_comb_filters (
  input clk,
  input rst,
  input pcm_pulse,
  input [23:0] din,
  output logic [23:0] dout
);

// memory registers to hold the previous samples ( x[n-1] ) //
logic [23:0] delay1, delay2, delay3;

// registers to hold the output of the subtractions //
logic [23:0] comb1, comb2, comb3;

always @(posedge clk) begin
  if (!rst) begin
    delay1 <= 24'b0;
    delay2 <= 24'b0;
    delay3 <= 24'b0;
    
    comb1  <= 24'b0;
    comb2  <= 24'b0;
    comb3  <= 24'b0;
  end 
  
  else if (pcm_pulse) begin // we do the operations only when the pulse is active
    
    // first update the delay memories with the current values //
    delay1 <= din;
    delay2 <= comb1;
    delay3 <= comb2;
    
    // then perform the subtractions //
    comb1 <= din - delay1;
    comb2 <= comb1 - delay2;
    comb3 <= comb2 - delay3;
    
  end
end

// pass the final filtered wave out //
assign dout = comb3;

endmodule