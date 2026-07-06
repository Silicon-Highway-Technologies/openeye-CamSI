module fsm_last_packet_in_fifo(

  input clk,
  input rst,
  input image_valid_out,
  input send_data_active,
  output logic last_packet_in_fifo

);

parameter idle_state = 2'b00;
parameter image_valid_out_active_state = 2'b01;
parameter send_data_active_state = 2'b10;

logic [1:0] cur, nxt;
always @(posedge clk) begin

  if (!rst) cur <= idle_state;
  else cur <= nxt;

end

always @(*) begin

  nxt = cur;
  last_packet_in_fifo = 1'b0;

  case(cur)

    idle_state: begin
      
      if (image_valid_out) begin
        nxt = image_valid_out_active_state;
        last_packet_in_fifo = 1'b1;
      end
    end

    image_valid_out_active_state: begin

      last_packet_in_fifo = 1'b1;

      if (send_data_active) begin
        nxt = send_data_active_state;
        last_packet_in_fifo = 1'b0;
      end

    end

    send_data_active_state: begin

      if (!send_data_active && !image_valid_out) begin
        nxt = idle_state;
      end

    end


  endcase


end


endmodule