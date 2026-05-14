// count for 26 + 3 = 29 bytes

module out_packet_byte_counter(
  input clk,
  input rst,
  input active,
  input reset_counter,
  output logic done
);

logic [4:0] counter;

always @(posedge clk) begin

  if (!rst || reset_counter) counter <= 5'b0;

  else if (active && !done) counter <= counter + 1'b1;
end

assign done = (counter == 5'd29);

endmodule