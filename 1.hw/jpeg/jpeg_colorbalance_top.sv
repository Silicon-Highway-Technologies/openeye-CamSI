`define USE_SCB
// `undef USE_SCB

module jpeg_colorbalance_top #(
  parameter WIDTH = 1280,
  parameter HEIGHT = 720
)(
  input clk_ext,
  input sys_rst_n,
  input hdmi_clk,

  input start_capture_in,

  input [7:0] red_data_in,
  input [7:0] green_data_in,
  input [7:0] blue_data_in,    
  input frame_valid_in,
  input line_valid_in,

  output logic [31:0] data_out,           // 4 bytes of data
  output logic [15:0] address_out,        // Adress of 16-byte data in image buffer (in bytes)
  output logic image_valid_out,    // Set to 1 when compression finished. If 1, size of encoded data is address_out
  output logic data_valid_out,     // Qualifier for valid data. Data is invalid if 0.

  input [1:0] qf_select_in,       // select one of the 4 possible QF

  input [$clog2(WIDTH)-1:0] x_size_in, // 1280 //
  input [$clog2(HEIGHT)-1:0] y_size_in  // 720 //
);

logic [7:0] red_data_balanced;
logic [7:0] green_data_balanced;
logic [7:0] blue_data_balanced;

logic line_valid_in_delayed;
logic frame_valid_in_delayed;

logic jpeg_fast_clock, jpeg_slow_clock, pixel_clock;

jpeg_clkgen jpeg_clkgen_inst(
  .sysclk(clk_ext),
  .reset(!sys_rst_n),
  .hdmi_clock(hdmi_clk),
  .jpeg_fast_clock(jpeg_fast_clock),
  .jpeg_slow_clock(jpeg_slow_clock),
  .pixel_clock(pixel_clock)
);

`ifdef USE_SCB
  simplecolorbalance simplecolorbalance_inst(
    .clk(pixel_clock),
    .reset_async(!sys_rst_n),
    .red_data_in(red_data_in),
    .green_data_in(green_data_in),
    .blue_data_in(blue_data_in),
    .line_valid_in(line_valid_in),
    .frame_valid_in(frame_valid_in),
    .red_data_out(red_data_balanced),
    .green_data_out(green_data_balanced),
    .blue_data_out(blue_data_balanced),
    .line_valid_out(line_valid_in_delayed),
    .frame_valid_out(frame_valid_in_delayed)
  );
`else
  assign red_data_balanced = red_data_in;
  assign green_data_balanced = green_data_in;
  assign blue_data_balanced = blue_data_in;
  assign line_valid_in_delayed = line_valid_in;
  assign frame_valid_in_delayed = frame_valid_in;
`endif

jpeg_encoder #(
    .SENSOR_X_SIZE(WIDTH),
    .SENSOR_Y_SIZE(HEIGHT)
) jpeg_encoder_inst(
  .start_capture_in(start_capture_in),
  .red_data_in({red_data_balanced, 2'b0}),
  .green_data_in({green_data_balanced, 2'b0}),
  .blue_data_in({blue_data_balanced, 2'b0}),
  .frame_valid_in(frame_valid_in_delayed),
  .line_valid_in(line_valid_in_delayed),
  .data_out(data_out),
  .address_out(address_out),
  .image_valid_out(image_valid_out),
  .data_valid_out(data_valid_out),
  .qf_select_in(qf_select_in),
  .x_size_in(x_size_in),
  .y_size_in(y_size_in),
  .pixel_clock_in(pixel_clock),
  .pixel_reset_n_in(sys_rst_n),
  .jpeg_fast_clock_in(jpeg_fast_clock),
  .jpeg_fast_reset_n_in(sys_rst_n),
  .jpeg_slow_clock_in(jpeg_slow_clock),
  .jpeg_slow_reset_n_in(sys_rst_n)
  
);

endmodule