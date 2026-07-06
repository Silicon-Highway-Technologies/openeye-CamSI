`define TEST_USB
// `define USE_SCB 

// eventually we must make SCB work when called in ISP //

parameter AFIFO_SIZE = 4'd14;

`include "settings.vh"

module jpeg_afifo_top
(

    // JPEG inputs //

    input start_capture_in,  // must rise before every frame to trigger the FSM
    input [7:0] red_data_in,       // 8-bit value of the red channel
    input [7:0] green_data_in,     // 8-bit value of the green channel
    input [7:0] blue_data_in,      // 8-bit value of the blue channel
    input frame_valid_in,    // active while a frame is being transmitted
    input line_valid_in,     // active while a line is being transmitted
    output logic image_valid_out,    // when 1, a frame has been fully processed
    input logic [1:0] qf_select_in,       // select one of the 4 possible QF (00 for 50%, 01 for 100%, 10 for 10%, 11 for 25%)
    input [10:0] x_size_in, 
    input [10:0] y_size_in, 

    input pixel_clock_in,
    input pixel_reset_n_in,
    input jpeg_fast_clock_in,
    input jpeg_fast_reset_n_in,
    input jpeg_slow_clock_in,
    input jpeg_slow_reset_n_in,

    // usb input clock and reset //
    input clk_60MHz,
    input reset_60MHz,

    // fifo input only when usb declared

    `ifdef TEST_USB
    input fifo_read_en,
    `endif

    // fifo output //
    output logic  [7:0] afifo_data_out,
    output logic afifo_data_valid_out,
    output logic afifo_wait,

    output logic data_valid_out,

    output logic full_packet_in_fifo,
    output logic [AFIFO_SIZE:0] bytes_in_fifo,

    output logic full,

    output logic empty
);

logic [7:0] red_data_balanced;
logic [7:0] green_data_balanced;
logic [7:0] blue_data_balanced;

logic line_valid_in_delayed;
logic frame_valid_in_delayed;

logic [31:0] data_out;
logic [23:0] address_out;

logic read_en;

`ifdef USE_SCB 
  simplecolorbalance simplecolorbalance_inst(
    .clk(pixel_clock_in),
    .reset_async(!pixel_reset_n_in),
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

// instantiate jpeg //
// eventually have to remove clock outs //

jpeg_encoder #(
  .SENSOR_X_SIZE(ACTIVE_WIDTH),
  .SENSOR_Y_SIZE(ACTIVE_HEIGHT)
) jpeg_encoder_inst (
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
  .pixel_clock_in(pixel_clock_in),
  .pixel_reset_n_in(pixel_reset_n_in),
  .jpeg_fast_clock_in(jpeg_fast_clock_in),
  .jpeg_fast_reset_n_in(jpeg_fast_reset_n_in),
  .jpeg_slow_clock_in(jpeg_slow_clock_in),
  .jpeg_slow_reset_n_in(jpeg_slow_reset_n_in)
);

// various signals //
logic [AFIFO_SIZE:0] wptr, rptr;
logic       afifo_wr, afifo_rd;
logic full;
logic [7:0] data_in_fifo, data_out_fifo;
logic [7:0] read_data_out_buffer;
logic [23:0] read_address;
logic read_valid;

// instantiate the image buffer //
// we only pass the 16bits because these correspond to the actual size of the buffer //
// the image buffer stores the bytes which must be read and transmitted to the fifo   //
image_buffer_custom image_buffer_inst (
  .clock_in(pixel_clock_in),

  .write_address_in(address_out[15:0]),
  .read_address_in(read_address[15:0]),
  .read_address_valid_in(read_valid),
  .write_data_in(data_out),
  .read_data_out(read_data_out_buffer),
  .write_read_n_in(data_valid_out)
);

// in the FSM we pass the full address to overcome (even with this cheesy way) address rollover //
// the fsm decides the current address from which we must read, depending on the writing status //
read_data_fsm fsm_inst(
  .clk(pixel_clock_in),
  .reset(pixel_reset_n_in),
  .write_address(address_out),
  .write_valid(data_valid_out),
  .read_address(read_address),
  .read_valid(read_valid),
  .image_valid_out(image_valid_out)
);

// data valid out counter counts 4 cycles after a read_valid is enabled //
// in these four cycles the output data from the fifo is VALID          //
// this counter determines which BYTES will be passed to FIFO           //

logic [2:0] data_valid_counter;
logic counter_enable;

always @(posedge pixel_clock_in) begin
  if ((pixel_reset_n_in == 0) || (data_valid_counter == 3'd3)) begin
    counter_enable <= 0;
  end
  else if (read_valid) begin
    counter_enable <= 1;
  end
end

always @(posedge pixel_clock_in) begin
  if ((pixel_reset_n_in == 0) || (data_valid_counter == 3'd3)) begin
    data_valid_counter <= 0;
  end
  else if (counter_enable) begin
    data_valid_counter <= data_valid_counter + 1'b1;
  end

end

assign data_in_fifo = (counter_enable) ? (read_data_out_buffer) : (8'b0);

// then connect the fifo which writes with 36MHz clock and reads with 60MHz clock //
// we should not have any problems because the read is faster                     //

assign afifo_wr = write_en & ~full;
assign afifo_rd = read_en & ~empty;

assign write_en = counter_enable;

`ifdef TEST_USB assign read_en = fifo_read_en;
`else assign read_en = ~empty;
`endif

// right now we always read when the buffer is not empty //
// if we add USB functionality we may not want to read always! //

// Instantiate the asynchronous FIFO
afifo #(
    .DSIZE(8),       // Data width
    .ASIZE(AFIFO_SIZE)        // Address size
) jpeg_afifo (
    .i_wclk(pixel_clock_in),
    .i_wrst_n(pixel_reset_n_in),
    .i_wr(afifo_wr),
    .i_wdata(data_in_fifo),
    .o_wfull(full),
    .i_rclk(clk_60MHz),
    .i_rrst_n(reset_60MHz),
    .i_rd(afifo_rd),
    .o_rdata(data_out_fifo),
    .o_rempty(empty),
    .wptr(wptr),
    .rptr(rptr)
);

assign afifo_data_out = data_out_fifo;
assign afifo_data_valid_out = afifo_rd;

// count the afifo bytes
count_afifo_bytes #(
    .ASIZE(AFIFO_SIZE)
) u_fifo_counter (
    .i_wclk   (pixel_clock_in),
    .i_wrst_n (pixel_reset_n_in),
    .wptr     (wptr),
    
    .i_rclk   (clk_60MHz),
    .i_rrst_n (reset_60MHz),
    .rptr     (rptr),
    
    .o_rcount (bytes_in_fifo) // The golden 60MHz synchronized count!
);

assign full_packet_in_fifo = (bytes_in_fifo >= 11'd1024);

// module that detects if afifo_data_valid_out has stayed at 0 for a few cycles, so that sampling can be stopped //

afifo_wait_driver afifo_wait_driver_inst(
  .clk(clk_60MHz),
  .reset(reset_60MHz),
  .image_valid_out(image_valid_out),
  .afifo_data_valid_out(afifo_data_valid_out),
  .afifo_wait(afifo_wait)
);

endmodule