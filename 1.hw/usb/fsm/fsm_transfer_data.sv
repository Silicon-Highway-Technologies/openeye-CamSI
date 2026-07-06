module fsm_transfer_data(

	input clk,
	input rst,
	input DIR,
	input NXT,
	input [7:0] DATA,
  input [7:0] jpeg_data_in,
  input [7:0] audio_data_in,
  input [6:0] address,
  input jpeg_data_valid_in,
  input image_valid_out,
  output logic jpeg_afifo_read,
  input jpeg_afifo_empty,
  input audio_afifo_empty,
  output audio_afifo_read,
  input jpeg_afifo_finished,
  input frame_transmitted,
  input [23:0] jpeg_bytes_in_fifo,
	output logic stp_value,
	output logic [7:0] data_value,
  output logic transmission_started,

  output logic [6:0] debug_fsm,

	output logic [4:0] current_state,
  output logic sending_packet,
	output logic active

);

`include "parameters_fsm_transfer_data.vh"
`include "pid.vh"

logic [4:0] next_state;
logic new_byte;
logic ignore_sof_flag;
logic check_address_and_endpoint;
logic send_data_fsm_active;

logic [7:0] transmitted_data;
logic [7:0] data_to_send;
logic jpeg_data_finished;
logic start_transmitting, finished_transmitting;
logic new_packet_flag;
logic sending_crc;
logic send_UVC_header;
logic sent_frame;
logic new_frame;
logic send_zlp;
logic audio_mode;
logic video_endpoint, audio_endpoint, endpoint0;
logic audio_packet_done;
logic afifo_empty, afifo_read;
logic frame_complete;
logic new_microframe;
logic transmission_started_flag;
logic control_PID;
logic [7:0] jpeg_byte;
logic jpeg_send_data;
logic zlp_mode_active;
logic sending_footer;
logic [3:0] new_PID, send_data_PID;
logic multipacket_transmission_active;

logic [4:0] debug_uvc_reader;

// phy asserts NXT along with DIR when it sends data that is part of packet //
// if NXT is not asserted, data is part of RXCMD and not part of a packet //
// so, use variable new_byte for this functionality //
assign new_byte = (DIR && NXT);

// multiplexing signals based on audio mode flag (whether the current data transmitted is audio data or video data)
assign data_to_send = audio_mode ? audio_data_in : jpeg_byte;
assign afifo_empty = audio_mode ? (audio_afifo_empty || audio_packet_done) : (jpeg_data_finished || jpeg_afifo_empty);
assign audio_afifo_read =  audio_mode ? afifo_read : 1'b0;
assign jpeg_afifo_read = !audio_mode ? afifo_read : 1'b0;
assign send_data_PID = audio_mode ? PID_DATA0[3:0] : new_PID;

