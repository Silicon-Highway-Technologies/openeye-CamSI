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
// Description: N/A
//========================================================================

package soc_pkg;

//-----------------------------------------
// parameters that can be customized to your SOC
//-----------------------------------------
   localparam SOC_ADDRW = 32;
   localparam SOC_DATAW = 32;

//-----------------------------------------
// derived values. Don't touch anything in this section
//-----------------------------------------
`ifdef USE_OWN_CLOG2
   function int clog2 (
      input int value
   );
      int temp;
      temp = value - 1;
 
      for (clog2 = 0; temp > 0; clog2++) begin
         temp = temp >> 1;
      end
   endfunction: clog2
`endif

   
//- - - - - - - - - - - - - - - - - - - - -
   localparam SOC_BYTES = SOC_DATAW / 8;     // 4 for 32-bit data bus
   localparam SOC_ADDRL = $clog2(SOC_BYTES); // 2 for 32-bit data bus
   
   typedef logic [SOC_ADDRW-1:SOC_ADDRL] soc_addr_t; // address is in the full data words
   typedef logic [SOC_BYTES-1:0]         soc_we_t;   // per-byte Write Enables. They serve as decoded addr LSBs
   typedef logic [SOC_DATAW-1:0]         soc_data_t; // Write Data

   typedef enum logic {LO = 1'b0, HI = 1'b1} soc_boolean_t;

   typedef struct packed {
      logic p; // [1]
      logic n; // [0]
   } diff_t; // differential data type

//   //instruction opcode with corresponding decode
//   typedef enum logic [6:0] {
//      ALUREG = 7'b0110011,    //-\ ALU Data
//      ALUIMM = 7'b0010011,    //-/ instructions 
//                               
//      BRNCH  = 7'b1100011,    //-\ 
//      JALR   = 7'b1100111,    // | Code flow 
//      JAL    = 7'b1101111,    // | instructions
//      AUIPC  = 7'b0010111,    //-/ 
//                               
//      LUI    = 7'b0110111,    //-\ Load/Store 
//      LOAD   = 7'b0000011,    // | instructions
//      STORE  = 7'b0100011,    //-/ 
//                               
//      SYSTEM = 7'b1110011     //- special
//   } opcode_t;

//   typedef struct packed {
//      logic         imm20;    // [31]
//      logic [10:1]  imm10_1;  // [30:21]
//      logic         imm11;    // [20]
//      logic [19:12] imm19_12; // [19:12]
//      logic [4:0]   rd;       // [11:7]
//   } grp_jump_t;
// 
//   //union declaration for variable parts of instruction, [31:7]
//   typedef union packed {
//      grp_reg2reg_t reg2reg;  //[31:7]-InstrGroup#1
//      grp_imm_t     imm;      //[31:7]-InstrGroup#2
//      grp_uimm_t    uimm;     //[31:7]-InstrGroup#3
//      grp_store_t   store;    //[31:7]-InstrGroup#4
//      grp_brnch_t   brnch;    //[31:7]-InstrGroup#5
//      grp_jump_t    jump;     //[31:7]-InstrGroup#6
//   } grp_t;
   
endpackage: soc_pkg

/*
-----------------------------------------------------------------------------
Version History:
-----------------------------------------------------------------------------
 2024/01/15 AZ: initial creation    

*/
