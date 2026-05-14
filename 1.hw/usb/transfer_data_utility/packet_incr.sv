module packet_incr(

  input clk,
  input rst,
  input new_packet_flag,
  output logic [31:0] current_packet
);

// this module increases the current packet when a flag is activated //

always @(posedge clk) begin

  if (!rst) current_packet <= 32'b0;

  else if (new_packet_flag) current_packet <= current_packet + 1'b1;

end

endmodule