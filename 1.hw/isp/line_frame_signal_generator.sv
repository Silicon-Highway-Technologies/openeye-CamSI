// this module generates signals line_valid_in and frame_valid_in //
// which will be used as inputs for the simplecolorbalance module //

module line_frame_signal_generator(

    input logic clk,
    input logic rst,
    input logic csi_in_frame,
    input logic reading,
    output logic line_valid_in,
    output logic frame_valid_in

);

// circuit to get the edge of csi_in_frame //
logic csi_in_frame_edge;

edge_detector edge_detector_frame(
   .in(csi_in_frame),
   .out(csi_in_frame_edge),
   .clk(clk),
   .rst(rst)
);

// two counters are necessary:        //
// 1: to measure how many times the reading signal is enabled (line_counter)      //
// 2: to measure for how many cycles the reading signal is active (frame_counter) //

logic reading_edge;
logic [10:0] line_counter;

// get the 1-cycle signal for the edge of reading //
edge_detector edge_detector_reading(
   .in(reading),
   .out(reading_edge),
   .clk(clk),
   .rst(rst)
);

// line counter increments every time reading rises //
always @(posedge clk) begin

   if (rst || csi_in_frame_edge) begin
      line_counter <= 11'b00;
   end else if (reading_edge) begin
      line_counter <= line_counter + 1'b1;
   end

end

logic frame_valid_in, line_valid_in;

// raise frame_valid_in while the line counter corresponds to a subset of the visible area //
always @(posedge clk) begin

   `ifdef HDMI_720p60
      if (rst || line_counter < 11'd100 || line_counter > 11'd719) begin
   `else // HDMI_1080P30
      if (rst || line_counter < 11'd100 || line_counter > 11'd1079) begin
   `endif

      frame_valid_in <= 0;
   end else begin
      frame_valid_in <= 1;
   end

end

logic [10:0] pixel_counter;

// pixel counter increments at every cycle that reading is active //
always @(posedge clk) begin

   if (rst || reading == 0) begin
      pixel_counter <= 11'b0;
   end else if (reading == 1) begin
      pixel_counter <= pixel_counter + 1'b1;
   end

end

// raise line_valid_in while the pixel counter corresponds to a subset of the visible area //
always @(posedge clk) begin

   `ifdef HDMI_720p60
      if (rst || pixel_counter < 11'd100 || pixel_counter > 11'd1000) begin
   `else // HDMI_1080P30
      if (rst || pixel_counter < 11'd100 || pixel_counter > 11'd1700) begin
   `endif
      line_valid_in <= 0;
   end else begin
      line_valid_in <= 1;
   end

end


endmodule