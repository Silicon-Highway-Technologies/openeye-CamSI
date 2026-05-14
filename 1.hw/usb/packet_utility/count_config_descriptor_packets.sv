module count_config_descriptor_packets(

  input clk,
  input rst,
  input reset_packet_counter,
  input new_packet,
  output logic [2:0] packet_counter

);

// this module increases a counter that counts how many config descriptor packets have arrived //

always @(posedge clk) begin

  if ((!rst) || (reset_packet_counter)) packet_counter <= 3'b0;

  else if (new_packet) packet_counter <= packet_counter + 1'b1;

end

endmodule