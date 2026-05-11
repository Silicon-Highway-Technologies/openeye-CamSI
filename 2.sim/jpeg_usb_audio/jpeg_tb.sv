`timescale 1ns/1ps

`define RES_720P60
// `define RES_1080P30

// width, height and frame rate depend on resolution parameter //
`ifdef RES_720P60
  localparam WIDTH = 1280;
  localparam HEIGHT = 720;
  localparam time FRAME_PERIOD_NS = 16666666; 
`elsif RES_1080P30
  localparam WIDTH = 1920;
  localparam HEIGHT = 1080;
  localparam time FRAME_PERIOD_NS = 33333333; 
`endif

module jpeg_tb;

reg clk_ext;
reg sys_rst_n;
reg hdmi_clk;
reg [7:0] red_data_in;
reg [7:0] green_data_in;
reg [7:0] blue_data_in;
reg line_valid_in;
reg frame_valid_in;
reg start_capture_in;
reg [1:0] qf_select_in;
reg [$clog2(WIDTH)-1:0] x_size_in;
reg [$clog2(HEIGHT)-1:0] y_size_in;

wire [31:0] data_out;
wire data_valid_out;
wire image_valid_out;
wire [15:0] address_out;

integer framei;

always #((1000.0 / 86.11) / 2.0) hdmi_clk = ~hdmi_clk;       // hdmi clk: 86.11MHz //
always #((1000.0 / 200)  / 2.0) clk_ext = ~clk_ext;  // system clk //

// instantiation of the top-level module //
jpeg_colorbalance_top #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
) dut (
  .*
);

// a task that sends the image pixel by pixel at every pixel clock cycle //
task send_image(input string filename, input [15:0] width, input [15:0] height);
    integer img_file, x, y;
    reg [8*24:1] line;
    reg [7:0] r, g, b;
    begin
        img_file = $fopen(filename, "r");
        if (img_file == 0) begin
            $display("ERROR: Could not open file %s", filename);
            $stop;
        end

        #2;
        frame_valid_in = 1;
        for (y = 0; y < height; y = y + 1) begin
            repeat (100) @(posedge hdmi_clk);
            #2;
            line_valid_in = 1;
            for (x = 0; x < width; x = x + 1) begin
                if (!$fgets(line, img_file)) begin
                    $display("ERROR: Unexpected end of file %s", filename);
                    $stop;
                end
                if ($sscanf(line, "%d %d %d", r, g, b) != 3) begin
                    $display("ERROR: Invalid line format at (%0d, %0d): %s", x, y, line);
                    $stop;
                end

                red_data_in = r;
                green_data_in = g;
                blue_data_in = b;
                
                @(posedge hdmi_clk); 
                #2;
            end
            red_data_in = 0;
            green_data_in = 0;
            blue_data_in = 0;
            line_valid_in = 0;
            $display("Sent line %d\n", y);
            repeat (100) @(posedge hdmi_clk);
        end
        #2;
        frame_valid_in = 0;
        $fclose(img_file);
    end
endtask

// capture the encoded JPEG data and store it, every time data_valid_out rises //
task capture_jpeg(input string filename);
    integer out_file;
    integer i = 0;
    reg [7:0] section[0:3];
    begin
        out_file = $fopen(filename, "wb");
        if (out_file == 0) begin
            $display("ERROR: Could not open file %s", filename);
            $stop;
        end

        while (!image_valid_out) begin
            @(posedge dut.jpeg_slow_clock);
            if (data_valid_out == 1) begin
              section[0] = data_out[7:0];
              section[1] = data_out[15:8];
              section[2] = data_out[23:16];
              section[3] = data_out[31:24];
              $fwrite(out_file, "%h\n", {section[0], section[1], section[2], section[3]});
              $display("Captured a new data word (#%d)!", i);
              i = i + 1;
            end
        end

        $fclose(out_file);

        $display("Closed the file!");
    end
endtask

// have an event for the frame tick that happens every 16.666ns or every 33.333ns
event frame_tick;

initial begin
  forever begin
    -> frame_tick;
    #(FRAME_PERIOD_NS);
  end
end    

// main testbench initial begin block //
initial begin

    // The input files should be txt files, with the RGB values of each pixel in each line //
    // All input files must therefore have 1280*720 lines                                  //

    string image_in;
    string image_in2;

    // string jpeg_out = "../../../../../../2.sim/jpeg_usb_audio/image_files/txts/seagulls_encoded_original.txt"; 
    string jpeg_out;
    string jpeg_out2;

`ifdef RES_720P60
    // image_in = "../../../../../../2.sim/jpeg_usb_audio/image_files/txts/seagulls_original.txt";
    image_in = "../../../../../../2.sim/jpeg_usb_audio/image_files/txts/seagulls_original.txt";
    image_in2 = "../../../../../../2.sim/jpeg_usb_audio/image_files/txts/seagulls_bits_scaled_pink.txt";
`elsif RES_1080P30
    image_in = "../../../../../../2.sim/jpeg_usb_audio/image_files/txts/horses_original.txt";
    image_in2 = "../../../../../../2.sim/jpeg_usb_audio/image_files/txts/horses_bits_scaled_pink.txt";
`endif
    $display("About to begin!\n");

    hdmi_clk = 1'b1;
    clk_ext = 1'b1;
    red_data_in = 0;
    green_data_in = 0;
    blue_data_in = 0;
    line_valid_in = 0;
    frame_valid_in = 0;
    start_capture_in = 0;
    x_size_in = WIDTH;
    y_size_in = HEIGHT;
    // qf_select_in = 2'b00; // 50% quality
    // qf_select_in = 2'b01; // 100% quality
    // qf_select_in = 2'b10; // 10% quality
    qf_select_in = 2'b11; // 25% quality    

    sys_rst_n = 0;
    #200 sys_rst_n = 1;


    // start_capture_in = 0;

    for (framei = 0; framei < 4; framei = framei + 1) begin

      #500
      start_capture_in = 1;
      #500
      start_capture_in = 0;
      repeat (100) @(posedge hdmi_clk);

      // in this example the same image is scanned four times, but the user may change it as they like //

`ifdef RES_720P60
      jpeg_out = $sformatf("../../../../../../2.sim/jpeg_usb_audio/image_files/txts/seagulls_encoded_%0d.txt", framei);
`elsif RES_1080P30
      jpeg_out = $sformatf("../../../../../../2.sim/jpeg_usb_audio/image_files/txts/horses_encoded_%0d.txt", framei);
`endif
      #100;

      @(frame_tick); #10;

      fork
          // send_image(image_in, x_size_in, y_size_in);
          send_image(image_in2, x_size_in, y_size_in);
          capture_jpeg(jpeg_out);
      join

      // the frame must be encoded before the next frame signal ticks //

      $display("JPEG encoding for frame %d complete. Output written to %s", framei, jpeg_out);

      qf_select_in = qf_select_in - 1'b1;

    end

    $stop;
end

endmodule