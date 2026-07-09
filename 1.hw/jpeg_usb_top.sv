module jpeg_usb_top(

  input button,
  output logic led,

  input sysclk,

  // USB3343 ULPI Interface //
  input phyclk, // 60MHz //
  input DIR,
  input NXT,
  output logic STP,
  inout logic [7:0] DATA,

  output logic phyrst,
  output logic [15:0] debug_jpeg_usb,
  output logic debug_led_usb,

  input [7:0] red_data_in,       // 8-bit value of the red channel
  input [7:0] green_data_in,     // 8-bit value of the green channel
  input [7:0] blue_data_in,      // 8-bit value of the blue channel
  input frame_valid_in,    // active while a frame is being transmitted
  input line_valid_in,     // active while a line is being transmitted
  input [1:0] qf_select_in,      // select one of the 4 possible QF (00 for 50%, 01 for 100%, 10 for 10%, 11 for 25%)
  input [10:0] x_size_in, 
  input [10:0] y_size_in, 

  input pixel_clock_in,
  input pixel_reset_n_in,
  input jpeg_fast_clock_in,
  input jpeg_fast_reset_n_in,
  input jpeg_slow_clock_in,
  input jpeg_slow_reset_n_in,

  output logic jpeg_data_valid_out,

  // mic data //
  output logic mclk,
  input mdata,
  output logic mdis

);

`include "settings.vh"

logic clk_24MHz;
logic pdm_pulse;
logic [7:0] audio_8bit;
logic audio_afifo_write_en;
logic handshake_finished;
logic full_packet_in_fifo;
logic transmission_started;
logic jpeg_afifo_empty;
logic jpeg_afifo_read;
logic [7:0] jpeg_afifo_data, audio_afifo_data;
logic jpeg_afifo_data_valid;
logic afifo_wait;
logic audio_afifo_empty;
logic audio_afifo_read;
logic start_capture;
logic [23:0] jpeg_bytes_in_fifo;
logic [7:0] debug_usb;
logic image_valid_out;   // when 1, a frame has been fully processed


assign mdis = 1'b0;

// drive signal start_capture (stays at 1 until reset) //
always @(posedge pixel_clock_in) begin

  if (!button) start_capture <= 1'b0;

  else if (handshake_finished && !line_valid_in && !frame_valid_in) start_capture <= 1'b1;

end

usb_top usb_top_inst (
  .button(button),
  .led(led),
  .phyclk(phyclk),
  .DIR(DIR),
  .NXT(NXT),
  .STP(STP),
  .DATA(DATA),
  .phyrst(phyrst),
  .handshake_finished(handshake_finished),
  .jpeg_afifo_empty(jpeg_afifo_empty),
  .jpeg_afifo_read(jpeg_afifo_read),
  .audio_afifo_empty(audio_afifo_empty),
  .audio_afifo_read(audio_afifo_read),
  .jpeg_data_in(jpeg_afifo_data),
  .audio_data_in(audio_afifo_data),
  .jpeg_data_valid_in(jpeg_afifo_data_valid),
  .image_valid_out(image_valid_out),
  .transmission_started(transmission_started),
  .jpeg_afifo_finished(jpeg_afifo_finished),
  .frame_transmitted(frame_transmitted),
  .jpeg_bytes_in_fifo(jpeg_bytes_in_fifo),
  .debug_usb(debug_usb)
);

jpeg_afifo_top jpeg_afifo_top_inst(
  .start_capture_in(start_capture),
  .red_data_in(red_data_in),
  .green_data_in(green_data_in),
  .blue_data_in(blue_data_in),
  .frame_valid_in(frame_valid_in),
  .line_valid_in(line_valid_in),
  .full(full),
  .image_valid_out(image_valid_out),

  .qf_select_in(qf_select_in),

  .x_size_in(x_size_in),
  .y_size_in(y_size_in),

  .pixel_clock_in(pixel_clock_in),
  .pixel_reset_n_in(pixel_reset_n_in),
  .jpeg_fast_clock_in(jpeg_fast_clock_in),
  .jpeg_fast_reset_n_in(jpeg_fast_reset_n_in),
  .jpeg_slow_clock_in(jpeg_slow_clock_in),
  .jpeg_slow_reset_n_in(jpeg_slow_reset_n_in),

  .bytes_in_fifo(jpeg_bytes_in_fifo),
  .data_valid_out(jpeg_data_valid_out),

  .clk_60MHz(phyclk),
  .reset_60MHz(phyrst),
  // `ifdef TEST_USB
  .fifo_read_en(jpeg_afifo_read),
  // `endif
  .empty(jpeg_afifo_empty),
  .full_packet_in_fifo(full_packet_in_fifo),
  .afifo_data_out(jpeg_afifo_data),
  .afifo_data_valid_out(jpeg_afifo_data_valid),
  .afifo_wait(afifo_wait)
);

audio_clocking audio_clocking_inst(
  .sysclk(sysclk),
  .rst(phyrst),
  .clk_24MHz(clk_24MHz),
  .pdm_pulse(pdm_pulse),
  .mclk(mclk)
);

audio_top audio_top_inst(
  .clk_24MHz(clk_24MHz),
  .rst(phyrst),
  .mdata(mdata),
  .pdm_pulse(pdm_pulse),
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

// fsm that drives signal jpeg_afifo_finished

fsm_afifo_finished fsm_afifo_finished_inst(
  .clk(phyclk),
  .rst(phyrst),
  .image_valid_out(image_valid_out),
  .jpeg_afifo_empty(jpeg_afifo_empty),
  .frame_transmitted(frame_transmitted),
  .jpeg_afifo_finished(jpeg_afifo_finished)
);

assign debug_jpeg_usb = {debug_usb, image_valid_out, line_valid_in, frame_valid_in, jpeg_afifo_empty, full, frame_transmitted, jpeg_afifo_finished, 1'b0};
assign debug_led_usb = full;

endmodule