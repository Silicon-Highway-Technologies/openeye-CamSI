// SPDX-FileCopyrightText: 2024 Chili.CHIPS*ba
//
// SPDX-License-Identifier: BSD-3-Clause

//======================================================================== 
// openeye-CamSI * NLnet-sponsored open-source core for Camera I/F with ISP
//------------------------------------------------------------------------
//                   Copyright (C) 2024 Chili.CHIPS*ba
// 
// Redistribution and use in source and binary forms, with or without 
// modification, are permitted provided that the following conditions 
// are met:
//
// 1. Redistributions of source code must retain the above copyright 
// notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright 
// notice, this list of conditions and the following disclaimer in the 
// documentation and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its 
// contributors may be used to endorse or promote products derived
// from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS 
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED 
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//              https://opensource.org/license/bsd-3-clause
//------------------------------------------------------------------------
// Description: This is the Chip top-level file. It includes:
//   - Main PLL with top-level clock and reset generation
//   - Xilinx-specific IDELAY controller
//   - I2C Master for loading configuration into camera
//   - CSI_RX camera front-end
//   - ISP blocks:
//        - raw2rgb
//   - Asynchronous FIFO
//   - HDMI monitor back-end
//   - Misc and Debug utilities
//========================================================================

module top 
   import top_pkg::*;
   import hdmi_pkg::*;
(
`ifdef PUZHI
   input logic   sys_rst_n,   // external active-1 asynchronous reset
   input logic   sys_clk_p,   // external 200MHz clock source
   input logic   sys_clk_n,
`else
   input logic   areset,   // external active-1 asynchronous reset
   input logic   clk_ext,  // external 100MHz clock source
`endif

  //I2C_Master to Camera
`ifdef COCOTB_SIM
   inout  tri1   i2c_sda,
   inout  tri1   i2c_scl,
`else
   inout  wire   i2c_sda,
   inout  wire   i2c_scl,
`endif //COCOTB_SIM

  //MIPI DPHY from/to Camera
   input  diff_t      cam_dphy_clk,
   input  lane_diff_t cam_dphy_dat,

   output logic       cam_en,
      
  //HDMI output, goes directly to connector
   output logic  hdmi_clk_p,
   output logic  hdmi_clk_n,
   output bus3_t hdmi_dat_p,
   output bus3_t hdmi_dat_n,

   // audio //
    output logic mclk,
    input mdata,
    output logic mdis, 

    // usb //
    input phyclk, // 60MHz //
    input DIR,
    input NXT,
    output logic STP,
    inout logic [7:0] DATA,
    output logic phyrst,

//   //Misc/Debug

    output logic led,
    output logic [15:0] debug_pins
);

`include "settings.vh"

`ifdef COCOTB_SIM
glbl glbl();
`endif

`ifdef PUZHI

logic areset;
assign areset = ~sys_rst_n;

// generate clk using IBUFDS //
logic clk_ext;

IBUFDS #(
    .DIFF_TERM("FALSE"),
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD("DEFAULT")
) IBUFDS_inst(
    .O(clk_ext),
    .I(sys_clk_p),
    .IB(sys_clk_n)
);

