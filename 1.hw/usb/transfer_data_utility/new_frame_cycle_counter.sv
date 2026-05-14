module new_frame_cycle_counter(
  input clk,
  input rst,
  input active_flag,
  output logic fid_bit,
  output logic new_frame
);

logic [19:0] counter;
logic active;

always @(posedge clk) begin

  if (!rst) active <= 1'b0;
  else if (active_flag) active <= 1'b1;

end

always @(posedge clk) begin

  if (!rst || new_frame) counter <= 20'b0;

  else if (active) counter <= counter + 1'b1;

end

assign new_frame = (counter == 20'b11110100001001000000); // 1/60th of a second //

always @(posedge clk) begin

  if (!rst) fid_bit <= 1'b0;

  else if (new_frame) fid_bit <= ~fid_bit;

end

endmodule