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
// Description: Top-level interconnect for all ISP functions
//========================================================================

module isp_top
  import top_pkg::*;
  import hdmi_pkg::*;
#(
   parameter LINE_LENGTH = 640, // number of data entries per line
   parameter RGB_WIDTH   = 24   // width of RGB data (24-bit)
)(
   input  logic            clk, // byte_clock      
   input  logic            rst,

   input areset,
                        
   input  lane_raw_data_t  data_in,
   input  logic            data_valid,    
   input  logic            rgb_valid,

   input  logic            csi_in_frame,
                        
   output logic            reading,
   output logic         
      [RGB_WIDTH-1:0]      rgb_out
);

//---------------------------------
// Debayer ISP function
//---------------------------------

logic [RGB_WIDTH - 1 : 0] rgb_out_scb;
logic [RGB_WIDTH - 1 : 0] rgb_gamma;
logic reading_scb;
logic reading_gamma;


`ifdef RAW8
   raw2rgb_8 
`elsif RAW10
   raw2rgb_10
`else
   raw2rgb_12
`endif
     
  #(
      .LINE_LENGTH (HSCREEN/NUM_LANE), // number of data entries per line
      .RGB_WIDTH   (RGB_WIDTH)         // width of RGB data (24-bit)
   )
   u_raw2rgb (
      .clk        (clk),               //i           
      .rst        (rst),               //i
                                        
      .data_in    (data_in),           //i'lane_raw_data_t
      .data_valid (data_valid),        //i  
      .rgb_valid  (rgb_valid),         //i

`ifdef SCB
      .reading    (reading_scb),           //o
      .rgb_out    (rgb_out_scb)            //o[RGB_WIDTH-1:0]
`else
      .reading    (reading_gamma),           //o
      .rgb_out    (rgb_gamma)            //o[RGB_WIDTH-1:0]
`endif
   );


`ifdef SCB

// stall reading for one cycle //
always @(posedge clk) begin

 if (rst) begin
   reading_gamma <= 1'b0;
 end
 else begin
   reading_gamma <= reading_scb;
 end

end

logic [7:0] red_out;
logic [7:0] blue_out;
logic [7:0] green_out;

// raise signals line_valid and frame_valid accordingly //
// which are used by simple color balance //
line_frame_signal_generator line_frame_signal_generator_inst(
   .clk(clk),
   .rst(rst),
   .reading(reading_gamma),
   .csi_in_frame(csi_in_frame),
   .line_valid_in(line_valid_in),
   .frame_valid_in(frame_valid_in)
);

simplecolorbalance simplecolorbalance_inst(
   .clk(clk),
   .reset_async(rst),

   .red_data_in(rgb_out_scb[23:16]),
   .green_data_in(rgb_out_scb[15:8]),
   .blue_data_in(rgb_out_scb[7:0]),

   .line_valid_in(line_valid_in),
   .frame_valid_in(frame_valid_in),

   // .line_valid_out(line_valid_out), // currently unused //
   // .frame_valid_out(frame_valid_out), // currently unused //

   .red_data_out(red_out),
   .green_data_out(green_out),
   .blue_data_out(blue_out)
);

assign rgb_gamma = {red_out, green_out, blue_out};

`endif

// module for gamma correction //

rgb_gamma rgb_gamma_inst(
  .clk(clk),
  .rst(areset),

  .rgb_in(rgb_gamma),
  .rgb_valid_in(reading_gamma),

  .shadow_boost_en(1'b0),

  .rgb_out(rgb_out),
  .rgb_valid_out(reading)
);

   
endmodule: isp_top

/*
------------------------------------------------------------------------------
Version History:
------------------------------------------------------------------------------
 2024/5/14 Armin Zunic: initial creation
*/
