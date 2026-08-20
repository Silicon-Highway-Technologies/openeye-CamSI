`timescale 1ns/1ps

`include "request_parameters.vh"
`include "pid.vh"
// `include "settings.vh"

module jpeg_usb_tb();

// Parameters
localparam SYSCLK_PERIOD = 5; // 200MHz Differential Clock
localparam PHY_CLK_PERIOD = 16.666667; // 60MHz ULPI Clock

parameter DELAY = 1'b1;
parameter NO_DELAY = 1'b0;

parameter ENDPOINT0 = 2'b00;
parameter ENDPOINT1 = 2'b01;
parameter ENDPOINT2 = 2'b10;

// Signals
reg button; reg sysclk; reg phyclk; reg DIR; reg NXT;
wire led; wire STP; wire phyrst;

wire mclk;
reg mdata;
wire mdis;

wire [7:0] DATA;

reg [7:0] data_drive;
wire [7:0] data_recv;

// JPEG signals //

reg [7:0] red_data_in;
reg [7:0] green_data_in;
reg [7:0] blue_data_in;
reg jpeg_fast_clock_in;
reg jpeg_fast_reset_n_in;
reg jpeg_slow_clock_in;
reg jpeg_slow_reset_n_in;
reg pixel_clock_in;
reg pixel_reset_n_in; 
reg line_valid_in;
reg frame_valid_in;
reg [1:0] qf_select_in;
reg [10:0] x_size_in;
reg [10:0] y_size_in;

assign DATA = (DIR == 1) ? data_drive : 8'bZZZZ_ZZZZ;

integer num_of_packets = 32'd100;
integer bytes_per_packet = 16'd512;
integer i, j;

integer dump_file;

logic stp_flag;
logic sequence_complete;

