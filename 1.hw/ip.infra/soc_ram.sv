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
// Designers  : Armin Zunic, Isam Vrce
// Description: 
//   Syncronous RAM that's Plug-and-Play compatible with our SOC infrastructure
//==========================================================================

module soc_ram #(
   parameter NUM_WORDS = 1024 // RAM depth in SOC bus words, typically 32-bit
)(
   soc_if.SLV bus
);

   import soc_pkg::*;

   localparam ADDR_MSB = $clog2(NUM_WORDS) + 1;

//------------------------------------------------------------
// combo decode logic
//------------------------------------------------------------
   logic [ADDR_MSB:SOC_ADDRL] addr;
   soc_we_t                   we;
   
   always_comb begin
      addr = bus.addr[ADDR_MSB:SOC_ADDRL];
      we   = bus.vld ? bus.we : '0; // write only when accessed
   end   

//------------------------------------------------------------
// storage element
//------------------------------------------------------------
  (* ram_style = "block" *) soc_data_t mem [NUM_WORDS];

   always_ff @(posedge bus.clk) begin
      bus.rdat <= mem[addr];

      for (int i=0; i< SOC_BYTES; i++) begin
         if (we[i] == HI) mem[addr][i*8 +: 8] <= bus.wdat[i*8 +: 8];
      end
   end

//------------------------------------------------------------
// handshake: Data is RDY one cycle after VLD. RDY must
//            not be asserted for more than one cycle  
//------------------------------------------------------------
   always_ff @(negedge bus.arst_n or posedge bus.clk) begin
      if (bus.arst_n == 1'b0) begin
         bus.rdy <= '0;
      end   
      else begin
         bus.rdy <= bus.vld & ~bus.rdy;
      end
   end

endmodule: soc_ram

/*
-----------------------------------------------------------------------------
Version History:
-----------------------------------------------------------------------------
 2024/01/15 AZ: initial creation    

*/
