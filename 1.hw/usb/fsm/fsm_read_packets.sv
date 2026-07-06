module fsm_read_packets(

	input clk,
	input rst,
	input DIR,
	input NXT,
	input [7:0] DATA,
	input setup_highspeed_completed,
	output logic stp_value,
	output logic [7:0] data_value,
	output logic [4:0] current_state,
	output logic [7:0] bmRequestType,
	output logic [7:0] bRequest,
	output logic [15:0] wValue, 
	output logic [15:0] windex, 
	output logic [15:0] wLength,
	output logic [4:0] current_phase,
	output logic [6:0] address,
  output logic [4:0] request,
  output logic [2:0] config_descriptor_packet_counter,
	output logic active
);

// after high-speed has been achieved, we use this FSM to handle the packets //

`include "parameters_fsm_read_packets.vh"
`include "pid.vh"
`include "request_parameters.vh"

logic read_reg_flag;
logic [4:0] next_state;
logic write_to_reg_flag;
logic [5:0] write_reg_address;
logic stp_regwrite;
logic [7:0] output_data_regwrite;
logic [7:0] data_to_reg;
logic [5:0] read_reg_address;
logic stp_regread;
logic [7:0] output_data_regread;
logic regread_done;
logic decode_request_active;
logic send_ack_active, send_descriptor_active, send_blank_data1_active, send_stall_active;
logic [7:0] ack_data, descriptor_data, blank_data1_data, stall_data;
logic new_phase_flag;
logic check_address_endpoint_active;
logic check_address_enabled;
logic new_config_descriptor_packet;
logic set_cur_active;
logic reset_out_packet_counter;
logic valid_ep0;
logic new_byte;
logic ignore_sof_flag;
logic is_multi_packet_data_transfer, is_setup_in_transfer, is_setup_out_in_transfer; // notice the naming difference //
logic [2:0] config_descriptor_packet_counter;
logic reset_request;
logic reset_config_packet_counter;
logic config_descriptor_packet_counter_max;

assign is_setup_in_transfer = (request == SET_ADDRESS) ||
                              (request == SET_CONFIGURATION) ||
                              (request == SET_INTERFACE);

assign is_setup_out_in_transfer = (request == SET_CUR);

assign is_multi_packet_data_transfer = (request == GET_CONFIG_DESCRIPTOR_FULL) || (request == GET_CONFIG_DESCRIPTOR_255BYTES);

assign config_descriptor_packet_counter_max =  ((request == GET_CONFIG_DESCRIPTOR_255BYTES) && (config_descriptor_packet_counter == 3'd3)) ||
                                               ((request == GET_CONFIG_DESCRIPTOR_FULL)     && (config_descriptor_packet_counter == 3'd4));

// phy asserts NXT along with DIR when it sends data that is part of packet //
// if NXT is not asserted, data is part of RXCMD and not part of a packet //
// so, use variable new_byte for this functionality //
assign new_byte = (DIR && NXT);

always @(posedge clk) begin

	if (!rst) check_address_enabled <= 1'b0;
  else if (request == SET_ADDRESS && new_byte && DATA == PID_ACK) check_address_enabled <= 1'b1;

end

// fsm for register writes (probably unused here) //
register_write_fsm register_write_fsm_inst(
  .clk(clk),
  .reset(rst),
  .dir(DIR),
  .nxt(NXT),
  .stp(stp_regwrite),
  .write_to_reg_flag(write_to_reg_flag),
  .register_address(write_reg_address),
  .data_to_reg(data_to_reg), // input //
  .data_out(output_data_regwrite)
);

// fsm for register reads (probably unused here) //
register_read_fsm register_read_fsm_inst(
  .clk(clk),
  .reset(rst),
  .dir(DIR),
  .nxt(NXT),
  .data_in(DATA),
  .data_out(output_data_regread),
  .stp(stp_regread),
  .read_data_flag(read_reg_flag),
  .register_address(read_reg_address),
  .done(regread_done)
);

// when a data packet is sent to us, we must decode it //
// to understand what the request is //
// this fsm is not actually required for the flow //
// we use it for debugging purposes, to read the packets //
debug_request debug_request(
  .clk(clk),
  .rst(rst),
  .new_byte(new_byte),
  .data_in(DATA),
  .active((current_phase == 5'd16) && decode_request_active),
  .bmRequestType(bmRequestType),
  .bRequest(bRequest),
  .wValue(wValue), 
  .windex(windex), 
  .wLength(wLength)
);

// this fsm simply sends an ACK whenever required //
send_handshake_pid_fsm send_ack_fsm_inst(
  .clk(clk),
  .rst(rst),
  .dir(DIR),
  .nxt(NXT),
  .handshake_pid(PID_ACK[3:0]),
  .stp(stp_send_ack),
  .data_out(ack_data),
  .active(send_ack_active)
);

// this fsm simply sends a STALL whenever required //
send_handshake_pid_fsm send_stall_fsm_inst(
  .clk(clk),
  .rst(rst),
  .dir(DIR),
  .nxt(NXT),
  .handshake_pid(PID_STALL[3:0]),
  .stp(stp_send_stall),
  .data_out(stall_data),
  .active(send_stall_active)
);

// this FSM is used when we want to send data during the //
// get descriptor device request //
// will be replaced / modified when we work on answering the //
// get descriptor config request //
send_descriptor_fsm send_descriptor_fsm_inst(

  .clk(clk),
  .rst(rst),
  .dir(DIR),
  .nxt(NXT),
  .stp(stp_send_descriptor),
	.request(request),
  .data_out(descriptor_data),
  .config_descriptor_packet_counter(config_descriptor_packet_counter),
  .active(send_descriptor_active)

);

// this fsm sends the PID for DATA1 and then h00 twice //
// only used for the set_address request //
send_blank_data1_fsm send_blank_data1_fsm_inst(

  .clk(clk),
  .rst(rst),
  .dir(DIR),
  .nxt(NXT),
  .stp(stp_send_blank_data1),
  .data_out(blank_data1_data),
  .active(send_blank_data1_active)

);

// there are multiple packets that we receive that do not contain much useful info //
// and it happens that they are all 2 bytes long + the PID //
// so we count that the number of packets is correct
short_packet_counter short_packet_counter_inst(

  .clk(clk),
  .rst(rst),
  .new_byte(new_byte),
  .active(((DATA == PID_SETUP) || (DATA == PID_IN) || (DATA == PID_OUT)) || (DATA == PID_DATA1) && new_byte),
  .done(counted_setup_packets)
);

// at some point we also have to count 29 packets for the out packet send in phase 9 //
out_packet_byte_counter out_packet_byte_counter_inst(

  .clk(clk),
  .rst(rst),
  .active(set_cur_active),
  .reset_counter(reset_out_packet_counter),
  .done(counted_out_packet_bytes)
);

// during the set address transaction, host assigns an address to us //
// from this point onwards, we must only accept packets to this address //
// so every time we receive a SETUP packet, we check the address //
verify_address_and_endpoint verify_address_and_endpoint_inst(

  .clk(clk),
  .rst(rst),
  .new_byte(new_byte),
  .data(DATA),
  .check_address(check_address_enabled),
  .address(address),
  .active(check_address_endpoint_active),
  .valid_ep0(valid_ep0)
);

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
  .ignore_sof(ignore_sof_flag)
);

// increment packets when we receive the config descriptor //
// because all bytes do not fit into one packet //
count_config_descriptor_packets count_config_descriptor_packets_inst(

  .clk(clk),
  .rst(rst),
  .reset_packet_counter(reset_config_packet_counter), // after host has received all packets we must reset the counter //
  .new_packet(new_config_descriptor_packet),
  .packet_counter(config_descriptor_packet_counter)

);

// decode each request and use it to perform the respective actions //
// also get the address //
decode_request decode_request_inst(

  .clk(clk),
  .rst(rst),
  .new_byte(new_byte),
  .active(decode_request_active),
  .reset_request(reset_request),
  .data_in(DATA),
  .address(address),
  .request(request)
);

// this module is triggered when we move on to a new phase //
// and increments the phase counter //
// the phase method is not currently required for the module to work //
// but is kept for debugging purposes //
phase_incr phase_incr_inst(
  .clk(clk),
  .rst(rst),
  .new_phase_flag(new_phase_flag),
  .current_phase(current_phase)
);


always @(posedge clk) begin

  if (!rst) current_state <= idle;
  else current_state <= next_state;

end

always_comb begin

  data_value = 8'b0000_0000;
  stp_value = 1'b0;
  next_state = current_state;
  read_reg_flag = 0;
  read_reg_address = 6'b0;
  write_to_reg_flag = 0;
  write_reg_address = 6'b0;
  data_to_reg = 8'b0;
  active = 1'b1;
  check_address_endpoint_active = 1'b0;
  decode_request_active = 1'b0;
  send_ack_active = 1'b0; send_descriptor_active = 1'b0; send_blank_data1_active = 1'b0; send_stall_active = 1'b0;
  new_phase_flag = 1'b0;
  set_cur_active = 1'b0;
  new_config_descriptor_packet = 1'b0;
  reset_out_packet_counter = 1'b0;
  reset_request = 1'b0;
  reset_config_packet_counter = 1'b0;

  case (current_state)

  // we first expect SETUP PID //
  idle: begin

    if ((setup_highspeed_completed) && (new_byte)) begin
      
      if (DATA == PID_SETUP && (!ignore_sof_flag)) begin
        next_state = initial_setup_packet;
        check_address_endpoint_active = 1'b1;
      end    

    end

  end

  // we receive the SETUP packet, and we only check its address (after phase 2) //
  // to see if it matches the one we got from set_address //

	// actually to be correct we must also check IN and OUT packets //

  initial_setup_packet: begin
		
		check_address_endpoint_active = 1'b1;

    if (counted_setup_packets) begin
			
			check_address_endpoint_active = 1'b0;

      if (check_address_enabled) begin
        if (valid_ep0) next_state = wait_for_setup_data_packet;
        else next_state = idle;
      end
      else next_state = wait_for_setup_data_packet;
    end
    
  end


  // after setup, we receive a data0 packet which contains the descriptor request //
  // here we wait for the DATA0 PID //
  wait_for_setup_data_packet: begin
     
    if ((new_byte) && (DATA == PID_DATA0) && (!ignore_sof_flag)) begin
      next_state = setup_data_packet;
      decode_request_active = 1'b1;
    end     

  end

  // then we get the data packet, and decode it if we want //
  // the bytes are specific here and the length is always the same //
  
  setup_data_packet: begin
    
    decode_request_active = 1'b1;

    if (!DIR) begin
      next_state = send_ack_after_data0;
      send_ack_active = 1'b1;
    end

  end

  // after receiving the data0 packet, we must send back ACK //
  // there is a dedicated fsm for this //
  send_ack_after_data0: begin
    send_ack_active = 1'b1;
    stp_value = stp_send_ack;
    data_value = ack_data;
    if (stp_value) begin
      if (is_setup_out_in_transfer) next_state = wait_for_out;
      else next_state = wait_for_in;
    end

  end

  // then we receive IN pid //
  wait_for_in: begin

    if ((new_byte)) begin
      
      if (DATA == PID_IN && (!ignore_sof_flag)) begin

        next_state = in_packet;
        check_address_endpoint_active = 1'b1;
      end
    end

  end

  // we receive the in packet after the PID, which does not need to be decoded //
  // only when at phase 1 we do not follow the normal FSM route afterwards //
	// also in phase 8 when we receive get configuration //
  in_packet: begin

    check_address_endpoint_active = 1'b1;

    if (counted_setup_packets) begin

      check_address_endpoint_active = 1'b0;

      if (valid_ep0) begin
        if (is_setup_in_transfer || is_setup_out_in_transfer) next_state = send_blank_data1;

        else next_state = send_descriptor;
      end
      else next_state = wait_for_in;

    end
    else if (!DIR) next_state = wait_for_in;

  end  

  // we send the descriptor data, which varies based on the current phase //
  send_descriptor: begin
    send_descriptor_active = 1'b1;
    stp_value = stp_send_descriptor;
    data_value = descriptor_data;
    if (stp_value) next_state = wait_for_ack; 
  end

  // only on phase 1, we send two blank bytes after data1 //
  send_blank_data1: begin
    send_blank_data1_active = 1'b1;
    stp_value = stp_send_blank_data1;
    data_value = blank_data1_data;
    if (stp_value) next_state = wait_for_ack; 
  end 

  // must send stall as response to string requests //
  send_stall: begin
    send_stall_active = 1'b1;
    stp_value = stp_send_stall;
    data_value = stall_data;
    if (stp_value) begin
      next_state = wait_for_new_setup_packet;
    end
  end   

  // we receive ACK after we send data1 //
  // only on phase 1, the transaction finishes after the ack //
	// also on phase 8 //
  wait_for_ack: begin
    if ((new_byte)) begin
      
      if ((DATA == PID_ACK) && (!ignore_sof_flag)) begin
        if (is_setup_in_transfer || is_setup_out_in_transfer) begin

					next_state = wait_for_new_setup_packet;

        end
        else if (is_multi_packet_data_transfer && (!config_descriptor_packet_counter_max)) begin
          // go back to in_packet //
          next_state = wait_for_in;
          new_config_descriptor_packet = 1'b1;

        end
        else next_state = wait_for_out;
      end
    end    
  end

  // we receive out PID afterwards //
  wait_for_out: begin

    if ((new_byte)) begin

      if (DATA == PID_OUT && (!ignore_sof_flag)) begin
        next_state = out_packet;
        if (is_multi_packet_data_transfer) reset_config_packet_counter = 1'b1;
      end

    end

  end  

  // the out packet does not need to be decoded //
  out_packet: begin

    if (counted_setup_packets) next_state = wait_for_data1;
  end

  // we receive DATA1 pid //
  wait_for_data1: begin

    if ((new_byte)) begin

      if (DATA == PID_DATA1 && (!ignore_sof_flag)) next_state = data1_packet;

      if (is_setup_out_in_transfer) set_cur_active = 1'b1;

    end
  end  

  // data1 packet does not need to be decoded //
  // except for phase 9 in which I will receive many bytes (26 + 3) //
  data1_packet: begin
    
    if (!is_setup_out_in_transfer) begin
      if (counted_setup_packets) begin
        next_state = send_ack_after_data1;
      end
    end
    else begin
      set_cur_active = 1'b1;
      if (counted_out_packet_bytes) begin
        next_state = send_ack_after_data1;
        reset_out_packet_counter = 1'b1;
      end
    end
  end  

  // send ACK for the second time //
  send_ack_after_data1: begin
    send_ack_active = 1'b1;
    stp_value = stp_send_ack;
    data_value = ack_data;
    if (stp_value) begin
      if (!is_setup_out_in_transfer) begin
        next_state = wait_for_new_setup_packet;
      end
      else begin
        next_state = wait_for_in;
      end
    end
  end  

	// wait for a new setup packet //
	wait_for_new_setup_packet: begin

		if (new_byte) begin

			if (DATA == PID_SETUP && (!ignore_sof_flag)) begin
				new_phase_flag = 1'b1;
        next_state = initial_setup_packet;
        reset_request = 1'b1;
        check_address_endpoint_active = 1'b1;
      end
		end

	end

  terminalstate: begin
    
    active = 1'b0;

  end    


  endcase

end

endmodule