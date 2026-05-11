module dc_blocker (
  input clk,
  input rst,
  input pcm_pulse,         
  input [23:0] din,
  output logic [15:0] dout
);

// this module removes the DC bias //

logic [23:0] dc_offset;
logic [23:0] centered_wave;

logic [23:0] diff;
assign diff = din - dc_offset;

// manual sign extension by shifting to the right //
logic [23:0] shifted_diff;
assign shifted_diff = { {8{diff[23]}}, diff[23:8] };

always @(posedge clk) begin
  if (!rst) begin
    dc_offset <= 24'd0;
  end 
  else if (pcm_pulse) begin
    dc_offset <= dc_offset + shifted_diff; // DC average updated by right shift (division by 256) //
  end
end

// subtract the DC average to center it at 0 //
assign centered_wave = din - dc_offset;

// keep the bits in the middle for a medium volume //
assign dout = centered_wave[18:3]; // originally [20:5] but [18:3] produces louder audio and seems more preferable

endmodule