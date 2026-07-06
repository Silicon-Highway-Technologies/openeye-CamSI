module usb_top (
  input button,
  output logic led,

  // USB3343 ULPI Interface //
  input phyclk, // 60MHz //
  input DIR,
  input NXT,
  output logic STP,
  inout logic [7:0] DATA,

  output logic jpeg_afifo_read,
  output logic audio_afifo_read,
  input jpeg_afifo_empty,
  input audio_afifo_empty,

  input jpeg_afifo_finished,
  input frame_transmitted,

  output logic handshake_finished,
  output logic sending_packet,


  input [7:0] jpeg_data_in,
  input jpeg_data_valid_in,
  input image_valid_out,

  input [23:0] jpeg_bytes_in_fifo,

  input [7:0] audio_data_in,

  output logic transmission_started,

  output logic phyrst,
  output logic [7:0] debug_usb
);

`include "parameters_fsm_transfer_data.vh"
`include "pid.vh"

logic stp_value_setup_highspeed, stp_value_read_packets, stp_value_transfer_data, stp_value;
logic [7:0] data_value_setup_highspeed, data_value_read_packets, data_value_transfer_data, data_value;
logic fsm_read_packets_active, fsm_setup_highspeed_active, fsm_transfer_data_active;

logic [7:0] bmRequestType;
logic [7:0] bRequest;
logic [15:0] wValue; 
logic [15:0] windex; 
logic [15:0] wLength; 
logic [7:0] debug_byte;

logic [15:0] debug_data, debug_data2;

logic [4:0] current_phase;

logic [6:0] address;

logic [6:0] debug_fsm;

logic pdm_pulse, clk_24MHz, pcm_pulse;
logic audio_afifo_write_en, audio_afifo_empty;
logic [7:0] audio_8bit, audio_afifo_data;
logic [2:0] config_descriptor_packet_counter;

logic [4:0] fsm_state;
logic requestled;

assign DATA = (DIR == 0) ? data_value : 8'bZZZZ_ZZZZ;
assign STP = stp_value;
assign phyrst = button;

// when packet reading finished, we can activate JPEG //
assign handshake_finished = transmission_started;

// debug pins
assign debug_usb = {debug_fsm, handshake_finished};

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
  .bmRequestType(bmRequestType),
  .bRequest(bRequest),
  .wValue(wValue), 
  .windex(windex), 
  .wLength(wLength),   
  .current_phase(current_phase),
  .address(address),
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
  .active(fsm_transfer_data_active),	
	.current_state(fsm_state),
	.address(address),
  .jpeg_data_in(jpeg_data_in),
  .audio_data_in(audio_data_in),
  .jpeg_data_valid_in(jpeg_data_valid_in),
  .jpeg_afifo_empty(jpeg_afifo_empty),
  .jpeg_afifo_read(jpeg_afifo_read),
  .audio_afifo_empty(audio_afifo_empty),
  .audio_afifo_read(audio_afifo_read),  
  .image_valid_out(image_valid_out),
  .sending_packet(sending_packet),
  .jpeg_afifo_finished(jpeg_afifo_finished),
  .frame_transmitted(frame_transmitted),
  .jpeg_bytes_in_fifo(jpeg_bytes_in_fifo), 
  .debug_fsm(debug_fsm),
	.DATA(DATA)
);

assign stp_value = (stp_value_setup_highspeed) || (stp_value_read_packets) || (stp_value_transfer_data);
assign data_value = (data_value_setup_highspeed) | (data_value_read_packets) | (data_value_transfer_data);

// assign led = requestled;

assign led = (fsm_state == terminalstate);

endmodule
