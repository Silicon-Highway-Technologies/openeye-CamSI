module fsm_transfer_data(

	input clk,
	input rst,
	input DIR,
	input NXT,
	input [7:0] DATA,
	input [6:0] address,
  input [7:0] audio_data_in,
  input audio_afifo_empty,
  output audio_afifo_read,
	output logic stp_value,
	output logic [7:0] data_value,
	output logic transmission_started,
	output logic [4:0] current_state,
	output logic [31:0] current_packet,
	output logic active
);

`include "parameters_fsm_transfer_data.vh"
`include "pid.vh"

logic [4:0] next_state;
logic new_byte;
logic ignore_sof_flag;
logic check_address_and_endpoint;
logic send_data_fsm_active;

logic [7:0] jpeg_data_in, transmitted_data;
logic [7:0] data_to_send;
logic jpeg_data_finished;
logic video_afifo_read;
logic start_transmitting, finished_transmitting;
logic new_packet_flag;
logic sending_crc;

logic sent_frame;
logic new_frame;

logic send_zlp;
logic audio_mode;
logic video_endpoint, audio_endpoint, endpoint0;

logic fid_bit;
logic transmission_started_flag;

// phy asserts NXT along with DIR when it sends data that is part of packet //
// if NXT is not asserted, data is part of RXCMD and not part of a packet //
// so, use variable new_byte for this functionality //
assign new_byte = (DIR && NXT);

// multiplexing signals based on audio mode flag (whether the current data transmitted is audio data or video data)
assign data_to_send = audio_mode ? audio_data_in : jpeg_data_in;
assign afifo_empty = audio_mode ? (audio_afifo_empty || audio_packet_done) : jpeg_data_finished;
assign audio_afifo_read =  audio_mode ? afifo_read : 1'b0;
assign video_afifo_read = !audio_mode ? afifo_read : 1'b0;

// sometimes we may wait for a specific PID from the host //
// but we may detect a data instance that has the same value //
// but this instance is part of a SOF packet, which are regularly sent //
// so this module detects a SOF PID and raises a flag //
// which is used to ignore any PIDs while this flag is active //
ignore_sof ignore_sof_inst(
  .clk(clk),
  .rst(rst),
  .dir(DIR),
  .data(DATA),
  .ignore(ignore_sof_flag)
);

packet_incr packet_incr_inst(
  .clk(clk),
  .rst(rst),
  .new_packet_flag(new_packet_flag),
  .current_packet(current_packet)
);


// during the set address transaction, host assigns an address to us //
// from this point onwards, we must only accept packets to this address //
// so every time we receive a SETUP packet, we check the address //
// we must also verify that the endpoint is 1 for JPEG transmission //
verify_address_and_endpoint verify_address_and_endpoint_inst(

  .clk(clk),
  .rst(rst),
  .new_byte(new_byte),
  .data(DATA),
  .address(address),
  .active(check_address_and_endpoint),
  .check_address(1'b0),
  .valid_ep0(endpoint0),
  .valid_ep1(video_endpoint),
  .valid_ep2(audio_endpoint)
);

uvc_jpeg_reader uvc_jpeg_reader_inst(
  .clk(clk),
  .rst(rst),
  .active(send_data_fsm_active && !audio_mode),
  .fetch_next(video_afifo_read),            // Driven by send_data_fsm's afifo_read
  .fid_bit(fid_bit),                  // FROM YOUR 60FPS TIMER (Toggles 0/1 every frame)
  .finished(jpeg_data_finished),     // Drives send_data_fsm's afifo_empty
  .data_out(jpeg_data_in),           // Feeds send_data_fsm's data_in
  .sending_crc(sending_crc),
  .send_new_frame(new_frame),
  .frame_complete(frame_complete)     // Use this to drop data_ready in your top FSM!
);

audio_packet_counter audio_packet_counter_inst(
  .clk(clk),
  .rst(rst),
  .finished_transmitting(finished_transmitting),
  .audio_afifo_read(audio_afifo_read),
  .audio_packet_done(audio_packet_done)
);

// send JPEG data through this module (also uses fifo)
send_data_fsm send_data_fsm_inst(
 
	.clk(clk),
	.reset(rst),
	.start_transmitting(send_data_fsm_active),
	.finished_transmitting(finished_transmitting),
	.afifo_read(afifo_read),
	.data_in(data_to_send),
	.data_out(transmitted_data),
	.nxt(NXT),
	.sending_crc(sending_crc),
	.stp(stp_value_send_data),
  .send_zlp(send_zlp),
	.afifo_empty(afifo_empty)
);

// count 1/60 of a second and use it as data_ready //
// clock is 60MHz, so I need to count 10^6 cycles //
new_frame_cycle_counter new_frame_cycle_counter_inst(
  .clk(clk),
  .rst(rst),
  .new_frame(new_frame),
  .fid_bit(fid_bit),
  .active_flag(transmission_started_flag)
);

// raise a flag to show that the transmission has started //
always @(posedge clk) begin

  if (!rst) transmission_started <= 1'b0;
  else if (transmission_started_flag) transmission_started <= 1'b1;

end

always @(posedge clk) begin

  if (!rst) current_state <= idle;
  else current_state <= next_state;

end
always @(*) begin

  active = 1'b1;
	next_state = current_state;
	stp_value = 1'b0;
	data_value = 8'h00;
	transmission_started_flag = 1'b0;
	check_address_and_endpoint = 1'b0;
	new_packet_flag = 1'b0;
	send_data_fsm_active = 1'b0;
  send_zlp = 1'b0;
  audio_mode = 1'b0;

  case (current_state)

	// we begin when set_configuration is finished (phase 8) //
	// then USB is configured via pyusb and an IN request is sent //
	// which is what we read at this point //s
  idle: begin

    if ((new_byte)) begin
      
      if ((DATA == PID_IN) && (!ignore_sof_flag) && (DATA != PID_SOF))
      begin

        next_state = initial_in_packet;
        transmission_started_flag = 1'b1;
        check_address_and_endpoint = 1'b1;

      end

    end

	end

  // the below state assumes address is always correct //
	initial_in_packet: begin

		check_address_and_endpoint = 1'b1;

    if (video_endpoint) begin
      next_state = sending_video;
      if (frame_complete == 1'b1) send_zlp = 1'b1;
    end

    else if (audio_endpoint) begin
      next_state = sending_audio;
    end

    else if (endpoint0) next_state = idle;

	end


	sending_video: begin

		stp_value = stp_value_send_data;
		data_value = transmitted_data;
    send_data_fsm_active = 1'b1;

    if (frame_complete == 1'b1) send_zlp = 1'b1;

		if (finished_transmitting) begin
			next_state = idle;
			send_data_fsm_active = 1'b0;
		end
	end

	sending_audio: begin

		stp_value = stp_value_send_data;
		data_value = transmitted_data;
    send_data_fsm_active = 1'b1;
    audio_mode = 1'b1;

		if (finished_transmitting) begin
			next_state = idle;
			send_data_fsm_active = 1'b0;
		end
	end  


	terminalstate: begin

		active = 1'b0;

	end

	endcase

end


endmodule