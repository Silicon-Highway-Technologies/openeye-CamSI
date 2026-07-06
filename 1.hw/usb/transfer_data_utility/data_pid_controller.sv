module data_pid_controller(
  input clk,
  input rst,
  input new_microframe,
  input new_IN_packet,
  input [23:0] bytes_in_fifo,
  input stp,
  output logic send_UVC_header,
  output logic multipacket_transmission_active,
  output logic [3:0] new_PID
);

// this module controls the PID sent in video packets during High-Bandwidth Isochronous transmission //
// depending on how many bytes are left in the FIFO //
// for more than 1022 + 1024, send DATA2 + DATA1 + DATA0 //
// for more than 1022, send DATA1 + DATA0 //
// for 1022 or less, send DATA0 //

`include "pid.vh"

logic [1:0] current_state, next_state;
logic UVC_header_sent;
logic multipacket_disable, multipacket_enable;

parameter IDLE = 2'b00;
parameter SEND_PID_DATA0 = 2'b01;
parameter SEND_PID_DATA1 = 2'b10;
parameter SEND_PID_DATA2 = 2'b11;

always @(posedge clk) begin

  if (!rst) current_state <= IDLE;
  else if (new_microframe) current_state <= IDLE;
  else current_state <= next_state;

end

always @(*) begin

  next_state = current_state;
  new_PID = PID_DATA0[3:0];
  multipacket_disable = 1'b0;
  multipacket_enable = 1'b0;

  case(current_state)

  IDLE: begin

    if (new_IN_packet) begin
      if (bytes_in_fifo > 24'd2046) begin
        next_state = SEND_PID_DATA2;
        multipacket_enable = 1'b1;
      end
      else if (bytes_in_fifo > 24'd1022) begin
        next_state = SEND_PID_DATA1;
        multipacket_enable = 1'b1;
      end
      else next_state = SEND_PID_DATA0;

    end

  end

  SEND_PID_DATA2: begin

    new_PID = PID_DATA2[3:0];
    if (new_IN_packet) next_state = SEND_PID_DATA1;

  end

  SEND_PID_DATA1: begin

    new_PID = PID_DATA1[3:0];
    if (new_IN_packet) next_state = SEND_PID_DATA0;

  end

  SEND_PID_DATA0: begin

    new_PID = PID_DATA0[3:0];
    if (stp) begin
      next_state = IDLE;
      multipacket_disable = 1'b1;
    end

  end    

  endcase

end

// multipacket_transmission_active: must be active only when the packets sent are part of a transmission with 2 or 3 packets  //
// for states DATA2 and DATA1 we can easily activate the signal, because being in these states guarantees such a transmission //
// but we cannot do the same for DATA0 state //

always @(posedge clk) begin

  if (!rst || multipacket_disable) multipacket_transmission_active = 1'b0;

  else if (multipacket_enable) multipacket_transmission_active = 1'b1;

end

// also control if the UVC headers will be sent //
// these headers must only be send in the first packet of a microframe //

always @(posedge clk) begin
  
  if (!rst || current_state == IDLE) UVC_header_sent <= 1'b0;

  else if (new_IN_packet) UVC_header_sent <= 1'b1;
end

assign send_UVC_header = (current_state != IDLE) && (UVC_header_sent == 1'b0);

endmodule