assign zlp_mode_active = transmission_started && (jpeg_bytes_in_fifo < 24'd3068 && !frame_transmitted) && (!multipacket_transmission_active);

// sometimes we may wait for a specific PID from the host //
// but we may detect a data instance that has the same value //
// but this instance is part of a SOF packet, which are regularly sent //
// so this module detects a SOF PID and raises a flag //
// which is used to ignore any PIDs while this flag is active //
detect_sof detect_sof_inst(
  .clk(clk),
  .rst(rst),
  .DIR(DIR),
  .NXT(NXT),
  .DATA(DATA),
  .new_microframe(new_microframe),
  .ignore_sof(ignore_sof_flag)
);

// packet_incr packet_incr_inst(
//   .clk(clk),
//   .rst(rst),
//   .new_packet_flag(new_packet_flag),
//   .current_packet(current_packet)
// );

// use the signal control_PID to shift between MDATA, MDATA, DATA2 within a microframe //
data_pid_controller data_pid_controller_inst(
  .clk(clk),
  .rst(rst),
  .new_IN_packet(control_PID),
  .bytes_in_fifo(jpeg_bytes_in_fifo),
  .new_microframe(new_microframe),
  .send_UVC_header(send_UVC_header),
  .multipacket_transmission_active(multipacket_transmission_active),
  .stp(stp_value),
  .new_PID(new_PID)
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
  .send_data_fsm_active(send_data_fsm_active),
  .zlp_mode(current_state == zlp_mode),
  .nxt(NXT),
  .fetch_next(jpeg_afifo_read),            // Driven by send_data_fsm's afifo_read
  .finished(jpeg_data_finished),     // Drives send_data_fsm's afifo_empty
  .jpeg_data_in(jpeg_data_in),
  .jpeg_send_data(jpeg_send_data),
  .jpeg_afifo_finished(jpeg_afifo_finished),
  .frame_transmitted(frame_transmitted),
  .sending_footer(sending_footer),
  .data_out(jpeg_byte),           // Feeds send_data_fsm's data_in
  .sending_crc(sending_crc),
  .send_new_frame(video_endpoint && frame_complete),
  .send_UVC_header(send_UVC_header),
  .bytes_in_fifo(jpeg_bytes_in_fifo),
  .audio_mode(audio_mode),
  .debug_uvc_reader(debug_uvc_reader),
  .frame_complete(frame_complete)
);

audio_packet_counter audio_packet_counter_inst(
  .clk(clk),
  .rst(rst),
  .finished_transmitting(finished_transmitting),
  .audio_afifo_read(audio_afifo_read),
  .audio_packet_done(audio_packet_done)
);

// send JPEG data through this module (also uses fifo) //
// this module also sends audio data //
send_data_fsm send_data_fsm_inst(

	.clk(clk),
	.reset(rst),
  .send_data_PID(send_data_PID),
	.start_transmitting(send_data_fsm_active),
	.finished_transmitting(finished_transmitting),
	.afifo_read(afifo_read),
	.data_in(data_to_send),
  .jpeg_send_data(jpeg_send_data),
  .audio_mode(audio_mode),
	.data_out(transmitted_data),
	.nxt(NXT),
	.sending_crc(sending_crc),
	.stp(stp_value_send_data),
  .sending_footer(sending_footer),
  .sending_packet(sending_packet),
  .zlp_mode((current_state == zlp_mode) && !audio_mode),
  .send_zlp(send_zlp),
	.afifo_empty(afifo_empty)
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
  control_PID = 1'b0;

  case (current_state)

	// we begin when set_configuration is finished (phase 8) //
	// then USB is configured via pyusb and an IN request is sent //
	// which is what we read at this point //s
  idle: begin

    if ((new_byte)) begin
      
      if ((DATA == PID_IN) && (!ignore_sof_flag) && (DATA != PID_SOF))
      begin

        next_state = initial_in_packet;
        check_address_and_endpoint = 1'b1;

      end

    end

	end

  // the below state assumes address is always correct //
	initial_in_packet: begin

		check_address_and_endpoint = 1'b1;

    if (video_endpoint) begin
      next_state = sending_video;
      transmission_started_flag = 1'b1;
      control_PID = 1'b1;
      if (frame_complete == 1'b1) send_zlp = 1'b1;
    end

    else if (audio_endpoint) begin
      next_state = sending_audio;
    end

    else if (endpoint0) next_state = idle; // if endpoint 0 //

    if (zlp_mode_active && video_endpoint) begin
      next_state = zlp_mode;
      control_PID = 1'b0;
    end

	end

  // zlp mode is when data has not arrived yet, so we must keep sending ZLP //
  // OR when there are less than 3 full packets in the JPEG fifo and the frame has not finished yet //
  zlp_mode: begin

    send_zlp = 1'b1;
		stp_value = stp_value_send_data;
		data_value = transmitted_data;  
    send_data_fsm_active = 1'b1;  

		if (finished_transmitting) begin
			next_state = idle;
			send_data_fsm_active = 1'b0;
		end    
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

assign debug_fsm = {debug_uvc_reader, audio_mode, zlp_mode_active};

endmodule