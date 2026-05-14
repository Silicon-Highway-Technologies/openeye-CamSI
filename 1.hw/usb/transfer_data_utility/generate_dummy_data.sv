module generate_dummy_data(
	input clk,
	input rst,
	input start,
	input active,
	input fetch_next,
	input [15:0] num_bytes,
	input sending_crc,
	input [15:0] current_packet,
	output logic [7:0] dummy_data,
	output logic finished
);

// just use a 16-bit counter //

logic [15:0] counter;

always @(posedge clk) begin
  if (!rst) 
    counter <= 16'b0;
  else if (!active) 
    counter <= 16'b0; // Cleanly resets the counter between packets
  else if (fetch_next && !sending_crc) 
    counter <= counter + 1'b1; // Freely increments without being interrupted!
end

wire [15:0] scrambled = (counter + (current_packet << 8)) * 16'hC139; // invalid - fail at packet 75
// wire [15:0] scrambled = (counter + (current_packet << 8)) * 16'hEF37; // valid
// wire [15:0] scrambled = (counter + (current_packet << 8)) * 16'h8C0D; // invalid - fail at packet 251

// wire [15:0] scrambled = (counter + (current_packet << 8)) * 16'h8455;

// wire [15:0] scrambled = (counter) * 16'hC139;

assign dummy_data = scrambled[15:8] ^ scrambled[7:0];

// assign dummy_data = counter[7:0];

assign finished = (counter == num_bytes) ? 1'b1 : 1'b0;


endmodule