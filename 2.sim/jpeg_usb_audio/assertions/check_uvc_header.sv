module check_uvc_header (
  input phyclk,
  input rst,
  input DIR,
  input NXT,
  input [7:0] DATA
);

// does not work at the moment //

  // ========================================================================
  // 1. SEQUENCE DEFINITIONS
  // ========================================================================
  
  // The Video IN Token
  sequence seq_video_in_token;
    (DATA == 8'h69) ##1 
    (DATA == 8'h87) ##1 
    (DATA == 8'h18);
  endsequence

  // Trigger: The exact cycle the PHY accepts ANY valid Video PID (47, 4B, or 43)
  sequence seq_any_video_pid_accepted;
    seq_video_in_token ##1 first_match(##[1:30] (DIR == 1'b0 && NXT == 1'b1 && 
                                                (DATA == 8'h47 || DATA == 8'h4B || DATA == 8'h43)));
  endsequence


  // ========================================================================
  // 2. PROPERTY DEFINITION
  // ========================================================================

  property prop_uvc_header_format;
    @(posedge phyclk) disable iff (!rst)
    
    // IF a valid video PID was just accepted...
    seq_any_video_pid_accepted 
    
    |=> // Advance to the very next clock cycle, then start scanning:

    // 1. Find the VERY NEXT cycle where NXT is 1. On that exact cycle (##0), DATA must be 0x02
    (first_match(##[1:30] (!DIR && NXT)) ##0 (DATA == 8'h01))
    
    ##1 // Advance to the next clock cycle, then scan again:
    
    // 2. Find the NEXT cycle where NXT is 1. On that exact cycle (##0), DATA must be the UVC bitfield
    (first_match(##[1:30] (!DIR && NXT)) ##0 (DATA == 8'h80 || DATA == 8'h81 || DATA == 8'h82 || DATA == 8'h83));
    
  endproperty


  // ========================================================================
  // 3. ASSERTION INSTANTIATION
  // ========================================================================

  assert_uvc_header_correct: assert property (prop_uvc_header_format)
    else $fatal(1, "[%0t] SVA FATAL: UVC Header Violation! The first two payload bytes were not 0x02 and a valid bitfield (80, 81, 82, 83).", $time);


endmodule