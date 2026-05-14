module usb_top (
  input button,
  output logic led,

  input sysclk,
  input sysrst,

  // USB3343 ULPI Interface //
  input phyclk, // 60MHz //
  input DIR,
  input NXT,
  output logic STP,
  inout logic [7:0] DATA,

  output logic mclk,
  input mdata,
  output logic mdis,

  // // PHY switches //
  // input sw1,
  // input sw2,
  // input sw3,

  output logic phyrst,
  output logic [15:0] debug_pins
);

`include "parameters_fsm_transfer_data.vh"
`include "pid.vh"

logic sysclk;
logic stp_value_setup_highspeed, stp_value_read_packets, stp_value_transfer_data, stp_value;
logic [7:0] data_value_setup_highspeed, data_value_read_packets, data_value_transfer_data, data_value;
logic fsm_read_packets_active, fsm_setup_highspeed_active, fsm_transfer_data_active;

logic [7:0] bmRequestType;
logic [7:0] bRequest;
logic [15:0] wValue; 
logic [15:0] windex; 
logic [15:0] wLength; 

logic [15:0] debug_byte;

logic [15:0] debug_data, debug_data2;

logic [4:0] current_phase;
logic data_ready;

logic [6:0] address;
logic transmission_started;
logic [31:0] current_packet;
logic [4:0] request;

logic pdm_pulse, clk_24MHz, pcm_pulse;
logic audio_afifo_write_en, audio_afifo_read, audio_afifo_empty;
logic [7:0] audio_8bit, audio_afifo_data;
logic [2:0] config_descriptor_packet_counter;

logic [4:0] fsm_state;

assign DATA = (DIR == 0) ? data_value : 8'bZZZZ_ZZZZ;
assign STP = stp_value;
assign phyrst = button;

assign mdis = 1'b0;

audio_top audio_top_inst(
  .sysclk(sysclk),
  .rst(phyrst),
  .mdata(mdata),
  .mclk(mclk),
  .clk_24MHz(clk_24MHz),
  .audio_8bit(audio_8bit),
  .afifo_write_en(audio_afifo_write_en)
);

audio_afifo_top audio_afifo_top_inst(
  .phyclk(phyclk),
  .rst(phyrst),
  .clk_24MHz(clk_24MHz),
  .afifo_write_en(audio_afifo_write_en && transmission_started),
  .afifo_read(audio_afifo_read),
  .audio_8bit(audio_8bit),
  .data_to_send(audio_afifo_data),
  .afifo_empty(audio_afifo_empty)
);

// debug pins

// assign debug_pins[0] = DIR;
// assign debug_pins[1] = STP;
// assign debug_pins[2] = NXT;
// assign debug_pins[3] = (0);
// assign debug_pins[4] = (DATA == PID_IN);
// assign debug_pins[5] = (DATA == PID_DATA0);
// assign debug_pins[6] = (DATA == PID_DATA1);
// assign debug_pins[7] = (DATA == PID_ACK);


// assign debug_pins[8] = DATA[0];
// assign debug_pins[9] = DATA[1]; 
// assign debug_pins[10] = DATA[2];
// assign debug_pins[11] = DATA[3];
// assign debug_pins[12] = DATA[4];
// assign debug_pins[13] = DATA[5];
// assign debug_pins[14] = DATA[6];
// assign debug_pins[15] = DATA[7];

// assign debug_pins = {debug_byte};
// assign debug_pins = debug_data;
assign debug_pins = {fsm_state, 1'b0, current_phase, request};


fsm_setup_highspeed fsm_setup_highspeed_inst(
  .clk(phyclk),
  .rst(phyrst),
  .DIR(DIR),
  .NXT(NXT),
  .stp_value(stp_value_setup_highspeed),
  .data_value(data_value_setup_highspeed),
  .active(fsm_setup_highspeed_active),
  .DATA(DATA)
);

fsm_read_packets fsm_read_packets_inst(
  .clk(phyclk),
  .rst(phyrst),
  .DIR(DIR),
  .NXT(NXT),
  .stp_value(stp_value_read_packets),
  .data_value(data_value_read_packets),
  .setup_highspeed_completed(fsm_setup_highspeed_active == 1'b0),
  .active(fsm_read_packets_active),
  .current_state(fsm_state),
  .bmRequestType(bmRequestType),
  .bRequest(bRequest),
  .wValue(wValue), 
  .windex(windex), 
  .wLength(wLength),   
  .current_phase(current_phase),
  .request(request),
  .address(address),
  .config_descriptor_packet_counter(config_descriptor_packet_counter),
  .DATA(DATA)
);

fsm_transfer_data fsm_transfer_data_inst(
	.clk(phyclk),
	.rst(phyrst),
  .DIR(DIR),
  .NXT(NXT),
  .stp_value(stp_value_transfer_data),
  .data_value(data_value_transfer_data),	
	.transmission_started(transmission_started),
  // .read_packets_completed(fsm_read_packets_active == 1'b0),
  .active(fsm_transfer_data_active),	
	// .current_state(fsm_state),
  .audio_data_in(audio_afifo_data),
  .audio_afifo_empty(audio_afifo_empty),
  .audio_afifo_read(audio_afifo_read),
	.address(address),
	.current_packet(current_packet),
	.DATA(DATA)
);

assign stp_value = (stp_value_setup_highspeed) || (stp_value_read_packets) || (stp_value_transfer_data);
assign data_value = (data_value_setup_highspeed) | (data_value_read_packets) | (data_value_transfer_data);

assign led = (fsm_state == terminalstate);

endmodule
