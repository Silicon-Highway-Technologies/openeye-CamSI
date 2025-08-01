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
// Description: Common HDMI-related declarations
//========================================================================

`ifndef __HDMI_PKG__
`define __HDMI_PKG__
package hdmi_pkg;
   import top_pkg::*;

//-----------------------------------------------------------
// Screen Resolution and timings:
//-----------------------------------------------------------
// See: https://github.com/hdl-util/hdmi/blob/master/src/hdmi.sv
//      https://www.fpga4fun.com/HDMI.html
//      https://tomverbeure.github.io/video_timings_calculator (CEA-861)
//      https://tomverbeure.github.io/video_timings_calculator (CVT-RBv2)
//      https://purisa.me/blog/hdmi-released
//-----------------------------------------------------------

//-----------------------------
// 1280x720Px60Hz
//-----------------------------
`ifdef HDMI_720p60
   `ifdef OV2740
       localparam int HFRAME         = 1362; // complete frame X //1650 //1456 //1500 //1362
       localparam int HSCREEN        = 1280; // visible X
       localparam int HSYNC_START    = HSCREEN;
       localparam int HSYNC_SIZE     = 82; //82
       localparam int HSYNC_END      = HSYNC_START + HSYNC_SIZE;
       localparam bit HSYNC_POLARITY = HI;    // '+'
    
       localparam int VFRAME         = 1100;  // complete frame Y //750 //850 //1100
       localparam int VSCREEN        = 720;  // visible Y
       localparam int VSYNC_START    = VSCREEN;
       localparam int VSYNC_SIZE     = 380; // 380
       localparam int VSYNC_END      = VSYNC_START + VSYNC_SIZE;       
       localparam bit VSYNC_POLARITY = HI;    // '+' 
       
   `elsif HDMI2VGA
      localparam int HSCREEN        = 1280; // visible X
      localparam int HSYNC_SIZE     = 5; //5
      localparam int HSYNC_BACK     = 5; //40
      localparam int HSYNC_FRONT    = 397; //352
      localparam int HSYNC_START    = HSYNC_SIZE + HSYNC_BACK;
      localparam int HSYNC_END      = HSYNC_START + HSCREEN;
      localparam int HFRAME         = HSYNC_END + HSYNC_FRONT; //1677 or 1687
      localparam bit HSYNC_POLARITY = HI;    // '+'

      localparam int VSCREEN        = 720;  // visible Y
      localparam int VSYNC_SIZE     = 7; //7
      localparam int VSYNC_BACK     = 0;
      localparam int VSYNC_FRONT    = 130; //124
      localparam int VSYNC_START    = VSYNC_SIZE + VSYNC_BACK;
      localparam int VSYNC_END      = VSCREEN;
      localparam int VFRAME         = VSYNC_END + VSYNC_FRONT;  // complete frame Y = 850
      localparam bit VSYNC_POLARITY = HI;    // '+'   
   `else
      localparam int HFRAME         = 1687; // complete frame X //1650 //1456 //1500
      localparam int HSCREEN        = 1280; // visible X
      localparam int HSYNC_START    = HSCREEN;
      localparam int HSYNC_SIZE     = 407;
      localparam int HSYNC_END      = HSYNC_START + HSYNC_SIZE;
      localparam bit HSYNC_POLARITY = HI;    // '+'

      localparam int VFRAME         = 850;  // complete frame Y //750 //850
      localparam int VSCREEN        = 720;  // visible Y
      localparam int VSYNC_START    = VSCREEN;
      localparam int VSYNC_SIZE     = 130;
      localparam int VSYNC_END      = VSYNC_START + VSYNC_SIZE;
      localparam bit VSYNC_POLARITY = HI;    // '+'   
    `endif
//----------------------------- 
// 1920x1080Px30Hz CVT-RBv2
//-----------------------------
`elsif HDMI_1080p30
   `ifdef IMX219
      localparam int HFRAME         = 2553; // complete frame X //1650 //1456 //1500 // change in i2c as well? //
      localparam int HSCREEN        = 1920; // visible X
      localparam int HSYNC_START    = HSCREEN; 
      localparam int HSYNC_SIZE     = 633;
      localparam int HSYNC_END      = HSYNC_START + HSYNC_SIZE;
      localparam bit HSYNC_POLARITY = HI;    // '+'

      localparam int VFRAME         = 1125;  // complete frame Y //750 //850
      localparam int VSCREEN        = 1080;  // visible Y
      localparam int VSYNC_START    = VSCREEN;
      localparam int VSYNC_SIZE     = 45;
      localparam int VSYNC_END      = VSYNC_START + VSYNC_SIZE;
      localparam bit VSYNC_POLARITY = HI;    // '+'   
   `else
      localparam int HFRAME         = 2065;  // complete frame X
      localparam int HSCREEN        = 1920;  // visible X
      localparam int HSYNC_START    = HSCREEN;
      localparam int HSYNC_SIZE     = 145;
      localparam int HSYNC_END      = HSYNC_START + HSYNC_SIZE;
      localparam bit HSYNC_POLARITY = HI;     // '+'
   
      localparam int VFRAME         = 1765;  // complete frame Y
      localparam int VSCREEN        = 1080;  // visible Y
      localparam int VSYNC_START    = VSCREEN;
      localparam int VSYNC_SIZE     = 685;
      localparam int VSYNC_END      = VSYNC_START + VSYNC_SIZE;
      localparam bit VSYNC_POLARITY = HI;     // '+'
   `endif
//-----------------------------
// 1920x1080Px60Hz CVT-RBv2
//-----------------------------
`else
   localparam int HFRAME         = 2000;  // complete frame X
   localparam int HSCREEN        = 1920;  // visible X
   localparam int HSYNC_START    = HSCREEN;
   localparam int HSYNC_SIZE     = 80;
   localparam int HSYNC_END      = HSYNC_START + HSYNC_SIZE;
   localparam bit HSYNC_POLARITY = HI;     // '+'
 
   localparam int VFRAME         = 1111;  // complete frame Y
   localparam int VSCREEN        = 1080;  // visible Y
   localparam int VSYNC_START    = VSCREEN;
   localparam int VSYNC_SIZE     = 31;
   localparam int VSYNC_END      = VSYNC_START + VSYNC_SIZE;
   localparam bit VSYNC_POLARITY = HI;     // '+'
`endif


//-----------------------------------------------------------
// Pixel and TDMS Declarations:
//  2 = Red
//  1 = Green
//  0 = Blue
//-----------------------------------------------------------
   typedef struct packed {
      bus8_t  R;   // [2]
      bus8_t  G;   // [1]
      bus8_t  B;   // [0]
   } pix_t;

   typedef struct packed {
      bus2_t  c; //[9:8] - control[1:0]
      bus8_t  d; //[7:0] - data[7:0]
   } tdms_t;
   
   typedef tdms_t[2:0] tdms_pix_t;

endpackage: hdmi_pkg
`endif //__HDMI_PKG__

/*
------------------------------------------------------------------------------
Version History:
------------------------------------------------------------------------------
 2024/1/4  Isam Vrce: Initial creation 
 2024/1/8  Armin Zunic: Timing improvements  
 2024/1/10 Isam Vrce: More timing tuning
 2024/1/16 Armin Zunic: Adding ifdef parts
 */
