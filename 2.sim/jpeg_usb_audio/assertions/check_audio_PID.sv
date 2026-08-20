module check_audio_PID (
  input phyclk,
  input rst,
  input DIR,
  input NXT,
  input [7:0] DATA
);

  // 1. Define the sequence
  sequence seq_audio_in_token;
    (DIR == 1'b1 && DATA == 8'h69) ##1 
    (DIR == 1'b1 && DATA == 8'h07) ##1 
    (DIR == 1'b1 && DATA == 8'h19);
  endsequence

  // 2. Define the property
  property prop_audio_responds_data0;
    @(posedge phyclk) disable iff (!rst) 
    
    seq_audio_in_token |-> 
      first_match(##[1:30] (DIR == 1'b0 && NXT == 1'b1)) |-> 
        (DATA == 8'h43);
  endproperty

  // 3. Instantiate the assertion
  assert_audio_responds_data0: assert property (prop_audio_responds_data0) 
    else $fatal(1, "[%0t] SVA FATAL: Audio PID requirement is not met.", $time);

endmodule