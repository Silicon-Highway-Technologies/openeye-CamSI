module check_video_PID (
  input phyclk,
  input rst,
  input DIR,
  input NXT,
  input STP,
  input [7:0] DATA
);

// ========================================================================
  // 1. SEQUENCE DEFINITIONS (FIXED)
  // ========================================================================
  
  // The Video IN Token
  sequence seq_video_in_token;
    (DIR == 1'b1 && DATA == 8'h69) ##1 
    (DIR == 1'b1 && DATA == 8'h87) ##1 
    (DIR == 1'b1 && DATA == 8'h18);
  endsequence

  // Helper: Lock onto the FIRST cycle of the response, then check the PID.
  sequence seq_video_answered_with(logic [7:0] pid);
    seq_video_in_token ##1 
    first_match(##[1:30] (DIR == 1'b0 && NXT == 1'b1)) ##0 (DATA == pid);
  endsequence


  // ========================================================================
  // 2. PROPERTY DEFINITIONS (FIXED)
  // ========================================================================

  property prop_video_valid_pid;
    @(posedge phyclk) disable iff (!rst)
    seq_video_in_token |-> 
      first_match(##[1:30] (DIR == 1'b0 && NXT == 1'b1)) ##0 
        (DATA == 8'h47 || DATA == 8'h4B || DATA == 8'h43);
  endproperty

  property prop_video_data2_to_data1;
    @(posedge phyclk) disable iff (!rst)
    (seq_video_answered_with(8'h47) ##1 first_match(##[1:2000] STP) ##1 first_match(##[1:500] seq_video_in_token))
    |->
    // Use ##0 instead of |-> so we evaluate the exact clock edge the response starts
    first_match(##[1:30] (DIR == 1'b0 && NXT == 1'b1)) ##0 (DATA == 8'h4B);
  endproperty

  property prop_video_data1_to_data0;
    @(posedge phyclk) disable iff (!rst)
    (seq_video_answered_with(8'h4B) ##1 first_match(##[1:2000] STP) ##1 first_match(##[1:500] seq_video_in_token))
    |->
    first_match(##[1:30] (DIR == 1'b0 && NXT == 1'b1)) ##0 (DATA == 8'h43);
  endproperty


  // ========================================================================
  // 3. ASSERTION INSTANTIATIONS
  // ========================================================================

  assert_video_valid_pid: assert property (prop_video_valid_pid)
    else $fatal(1, "[%0t] SVA FATAL: Video EP responded with an illegal PID! Expected 47, 4B, or 43.", $time);

  assert_video_data2_to_data1: assert property (prop_video_data2_to_data1)
    else $fatal(1, "[%0t] SVA FATAL: High-Bandwidth Sequence broken! DATA2 was NOT followed by DATA1.", $time);

 assert_video_data1_to_data0: assert property (prop_video_data1_to_data0)
    else $error("[%0t] SVA ERROR: DATA1 was NOT followed by DATA0. FPGA instead sent PID: 8'h%h", $time, DATA);

// Put this right below your assertions!
cover_video_token_happens: cover property (@(posedge phyclk) disable iff (!rst) seq_video_in_token)
  $display("[%0t] SVA DEBUG: The Video IN Token (69 87 18) perfectly matched!", $time);

// ========================================================================
  // 4. BULLETPROOF SVA TIMELINE TRACKER (DATA1 -> DATA0)
  // ========================================================================
  
  // logic [2:0]  dir_shift;
  // logic [23:0] data_shift;
  // int cycle_wait; // To track how many clocks passed
  
  // always @(posedge phyclk) begin
  //   if (!rst) begin
  //     dir_shift  <= 3'b000;
  //     data_shift <= 24'h000000;
  //   end else begin
  //     dir_shift  <= {dir_shift[1:0], DIR};
  //     data_shift <= {data_shift[15:0], DATA};
  //   end
  // end
  
  // wire in_token_detected = (dir_shift == 3'b111) && (data_shift == 24'h69_87_18);

  // time dbg_t_token1, dbg_t_data1, dbg_t_stp, dbg_t_token2;
  // int  dbg_state = 0; 

  // always @(posedge phyclk) begin
  //   if (!rst) begin
  //     dbg_state <= 0;
  //   end else begin
  //     case (dbg_state)
  //       0: if (in_token_detected) begin
  //            dbg_t_token1 <= $time;
  //            dbg_state <= 1;
  //            $display("[%0t] DBG: Sequence Started. First IN Token seen.", $time);
  //          end
           
  //       1: if (DIR == 1'b0 && NXT == 1'b1) begin
  //            if (DATA == 8'h4B) begin
  //              dbg_t_data1 <= $time;
  //              dbg_state <= 2;
  //              cycle_wait <= 0;
  //              $display("[%0t] DBG: FPGA replied DATA1 (4B). Waiting for STP...", $time);
  //            end else begin
  //              dbg_state <= 0; // Not a DATA1 sequence, ignore.
  //            end
  //          end
           
  //       2: begin
  //            cycle_wait++;
  //            if (STP) begin
  //              dbg_t_stp <= $time;
  //              dbg_state <= 3;
  //              cycle_wait <= 0;
  //              $display("[%0t] DBG: STP seen. Packet closed. Waiting for next IN Token...", $time);
  //            end else if (cycle_wait > 2500) begin
  //              $display("[%0t] DBG ABORT: Waited > 2000 cycles for STP!", $time);
  //              dbg_state <= 0;
  //            end
  //          end
           
  //       3: begin
  //            cycle_wait++;
  //           end
           
  //       4: begin 
  //            cycle_wait++;
  //            if (DIR == 1'b0 && NXT == 1'b1) begin
  //                $display("\n===========================================================");
  //                $display(" SVA DEBUG TRACE: DATA1 -> DATA0 SEQUENCE COMPLETE");
  //                $display("===========================================================");
  //                $display(" [Time: %0t] 1. First IN Token Received", dbg_t_token1);
  //                $display(" [Time: %0t] 2. FPGA responded with DATA1 (4B)", dbg_t_data1);
  //                $display(" [Time: %0t] 3. FPGA ended packet with STP", dbg_t_stp);
  //                $display(" [Time: %0t] 4. Second IN Token Received", dbg_t_token2);
  //                $display(" [Time: %0t] 5. FPGA replied with PID: 8'h%h", $time, DATA);
  //                $display("-----------------------------------------------------------");
  //                if (DATA == 8'h43)
  //                  $display(" >>> SUCCESS: PID is correctly DATA0 (43)!");
  //                else
  //                  $display(" >>> ERROR: SVA failed! Expected DATA0 (43), but got 8'h%h!", DATA);
  //                $display("===========================================================\n");
                 
  //                dbg_state <= 0;
  //            end else if (cycle_wait > 30) begin
  //                $display("\n===========================================================");
  //                $display(" >>> ERROR: SVA failed! FPGA never responded within 30 cycles!");
  //                $display("===========================================================\n");
  //                dbg_state <= 0;
  //            end
  //          end
  //     endcase
  //   end
  // end
  // if (in_token_detected) begin
  //              dbg_t_token2 <= $time;
  //              dbg_state <= 4;
  //              cycle_wait <= 0;
  //              $display("[%0t] DBG: Second IN Token seen! Waiting for FPGA response...", $time);
  //            end else if (cycle_wait > 1000) begin
  //              // Don't abort, just warn. Host might be slow.
  //            end
          
endmodule