`endif 

//--------------------------------
// Clock and reset gen
//--------------------------------
   logic reset, i2c_areset_n;   
   logic clk_100, clk_180, clk_200, clk_1hz, strobe_400kHz;

   clkrst_gen u_clkrst_gen (
      .reset_ext     (areset),        //i
      .clk_ext       (clk_ext),       //i
                                       
      .clk_100       (clk_100),       //o: 100MHz 
      .clk_200       (clk_200),       //o: 200MHz
      .clk_1hz       (clk_1hz),       //o: 1Hz
      .strobe_400kHz (strobe_400kHz), //o: pulse1 at 400kHz

      .reset         (reset),         //o
      .cam_en        (cam_en),        //o
      .i2c_areset_n  (i2c_areset_n)   //o
   );

//--------------------------------
// I2C Master
//--------------------------------
   bus8_t debug_i2c;

   i2c_top  #(
      .I2C_SLAVE_ADDR (top_pkg::I2C_SLAVE_ADDR),
      .NUM_REGISTERS  (top_pkg::NUM_REGISTERS)
   ) u_i2c  (
     //clocks and resets
      .clk           (clk_100),       //i
      .strobe_400kHz (strobe_400kHz), //i
      .areset_n      (i2c_areset_n),  //i

     //I2C_Master to Camera
      .i2c_scl       (i2c_scl),       //io 
      .i2c_sda       (i2c_sda),       //io

     //Misc/Debug
      .debug_pins    (debug_i2c)      //o[7:0]
   );

//--------------------------------
// CSI_RX
//--------------------------------
   logic           csi_byte_clk;
   lane_raw_data_t csi_word_data;
   logic           csi_word_valid;
   logic           csi_in_line, csi_in_frame;   

   bus8_t         debug_csi;
    
   csi_rx_top u_csi_rx_top (
      .ref_clock              (clk_200),        //i 
      .reset                  (reset),          //i 
                          
     //MIPI DPHY from/to Camera
      .cam_dphy_clk           (cam_dphy_clk),   //i'diff_t
      .cam_dphy_dat           (cam_dphy_dat),   //i'lane_diff_t
      .cam_en                 (cam_en),         //i 

     //CSI to internal video pipeline     
      .csi_byte_clk           (csi_byte_clk),   //o
      .csi_unpack_raw_dat     (csi_word_data),  //o'lane_raw_data_t
      .csi_unpack_raw_dat_vld (csi_word_valid), //o

      .csi_in_line            (csi_in_line),    //o    
      .csi_in_frame           (csi_in_frame),   //o

     //Misc/Debug
      .debug_pins             (debug_csi)       //o[7:0]
   );
      
//--------------------------------
// ISP Functions
//--------------------------------
   logic  rgb_valid;
   pix_t  rgb_pix;
   logic  rgb_reading;

   isp_top #(
      .LINE_LENGTH (HSCREEN/NUM_LANE),  // number of data entries per line
      .RGB_WIDTH   ($bits(pix_t))       // width of RGB data (24-bit)
   )
   u_isp (
      .clk        (csi_byte_clk),   //i           
      .rst        (reset),          //i

      .data_valid (csi_word_valid), //i  
      .rgb_valid  (rgb_valid),      //i
      .data_in    (csi_word_data),  //i'lane_raw_data_t

      .csi_in_frame(csi_in_frame),  //i
      
      .reading    (rgb_reading),    //o
      .rgb_out    (rgb_pix)         //o[RGB_WIDTH-1:0]
   );
      
//--------------------------------
// AsyncFIFO with Synchronization
//--------------------------------
   logic hdmi_clk;
   logic hdmi_frame;
   logic hdmi_blank;
   logic hdmi_reset_n;
   pix_t hdmi_pix;
   bus4_t debug_fifo;

   rgb2hdmi u_rgb2hdmi (
     //from/to CSI and RGB block
      .csi_clk      (csi_byte_clk),   //i           
      .reset        (reset),          //i

      .csi_in_line  (csi_in_line),    //i  
      .csi_in_frame (csi_in_frame),   //i  

      .rgb_pix      (rgb_pix),        //i'pix_t
      .rgb_reading  (rgb_reading),    //i 
      .rgb_valid    (rgb_valid),      //o

     //from/to HDMI block
      .hdmi_clk     (hdmi_clk),       //i

      .hdmi_frame   (hdmi_frame),     //i
      .hdmi_blank   (hdmi_blank),     //i
      .hdmi_reset_n (hdmi_reset_n),   //o
      .hdmi_pix     (hdmi_pix),       //o'pix_t 

      .debug_fifo   (debug_fifo)      //o'bus4_t
   );


  logic jpeg_fast_clock;
  logic jpeg_slow_clock;
  logic pixel_clock;

  jpeg_clkgen jpeg_clkgen_inst(
    .sysclk(clk_ext),
    .reset(areset),
    .hdmi_clock(hdmi_clk),
    .jpeg_fast_clock(jpeg_fast_clock),
    .jpeg_slow_clock(jpeg_slow_clock),
    .pixel_clock(pixel_clock)
  );
  
  logic [31:0] data_out;
  logic [23:0] address_out;
  logic image_valid_out;
  logic data_valid_out;
  logic [2:0] state;

  // jpeg_encoder jpeg_encoder_inst (
  //   .start_capture_in(cam_en),
  //   .red_data_in({hdmi_pix.R, 2'b0}),
  //   .green_data_in({hdmi_pix.G, 2'b0}),
  //   .blue_data_in({hdmi_pix.B, 2'b0}),
  //   .frame_valid_in(!hdmi_frame),
  //   .line_valid_in(!hdmi_blank),
  //   .data_out(data_out),
  //   .address_out(address_out),
  //   .image_valid_out(image_valid_out),
  //   .data_valid_out(data_valid_out),
  //   .qf_select_in(2'b10),
  //   .x_size_in(11'd1280),
  //   .y_size_in(10'd720),
  //   .pixel_clock_in(pixel_clock),
  //   .pixel_reset_n_in(sys_rst_n),
  //   .jpeg_fast_clock_in(jpeg_fast_clock),
  //   .jpeg_fast_reset_n_in(sys_rst_n),
  //   .jpeg_slow_clock_in(jpeg_slow_clock),
  //   .jpeg_slow_reset_n_in(sys_rst_n),
  //   .state(state),
  //   .*
  // );

logic start_capture;

always @(posedge pixel_clock) begin

  if (!sys_rst_n) start_capture <= 1'b0;

  else if (usb_handshake_finished && !line_valid && !frame_valid) start_capture <= 1'b1;

end

logic [7:0] afifo_data_out;
logic afifo_data_valid_out;
logic afifo_wait;
logic sending_packet;
logic usb_handshake_finished;
logic [15:0] debug_jpeg_usb;
logic afifo_led;
logic jpeg_data_valid_out;
logic full;

logic frame_valid, line_valid;
assign frame_valid = !hdmi_frame;
assign line_valid = !hdmi_blank;

jpeg_usb_top jpeg_usb_top_inst (
  .button               (sys_rst_n),
  // .led                  (led),
  .sysclk(clk_ext),

  // USB3343 ULPI Interface
  .phyclk               (phyclk),
  .DIR                  (DIR),
  .NXT                  (NXT),
  .STP                  (STP),
  .DATA                 (DATA),
  .phyrst               (phyrst),
  .debug_jpeg_usb       (debug_jpeg_usb),

  .full(full),

  // JPEG Input
  .start_capture_in(start_capture),
  // .start_capture_in(csi_in_frame),
  .red_data_in(hdmi_pix.R),
  .green_data_in(hdmi_pix.G),
  .blue_data_in(hdmi_pix.B),
  .frame_valid_in(frame_valid),
  .line_valid_in(line_valid),
  .image_valid_out      (image_valid_out),
`ifdef QF10
  .qf_select_in(2'b10),
`elsif QF25
  .qf_select_in(2'b11),
`elsif QF50
  .qf_select_in(2'b00),
`elsif QF100
  .qf_select_in(2'b01),
`endif

`ifdef HDMI_720p60
  .x_size_in            (11'd1280),
  .y_size_in            (10'd720),
`elsif HDMI_1080p30
  .x_size_in            (11'd1920),
  .y_size_in            (11'd1080),
`endif

  // Clocks and Resets
  .pixel_clock_in(pixel_clock),
  .pixel_reset_n_in(sys_rst_n),
  .jpeg_fast_clock_in(jpeg_fast_clock),
  .jpeg_fast_reset_n_in(sys_rst_n),
  .jpeg_slow_clock_in(jpeg_slow_clock),
  .jpeg_slow_reset_n_in(sys_rst_n),

  // audio //
  .mclk(mclk),
  .mdis(mdis),
  .mdata(mdata),

  // Status Signals
  .sending_packet       (sending_packet),
  .handshake_finished (usb_handshake_finished)
);

//--------------------------------
// HDMI backend
//--------------------------------
   logic hdmi_hsync, hdmi_vsync;
   bus12_t x;
   bus11_t y;

   hdmi_top u_hdmi_top(
      .clk_ext      (clk_100),      //i 
      .clk_pix      (hdmi_clk),     //o
                     
      .pix          (hdmi_pix),     //i'pix_t  
     
     //synchronization
      .hdmi_reset_n (hdmi_reset_n), //i

      .hdmi_frame   (hdmi_frame),   //o

      .blank        (hdmi_blank),   //o
      .vsync        (hdmi_vsync),   //o 
      .hsync        (hdmi_hsync),   //o 
                     
     //HDMI output, goes directly to connector
      .hdmi_clk_p   (hdmi_clk_p),   //o
      .hdmi_clk_n   (hdmi_clk_n),   //o
      .hdmi_dat_p   (hdmi_dat_p),   //o'bus3_t
      .hdmi_dat_n   (hdmi_dat_n),   //o'bus3_t

      .x            (x),            //o'bus12_t
      .y            (y)             //o'bus11_t
   );
  
assign debug_pins = debug_jpeg_usb;

assign led = full;

endmodule: top

/*
------------------------------------------------------------------------------
Version History:
------------------------------------------------------------------------------
 2024/2/30  AnelH: Initial creation
 2024/3/14  Armin Zunic: updated based on sim results
 2024/11/12 Armin Zunic: updated for code readability
*/
