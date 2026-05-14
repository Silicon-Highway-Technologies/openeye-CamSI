`timescale 1ns/100ps

`include "request_parameters.vh"
parameter DELAY = 1'b1;
parameter NO_DELAY = 1'b0;

parameter ENDPOINT0 = 2'b00;
parameter ENDPOINT1 = 2'b01;
parameter ENDPOINT2 = 2'b10;

module usb_tb();

  // Parameters
  localparam SYS_CLK_PERIOD = 5; // 200MHz Differential Clock
  localparam PHY_CLK_PERIOD = 16.67; // 60MHz ULPI Clock

  // Signals
  reg button; reg sysclk; reg sysrst; reg phyclk; reg DIR; reg NXT;
  wire led; wire STP; wire phyrst;

  wire mclk;
  reg mdata;
  wire mdis;
  
  wire [15:0] debug_pins; wire [7:0] DATA;

  reg [7:0] data_drive;
  wire [7:0] data_recv;

  assign DATA = (DIR == 1) ? data_drive : 8'bZZZZ_ZZZZ;

  integer num_of_packets = 32'd100;
  integer bytes_per_packet = 16'd512;
  integer i, j;

  usb_top usb_top_inst (
    .button(button),
    .led(led),
    .sysclk(sysclk),
    .sysrst(sysrst),
    .phyclk(phyclk),
    .DIR(DIR),
    .NXT(NXT),
    .STP(STP),
    .DATA(DATA),
    .phyrst(phyrst),
    .mclk(mclk),
    .mdata(mdata),
    .mdis(mdis),    
    .debug_pins(debug_pins)
  );

  // Clock Generation
  always #(SYS_CLK_PERIOD/2.0) sysclk = ~sysclk;
  always #(PHY_CLK_PERIOD/2.0) phyclk = ~phyclk;

  always @(posedge mclk) begin
    #30 mdata = $urandom_range(0, 1);
  end

  logic [63:0] request_memory [0:16];

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

  // Test Procedure
  initial begin
    // Initialize Signals
    sysrst = 0;
    button = 0;
    DIR = 0;
    NXT = 0;
    data_drive = 8'h00;
    phyclk = 1; sysclk = 0;

    #(SYS_CLK_PERIOD * 10);
    sysrst = 1;

    #(SYS_CLK_PERIOD * 20);
    #(SYS_CLK_PERIOD/3);
    button = 1;
    
    // the initial RXCMD //
    phy_sends_rxcmd();

    // wait at least 2.5us
    wait(usb_top_inst.fsm_setup_highspeed_inst.se0counterdone == 1'b1);     

    // we write ID register
    phy_accepts_data(2, DELAY);

    // we write register to disconnect //
    phy_accepts_data(2, DELAY);

    // phy sends RXCMD after reconnecting //
    phy_sends_rxcmd();        
    
    // wait for se0 again
    wait(usb_top_inst.fsm_setup_highspeed_inst.se0counterdone == 1'b1);     

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

    // for (i = 0; i < 1000; i = i + 1) begin // repeat this 100 times
    while(1) begin

      // send video data //

      #(PHY_CLK_PERIOD * 10);
      phy_sends_in(ENDPOINT1);
      #(PHY_CLK_PERIOD * 10);

      // we add 4 nxt: 1 for PID, 2 for CRC and one when we assert STP //
      for (j = 0; j < bytes_per_packet + 4; j = j + 1) begin 
        
        // random chance 1-3 NXT blanks is added before //
        repeat(3) begin
          if ($urandom_range(0, 9) == 9) begin
            @(posedge phyclk); #5 NXT = 0;
          end
        end

        @(posedge phyclk); #5 NXT = 1;
      end

      @(posedge phyclk); #5 NXT = 0;
      #(PHY_CLK_PERIOD * 10);					
      
      phy_sends_ack();

      // send audio data //

      #(PHY_CLK_PERIOD * 10);
      phy_sends_in(ENDPOINT2);
      #(PHY_CLK_PERIOD * 10);

      // we add 4 nxt: 1 for PID, 2 for CRC and one when we assert STP //
      for (j = 0; j < 16; j = j + 1) begin 
        
        // random chance 1-3 NXT blanks is added before //
        repeat(3) begin
          if ($urandom_range(0, 9) == 9) begin
            @(posedge phyclk); #5 NXT = 0;
          end
        end

        @(posedge phyclk); #5 NXT = 1;
      end

      @(posedge phyclk); #5 NXT = 0;
      #(PHY_CLK_PERIOD * 10);					
      
      phy_sends_ack();      
    end

    #(PHY_CLK_PERIOD * 3000);    

    $finish;
  end

task get_descriptor_setup_in_out(input integer wait_cycles, input [4:0] request);
  begin
    phy_sends_setup();
    phy_sends_request(request);
    // we send ACK //
    phy_accepts_data(2, DELAY); // phy accepts ACK //
    phy_sends_in(ENDPOINT0);
    wait (!DIR && (DATA == 8'h4B)); // we send DATA1 //
    phy_accepts_data(wait_cycles, NO_DELAY); // phy accepts DATA1 //
    phy_sends_sof();       
    phy_sends_ack(); 
    phy_sends_out();
    phy_sends_data1_short();  // phy sends ZLP //
    phy_sends_sof();  
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
      phy_sends_sof();       
      phy_sends_ack(); 
    end
    phy_sends_out();
    phy_sends_data1_short(); // phy sends ZLP //
    phy_sends_sof();
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