// Instantiate Unit Under Test (jpeg_usb_top_inst.usb_top_inst)
jpeg_usb_top jpeg_usb_top_inst (
  .button(button),
  .led(led),
  .sysclk(sysclk),

  .phyclk(phyclk),
  .DIR(DIR),
  .NXT(NXT),
  .STP(STP),
  .DATA(DATA),
  .phyrst(phyrst),

  .mclk(mclk),
  .mdata(mdata),
  .mdis(mdis),

  .red_data_in(red_data_in),
  .green_data_in(green_data_in),
  .blue_data_in(blue_data_in),
  .frame_valid_in(frame_valid_in),
  .line_valid_in(line_valid_in),
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

check_audio_PID check_audio_PID_inst (
  .phyclk(phyclk),
  .rst(button),
  .DIR(DIR),
  .NXT(NXT),
  .DATA(DATA)
);

check_video_PID check_video_PID_inst (
  .phyclk(phyclk),
  .rst(button),
  .DIR(DIR),
  .NXT(NXT),
  .STP(STP),
  .DATA(DATA)
);

count_video_packet_bytes count_video_packet_bytes (
  .phyclk(phyclk),
  .rst(button),
  .DIR(DIR),
  .NXT(NXT),
  .STP(STP),
  .DATA(DATA)
);

check_dir_stp check_dir_stp_inst (
  .phyclk(phyclk),
  .rst(button),
  .DIR(DIR),
  .STP(STP)
);

check_uvc_header check_uvc_header_inst (
  .phyclk(phyclk),
  .rst(button),
  .DIR(DIR),
  .NXT(NXT),
  .DATA(DATA)
);

// Clock Generation
always #(SYSCLK_PERIOD/2.0) sysclk = ~sysclk;
always #(PHY_CLK_PERIOD/2.0) phyclk = ~phyclk;

always #((1000.0 / 86.11) / 2.0) pixel_clock_in = ~pixel_clock_in; 
always #((1000.0 / 86.11)  / 2.0) jpeg_slow_clock_in = ~jpeg_slow_clock_in; 
always #((1000.0 / 175) / 2.0) jpeg_fast_clock_in = ~jpeg_fast_clock_in; 

always @(posedge mclk) begin
  #30 mdata = $urandom_range(0, 1);
end

logic [63:0] request_memory [0:16];

initial begin
  // "w" opens the file for writing (overwrites previous runs)
  dump_file = $fopen("usb_bus_dump.txt", "w");
  
  if (dump_file == 0) begin
      $display("CRITICAL ERROR: Could not open dump file!");
      $finish;
  end
  
  $display("Logging USB DATA to usb_bus_dump.txt...");
end  

initial begin // initialise memory //

  request_memory[GET_DEVICE_DESCRIPTOR] = 64'h80_06_00_01_00_00_12_00;
  request_memory[SET_ADDRESS] = 64'h00_05_07_00_00_00_00_00;
  request_memory[GET_CONFIG_DESCRIPTOR_9BYTES] = 64'h80_06_00_02_00_00_09_00;
  request_memory[GET_CONFIG_DESCRIPTOR_255BYTES] = 64'h80_06_00_02_00_00_FF_00;
  request_memory[GET_CONFIG_DESCRIPTOR_FULL] = 64'h80_06_00_02_00_00_01_01;
  request_memory[SET_CONFIGURATION] = 64'h00_09_01_00_00_00_00_00;
  request_memory[SET_INTERFACE] = 64'h00_0B_00_00_01_00_00_00;
  request_memory[SET_CUR] = 64'h21_01_00_01_01_00_1A_00;
  request_memory[GET_CUR_VIDEO_PROBE] = 64'hA1_81_00_01_01_00_1A_00;
  request_memory[GET_CUR_AUDIO_MUTE] = 64'hA1_81_00_01_02_04_01_00;
  request_memory[GET_CUR_AUDIO_VOL] = 64'hA1_81_00_02_02_04_02_00;
  request_memory[GET_MIN_VIDEO_PROBE] = 64'hA1_82_00_01_01_00_1A_00;
  request_memory[GET_MAX_VIDEO_PROBE] = 64'hA1_83_00_01_01_00_1A_00;
  request_memory[GET_MIN_AUDIO_VOL] = 64'hA1_82_00_02_02_04_02_00;
  request_memory[GET_MAX_AUDIO_VOL] = 64'hA1_83_00_02_02_04_02_00;   
  request_memory[GET_RES] = 64'hA1_84_00_02_02_04_02_00;  

end

  // always @(posedge phyclk) begin
  //   $fdisplay(dump_file, "[%0t ns] DATA: %h DIR: %h NXT: %h STP; %h", $time, DATA, DIR, NXT, STP);
  // end

// 7500 cycle counter (SOF counter) 

logic [23:0] sof_counter;
logic send_sof;

always @(posedge phyclk) begin

  if (jpeg_usb_top_inst.usb_top_inst.fsm_setup_highspeed_active || send_sof) sof_counter <= 24'b0;

  else sof_counter <= sof_counter + 1'b1;

end

assign send_sof = (sof_counter == 24'd7499);

integer debug_file_usb_jpeg, jpegusbi;
integer debug_file_usb_audio, audiousbi;
integer debug_file_jpeg, debug_file_afifo, jpegi, afifoi;

initial begin

  debug_file_usb_jpeg = $fopen("continuous_capture_usb_jpeg.txt", "w");
  if (debug_file_usb_jpeg == 0) begin
      $display("ERROR: Could not open continuous_capture usb jpeg");
      $stop;
  end       

  jpegusbi = 0;

  debug_file_usb_audio = $fopen("continuous_capture_usb_audio.txt", "w");
  if (debug_file_usb_audio == 0) begin
      $display("ERROR: Could not open continuous_capture usb audio");
      $stop;
  end       

  audiousbi = 0;

  debug_file_jpeg = $fopen("continuous_capture_jpeg.txt", "w");
  if (debug_file_jpeg == 0) begin
      $display("ERROR: Could not open continuous_capture jpeg");
      $stop;
  end

  jpegi = 0;

  debug_file_afifo = $fopen("continuous_capture_afifo.txt", "w");
  if (debug_file_afifo == 0) begin
      $display("ERROR: Could not open continuous_capture afifo");
      $stop;
  end

  afifoi = 0;


end

always @(posedge phyclk) begin

  // below sequence coould be written better //
  if (NXT && jpeg_usb_top_inst.usb_top_inst.fsm_transfer_data_inst.send_data_fsm_active &&
          jpeg_usb_top_inst.usb_top_inst.fsm_transfer_data_inst.uvc_jpeg_reader_inst.packet_byte_cnt > 0 &&
          (jpeg_usb_top_inst.usb_top_inst.fsm_transfer_data_inst.send_UVC_header == 1'b0 || jpeg_usb_top_inst.usb_top_inst.fsm_transfer_data_inst.uvc_jpeg_reader_inst.packet_byte_cnt > 2'd2) &&
          jpeg_usb_top_inst.usb_top_inst.fsm_transfer_data_inst.send_data_fsm_inst.current_state != 3'd3 &&
          jpeg_usb_top_inst.usb_top_inst.fsm_transfer_data_inst.send_data_fsm_inst.current_state != 3'd4
          // && $past(jpeg_usb_top_inst.usb_top_inst.fsm_transfer_data_inst.uvc_jpeg_reader_inst.header_incr == 0) &&
          // $past(jpeg_usb_top_inst.usb_top_inst.fsm_transfer_data_inst.uvc_jpeg_reader_inst.footer_incr == 0)
          ) begin // exclude headers and CRC//
  // Write the byte-swapped word to the file
    $fwrite(debug_file_usb_jpeg, "%h", DATA);
    $display("Wrote %h to usb_jpeg debug!", DATA);
    jpegusbi = jpegusbi + 1;

    if (jpegusbi%4 == 0) begin
      $fwrite(debug_file_usb_jpeg, "\n");
    end
  end

end

always @(posedge phyclk) begin

    if (jpeg_usb_top_inst.usb_top_inst.fsm_transfer_data_inst.send_data_fsm_active && jpeg_usb_top_inst.usb_top_inst.fsm_transfer_data_inst.audio_mode) begin
      
    // Write the byte-swapped word to the file
      $fwrite(debug_file_usb_audio, "%h", DATA);
      // $display("Captured a new audio data word in usb (#%d)!", audiousbi);
      audiousbi = audiousbi + 1;

      if (audiousbi%4 == 0) begin
        $fwrite(debug_file_usb_audio, "\n");
      end

    end

end

always @(posedge phyclk) begin

  if (jpeg_usb_top_inst.jpeg_afifo_data_valid) begin
      
    // Write the byte-swapped word to the file
      $fwrite(debug_file_afifo, "%h", jpeg_usb_top_inst.jpeg_afifo_data);
      // $display("Captured a new data word in jpeg afifo (#%d)!", afifoi);
      afifoi = afifoi + 1;

      if (afifoi%4 == 0) begin
        $fwrite(debug_file_afifo, "\n");
      end
  end
end

always @(posedge jpeg_slow_clock_in) begin
  reg [7:0] section[0:3];

  if (jpeg_usb_top_inst.jpeg_afifo_top_inst.data_valid_out == 1) begin
    section[0] = jpeg_usb_top_inst.jpeg_afifo_top_inst.data_out[7:0];
    section[1] = jpeg_usb_top_inst.jpeg_afifo_top_inst.data_out[15:8];
    section[2] = jpeg_usb_top_inst.jpeg_afifo_top_inst.data_out[23:16];
    section[3] = jpeg_usb_top_inst.jpeg_afifo_top_inst.data_out[31:24];
    $fwrite(debug_file_jpeg, "%h\n", {section[0], section[1], section[2], section[3]});
    // $display("Captured a new data word (#%d)!", jpegi);
    jpegi = jpegi + 1;
  end

end

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

        // #0.5; 
        frame_valid_in = 1;
        for (y = 0; y < height; y = y + 1) begin
            repeat (100) @(posedge pixel_clock_in);
            // #0.5;
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
                
                @(posedge pixel_clock_in);
                // #0.5;
            end
            red_data_in = 0;
            green_data_in = 0;
            blue_data_in = 0;
            line_valid_in = 0;
            $display("Sent line %d\n", y);
            repeat (100) @(posedge pixel_clock_in);
        end
        // #0.5;
        frame_valid_in = 0;
        $fclose(img_file);
    end
endtask

  // testbench to send image frames //
initial begin

  // The input files should be txt files, with the RGB values of each pixel in each line //
  // All input files must therefore have 1280*720 lines                                  //

  fork begin

  // string image_in1 = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/seagulls_bits_scaled_pink.txt";
  // string image_in2 = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/seagulls_original.txt";
  // string image_in3 = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/croissants_original.txt";

  string image_in1 = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/seagulls_original.txt";
  string image_in2 = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/seagulls_original.txt";
  string image_in3 = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/seagulls_original.txt";

  // string image_in1 = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/test_pattern_original.txt";
  // string image_in2 = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/test_pattern_original.txt";
  // string image_in3 = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/test_pattern_original.txt";    

  string jpeg_out2 = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/seagulls_encoded1.txt"; 
  string jpeg_out2_debug = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/seagulls_encoded1_debug.txt"; 
  string jpeg_out3_debug = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/croissants_encoded.txt"; 
  string jpeg_out = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/seagulls_encoded2.txt";
  string jpeg_out_debug = "C:/Users/SiHi/Documents/jpeg_usb_simulation/jpeg/image_files/txts/seagulls_encoded2_debug.txt";

  $display("About to begin!\n");

  pixel_clock_in     = 1'b1;
  jpeg_slow_clock_in = 1'b1;
  jpeg_fast_clock_in = 1'b1;

  jpeg_fast_reset_n_in = 0;
  jpeg_slow_reset_n_in = 0;
  pixel_reset_n_in = 0;

  #(SYSCLK_PERIOD * 20);
  #(SYSCLK_PERIOD/3);
  button = 1;
  jpeg_fast_reset_n_in = 1;
  jpeg_slow_reset_n_in = 1;
  pixel_reset_n_in = 1;

  red_data_in = 0;
  green_data_in = 0;
  blue_data_in = 0;
  line_valid_in = 0;
  frame_valid_in = 0;

  x_size_in = ACTIVE_WIDTH;
  y_size_in = ACTIVE_HEIGHT;
  // qf_select_in = 2'b00; // 50% quality
  // qf_select_in = 2'b01; // 100% quality
  qf_select_in = 2'b10; // 10% quality
  // qf_select_in = 2'b11; // 25% quality  

    #250
    
    wait(jpeg_usb_top_inst.handshake_finished);
    #2000000;


    // fork
        send_image(image_in1, x_size_in, y_size_in);
    //     // capture_jpeg(jpeg_out);
    //     capture_jpeg_debug(jpeg_out_debug);
    //     // monitor_end_of_frame();
    // join

    $display("JPEG encoding for frame 1 complete\n");

    // todel //
    #1000000;
    $finish;

    #5000
    @(posedge pixel_clock_in);

    // fork
        send_image(image_in2, x_size_in, y_size_in);
    //     // capture_jpeg(jpeg_out2);
    //     capture_jpeg_debug(jpeg_out2_debug);
    //     // monitor_end_of_frame();
    // join

    $display("JPEG encoding for frame 2 completed.");

    // add this just to trigger the afifo //
    #5000

    // fork
        send_image(image_in3, x_size_in, y_size_in);
    //     // capture_jpeg(jpeg_out);
    //     capture_jpeg_debug(jpeg_out3_debug);
    //     // monitor_end_of_frame();
    // join

    $display("JPEG encoding for frame 3 complete\n");    

    #1000000;

    $finish;

    end
    begin

      usb_read_write();

    end

    join

  $fclose(dump_file);
  $fclose(debug_file_usb_jpeg);
  $fclose(debug_file_jpeg);
  $fclose(debug_file_afifo);
  $fclose(debug_file_usb_audio);
  
  $finish;

end

task usb_read_write;

begin

  button = 0;
  DIR = 0;
  NXT = 0;
  data_drive = 8'h00;
  phyclk = 1; sysclk = 1;

  #(SYSCLK_PERIOD * 20);
  #(SYSCLK_PERIOD/3);
  button = 1;

  // the initial RXCMD //
  phy_sends_rxcmd();

  // wait at least 2.5us
  wait(jpeg_usb_top_inst.usb_top_inst.fsm_setup_highspeed_inst.se0counterdone == 1'b1);     

  // we write ID register
  phy_accepts_data(2, DELAY);

  // we write register to disconnect //
  phy_accepts_data(2, DELAY);

  // phy sends RXCMD after reconnecting //
  phy_sends_rxcmd();        
  
  // wait for se0 again
  wait(jpeg_usb_top_inst.usb_top_inst.fsm_setup_highspeed_inst.se0counterdone == 1'b1);     

  // writing to registers regularly now //
  phy_accepts_data(2, DELAY);
  phy_accepts_data(2, DELAY);
  phy_accepts_data(2, DELAY);
  phy_accepts_data(2, DELAY);        

  // send TXCMD chirp //
  #(PHY_CLK_PERIOD * 30);

  // phy accepts the chirp //      
  phy_accepts_data(2, NO_DELAY);

  // at this point we sent h00 continuously //
  wait(STP);
  @(posedge phyclk); #5 NXT = 0;

  #(PHY_CLK_PERIOD * 40); 
  
  // here, host is supposed to send JK sequence (in RXCMDs) //
  phy_sends_j();
  phy_sends_k();       
  phy_sends_j();
  phy_sends_k(); 
  phy_sends_j();
  phy_sends_k();         

  #(PHY_CLK_PERIOD * 10);    

  // phy sends one more rxcmd //
  phy_sends_rxcmd();

  // as soon as we receive JK sequence, we write opmode
  phy_accepts_data(2, DELAY);

  // here high speed setup has ended //
  
  // phase 0 - get descriptor device //
  get_descriptor_setup_in_out(21, GET_DEVICE_DESCRIPTOR);

  // phase 1 - set address //
  get_descriptor_setup_out(SET_ADDRESS);

  // phase 2 - get descriptor device //
  get_descriptor_setup_in_out(21, GET_DEVICE_DESCRIPTOR);

  // phase 3 - get descriptor config //
  get_descriptor_setup_multiplein_out(0, GET_CONFIG_DESCRIPTOR_255BYTES);
  get_descriptor_setup_multiplein_out(4, GET_CONFIG_DESCRIPTOR_FULL);

  // phase 4 - get descriptor device //
  get_descriptor_setup_in_out(21, GET_DEVICE_DESCRIPTOR);

  // phase 5 - get descriptor config, 9 bytes only
  get_descriptor_setup_in_out(12, GET_CONFIG_DESCRIPTOR_9BYTES); // PID & 9 bytes + 2crc //

  // phase 6 - get descriptor config, all bytes //
  get_descriptor_setup_multiplein_out(4, GET_CONFIG_DESCRIPTOR_FULL);

  // phase 7 - set config //
  get_descriptor_setup_out(SET_CONFIGURATION);

  // phase 8 - set interface //
  get_descriptor_setup_out(SET_INTERFACE);

  // phase 9 - set interface again//     
  get_descriptor_setup_out(SET_INTERFACE);

  // phase 10 - set interface again//     
  get_descriptor_setup_out(SET_INTERFACE);   

  // phase 11 - set interface again//     
  get_descriptor_setup_out(SET_INTERFACE);      

  // phase 12 - get cur //     
  get_descriptor_setup_in_out(29, GET_CUR_VIDEO_PROBE);   

  get_descriptor_setup_in_out(4, GET_CUR_AUDIO_MUTE);  

  get_descriptor_setup_in_out(5, GET_CUR_AUDIO_VOL);

  // send a SOF at this point //
  wait (send_sof);

  // phase 13 - SET_CUR //
  get_descriptor_setup_out_zlp(13, SET_CUR); 

  // phase 14 - get cur again//
  get_descriptor_setup_in_out(29, GET_CUR_VIDEO_PROBE); 

  // phase 15 - get max //
  get_descriptor_setup_in_out(5, GET_MAX_AUDIO_VOL); 

  // phase 16 - get min//
  get_descriptor_setup_in_out(5, GET_MIN_AUDIO_VOL);    

  get_descriptor_setup_in_out(5, GET_RES);  

  // phase 17 - SET_CUR again //
  get_descriptor_setup_out_zlp(13, SET_CUR);      

  // phase 18 - get cur //        
  get_descriptor_setup_in_out(29, GET_CUR_VIDEO_PROBE);

  // phase 19 - SET_CUR //
  get_descriptor_setup_out_zlp(13, SET_CUR);

  // phase 20 - set interface endpoint 1//
  get_descriptor_setup_out(SET_INTERFACE);

  // phase 21 - set interface endpoint 3//
  get_descriptor_setup_out(SET_INTERFACE);    
  get_descriptor_setup_out(SET_INTERFACE); 
  get_descriptor_setup_out(SET_INTERFACE); 
  get_descriptor_setup_out(SET_INTERFACE);    
  get_descriptor_setup_out(SET_INTERFACE); 
  get_descriptor_setup_out(SET_INTERFACE);     

  // // phase 21 - set interface //
  // get_descriptor_setup_out(SET_INTERFACE);    

  // phases have concluded - PHY sends an IN PID with ENDPOINT 1 //
  // I can keep responding / reading packets but for now we shift focus //

  wait (send_sof);

  // each iteration is a microframe //
  for (i = 0; i < 2000; i = i + 1) begin

    phy_sends_sof();

    sequence_complete = 1'b0;

    while (!sequence_complete) begin

      #(PHY_CLK_PERIOD * 10);
      phy_sends_in(ENDPOINT1);
      #(PHY_CLK_PERIOD * 10);

      wait ((DATA[7:4] == 4'b0100) && ( DATA[1:0] == 2'b11)); // PID DATA0 / DATA1 / DATA2 //

      if (DATA[3:0] == PID_DATA0[3:0]) sequence_complete = 1'b1;

      stp_flag = 1'b0;

      while (!stp_flag) begin
      
        // random chance 1-3 NXT blanks is added before //
        repeat(3) begin
          if ($urandom_range(0, 9) == 9) begin
            @(posedge phyclk); #5 NXT = 0;
            if (STP) begin
              stp_flag = 1'b1; 
              break;
            end
          end
        end

        @(posedge phyclk); #5 NXT = 1;

        if (STP) stp_flag = 1'b1;

      end

      @(posedge phyclk); #5 NXT = 0;
      #(PHY_CLK_PERIOD * 10);					

    end

    // send audio data //
    #(PHY_CLK_PERIOD * 10);

    if (i%8 == 0) begin
    
      phy_sends_in(ENDPOINT2);
      #(PHY_CLK_PERIOD * 10);

      wait ((DATA[7:4] == 4'b0100) && ( DATA[1:0] == 2'b11)); // PID DATA0 / DATA1 / DATA2 //

      stp_flag = 1'b0;

      while (!stp_flag) begin
      
        // random chance 1-3 NXT blanks is added before //
        repeat(3) begin
          if ($urandom_range(0, 9) == 9) begin
            @(posedge phyclk); #5 NXT = 0;
            if (STP) begin
              stp_flag = 1'b1; 
              break;
            end
          end
        end

        @(posedge phyclk); #5 NXT = 1;

        if (STP) stp_flag = 1'b1;

      end

      @(posedge phyclk); #5 NXT = 0;
      #(PHY_CLK_PERIOD * 10);					

    end     

    wait (send_sof);
  end

  #(PHY_CLK_PERIOD * 3000);    

end

endtask

task get_descriptor_setup_in_out(input integer wait_cycles, input [4:0] request);
  begin
    phy_sends_setup();
    phy_sends_request(request);
    // we send ACK //
    phy_accepts_data(2, DELAY); // phy accepts ACK //
    phy_sends_in(ENDPOINT0);
    wait (!DIR && (DATA == 8'h4B)); // we send DATA1 //
    phy_accepts_data(wait_cycles, NO_DELAY); // phy accepts DATA1 //
    // phy_sends_sof();       
    phy_sends_ack(); 
    phy_sends_out();
    phy_sends_data1_short();  // phy sends ZLP //
    // phy_sends_sof();  
    // we send ACK //
    phy_accepts_data(2, DELAY); // phy accepts ACK //
  end
endtask

// when we want to sends more than 64 bytes as a response to a single request //
task get_descriptor_setup_multiplein_out(input integer wait_cycles, input [4:0] request); // wait_cycles applies to the final in transaction, the first two are always 67 (pid + 64bytes + 2crc)
  begin
    
    phy_sends_setup();
    phy_sends_request(request);
    // we send ACK //
    phy_accepts_data(2, DELAY); // phy accepts ACK //
    phy_sends_in(ENDPOINT0);
    phy_sends_rxcmd();
    wait (!DIR && (DATA == 8'h4B)); // we send DATA1 //
    phy_accepts_data(67, NO_DELAY); // phy accepts DATA1 //
    phy_sends_ack();        
    phy_sends_in(ENDPOINT0);  
    wait (!DIR && (DATA == 8'h43)); // we send DATA0 //
    phy_accepts_data(67, NO_DELAY); // phy accepts DATA0 //
    phy_sends_ack();         
    phy_sends_in(ENDPOINT0);  
    phy_sends_rxcmd();
    wait (!DIR && (DATA == 8'h4B)); // we send DATA1 //
    phy_accepts_data(67, NO_DELAY); // phy accepts DATA1 //
    phy_sends_ack();        
    phy_sends_in(ENDPOINT0);   
    wait (!DIR && (DATA == 8'h43)); // we send DATA0 //
    phy_accepts_data(66 + (wait_cycles != 0), NO_DELAY); // phy accepts DATA0 //
    phy_sends_ack();
    if (wait_cycles != 0) begin 
      phy_sends_in(ENDPOINT0);  
      phy_sends_rxcmd();      
      wait (!DIR && (DATA == 8'h4B)); // we send DATA1 //
      phy_accepts_data(wait_cycles, NO_DELAY); // phy accepts DATA1 //        
      // phy_sends_sof();       
      phy_sends_ack(); 
    end
    phy_sends_out();
    phy_sends_data1_short(); // phy sends ZLP //
    // phy_sends_sof();
    // we send ACK //
    phy_accepts_data(2, DELAY); // phy accepts ACK //
  end
endtask  

task get_descriptor_setup_out_zlp(input integer receive_cycles, input [4:0] request);
  begin
    phy_sends_setup();
    phy_sends_request(request);
    // we send ACK //
    phy_accepts_data(2, DELAY); // phy accepts ACK //
    phy_sends_out();
    phy_sends_data1_long(receive_cycles); // phy sends data1 packet with actual data //
    // we send ACK //
    phy_accepts_data(2, DELAY); // phy accepts ACK //
    phy_sends_in(ENDPOINT0); 
    // we send ZLP DATA1 //
    phy_accepts_data(2, DELAY); // phy accepts ZLP DATA1 //
    phy_sends_sof(); 
    phy_sends_ack(); 
  end
endtask


task get_descriptor_setup_out(input [4:0] request);
  begin
    phy_sends_setup();
    phy_sends_request(request); 
    // we send ACK //
    phy_accepts_data(2, DELAY); // phy accepts ACK //
    phy_sends_in(ENDPOINT0);
    wait (!DIR && (DATA == 8'h4B)); // we send DATA1 //
    phy_accepts_data(3, NO_DELAY); // phy accepts DATA1 //
    phy_sends_ack();   
  end
endtask

task phy_sends_setup();
  begin
    #(PHY_CLK_PERIOD * 10);
    @(posedge phyclk); #5 DIR = 1'b1; // turnaround
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h2D; // setup pid //
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h07; // same as original address //
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h18; // random CRC //
    @(posedge phyclk); #5 DIR = 1'b0; NXT = 1'b0;
    #(PHY_CLK_PERIOD * 10);
  end
endtask

task phy_sends_in(input [1:0] endpoint);
  begin
    @(posedge phyclk); #5 DIR = 1'b1; // turnaround
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h69; // IN pid //

    if (endpoint == ENDPOINT0) begin
      @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h07;
      @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h18; // random CRC //
    end
    else if (endpoint == ENDPOINT1) begin
      @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h87;
      @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h18; // random CRC //
    end
    else if (endpoint == ENDPOINT2) begin
      @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h07;
      @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h19; // random CRC with endpoint 2 bit active //      
    end

    @(posedge phyclk); #5 DIR = 1'b0; NXT = 1'b0;
  end
endtask

task phy_sends_ack();
  begin
    #(PHY_CLK_PERIOD * 10);
    @(posedge phyclk); #5 DIR = 1'b1; // turnaround
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'hD2; //ack pid//
    @(posedge phyclk); #5 DIR = 1'b0; NXT = 1'b0;
    #(PHY_CLK_PERIOD * 10);   
  end
endtask

task phy_sends_sof();
  begin
    #(PHY_CLK_PERIOD * 10);
    @(posedge phyclk); #5 DIR = 1'b1; // turnaround
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'b1010_0101; // sof //
    @(posedge phyclk); #5 NXT = 1'b0; // sof //
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h7B; // random //
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'hD2; // random - ACK but must ignore!! //        
    @(posedge phyclk); #5 DIR = 1'b0; NXT = 1'b0;
    #(PHY_CLK_PERIOD * 10);  
  end
endtask

task phy_accepts_data(input int register_num, input delay_en);
  begin
    if (delay_en) #(PHY_CLK_PERIOD * 10); 
    repeat(register_num) begin @(posedge phyclk); #5 NXT = 0; @(posedge phyclk); #5 NXT = 1; end
    @(posedge phyclk); #5 NXT = 0;
    if (delay_en) #(PHY_CLK_PERIOD * 10);
  end
endtask

task phy_sends_out();
  begin
    #(PHY_CLK_PERIOD * 10);
    @(posedge phyclk); #5 DIR = 1'b1; // turnaround
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'hE1; //out pid//
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h66; // random //
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h99; // random //
    @(posedge phyclk); #5 DIR = 1'b0; NXT = 1'b0;
    #(PHY_CLK_PERIOD * 10);  
  end
endtask

task phy_sends_data1_short();
  begin
    #(PHY_CLK_PERIOD * 10);
    @(posedge phyclk); #5 DIR = 1'b1; // turnaround
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'b0100_1011; //data1 pid//
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h66; // random //
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h99; // random //        
    @(posedge phyclk); #5 DIR = 1'b0; NXT = 1'b0;
    #(PHY_CLK_PERIOD * 10); 
  end
endtask

task phy_sends_data1_long(input int receive_cycles);
  begin
    #(PHY_CLK_PERIOD * 10);
    @(posedge phyclk); #5 DIR = 1'b1; // turnaround
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'b0100_1011; //data1 pid//
    repeat((receive_cycles + 1)/2) begin // data + 2*CRC
      @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h66; // random //
      @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'h99; // random //
    end        
    @(posedge phyclk); #5 DIR = 1'b0; NXT = 1'b0;
    #(PHY_CLK_PERIOD * 10);  
  end
endtask

task phy_sends_request(input [4:0] request);
begin
    @(posedge phyclk); #5 DIR = 1'b1; // turnaround
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = 8'hC3; // DATA0 PID //
    @(posedge phyclk); #5 data_drive = request_memory[request][63:56]; // following is data that we decode //
    @(posedge phyclk); #5 data_drive = request_memory[request][55:48];
    @(posedge phyclk); #5 NXT = 1'b0; data_drive = 8'h45;
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = request_memory[request][47:40]; // this is the address //
    @(posedge phyclk); #5 data_drive = request_memory[request][39:32];
    @(posedge phyclk); #5 data_drive = request_memory[request][31:24];
    @(posedge phyclk); #5 data_drive = request_memory[request][23:16];
    @(posedge phyclk); #5 NXT = 1'b0; data_drive = 8'h45;        
    @(posedge phyclk); #5 data_drive = 8'h46;
    @(posedge phyclk); #5 NXT = 1'b1; data_drive = request_memory[request][15:8];                  
    @(posedge phyclk); #5 data_drive = request_memory[request][7:0];    
    @(posedge phyclk); #5 data_drive = 8'ha9; // this is crc //
    @(posedge phyclk); #5 data_drive = 8'haA; // this is crc //
    @(posedge phyclk); #5 DIR = 1'b0;      NXT = 1'b0;  
  end
endtask

task phy_sends_rxcmd();
  begin
    #(PHY_CLK_PERIOD);
    @(posedge phyclk); #5 DIR = 1'b1; // turnaround
    @(posedge phyclk); #5 data_drive = 8'b0100_1100;
    @(posedge phyclk); #5 DIR = 1'b0;
  end
endtask

task phy_sends_j();
  begin
    @(posedge phyclk); #5 DIR = 1'b1; 
    @(posedge phyclk); #5 data_drive = 8'b11111110;
    @(posedge phyclk); #5 DIR = 1'b0;
    #(PHY_CLK_PERIOD * 200); 
  end
endtask

task phy_sends_k();
  begin
    @(posedge phyclk); #5 DIR = 1'b1; 
    @(posedge phyclk); #5 data_drive = 8'b11111101;
    @(posedge phyclk); #5 DIR = 1'b0;
    #(PHY_CLK_PERIOD * 200); 
  end
endtask



endmodule