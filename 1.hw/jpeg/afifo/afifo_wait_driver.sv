module afifo_wait_driver(

  input clk,
  input reset,
  input image_valid_out,
  input afifo_data_valid_out,
  output afifo_wait
);

// drive the signal afifo_wait, which shows that fifo is transmitting even after the encoding has been completed //

// count for 10 cycles (maybe even less cycles would be enough) //

logic [3:0] counter;
logic counter_reset;

always @(posedge clk) begin

  if ((reset == 0) || afifo_data_valid_out || (image_valid_out == 0)) counter <= 4'b0;

  else if (counter_reset == 0) counter <= counter + 1'b1;
end

assign counter_reset = (counter == 4'd10);

assign afifo_wait = (image_valid_out) && (counter_reset == 0);

endmodule