module fsm_last_frame_packet(

  input clk,
  input rst,
  input image_valid_out,
  input STP,
  output logic sent_last_frame_packet

);

parameter idle_state = 2'b00;
parameter wait_for_not_image_valid_out_state = 2'b01;
parameter wait_for_not_afifo_data_valid_out_state = 2'b10;

logic [1:0] cur, nxt;
always @(posedge clk) begin

  if (!rst) cur <= idle_state;
  else cur <= nxt;

end

always @(*) begin

  nxt = cur;
  sent_last_frame_packet = 1'b0;

  case(cur)

    idle_state: begin
      
      if (image_valid_out) nxt = wait_for_not_image_valid_out_state;
    end

    wait_for_not_image_valid_out_state: begin

      if (!image_valid_out) nxt = wait_for_not_afifo_data_valid_out_state;

    end

    wait_for_not_afifo_data_valid_out_state: begin

      if (STP) begin
        nxt = idle_state;
        sent_last_frame_packet = 1'b1;
      end

    end


  endcase


end


endmodule