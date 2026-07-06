module fsm_afifo_finished(

  input clk,
  input rst,
  input image_valid_out,
  input jpeg_afifo_empty,
  output logic frame_transmitted,
  output logic jpeg_afifo_finished

);

parameter idle_state = 2'b00;
parameter image_valid_out_active_state = 2'b01;
parameter afifo_empty_state = 2'b10;

logic [1:0] cur, nxt;
always @(posedge clk) begin

  if (!rst) cur <= idle_state;
  else cur <= nxt;

end

always @(*) begin

  nxt = cur;
  jpeg_afifo_finished = 1'b0;
  frame_transmitted = 1'b0;

  case(cur)

    idle_state: begin
      
      if (image_valid_out) begin
        nxt = image_valid_out_active_state;
      end
    end

    image_valid_out_active_state: begin

      frame_transmitted = 1'b1;
      if (jpeg_afifo_empty) begin
        nxt = idle_state;
        jpeg_afifo_finished = 1'b1;
        
      end

    end

    // afifo_empty_state: begin
      
    //   jpeg_afifo_finished = 1'b1;
    //   // if (new_frame) begin
    //     nxt = idle_state;
    //     // jpeg_afifo_finished = 1'b0;
    //   // end

    // end


  endcase


end


endmodule