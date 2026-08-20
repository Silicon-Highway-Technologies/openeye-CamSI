module count_video_packet_bytes (
  input phyclk,
  input rst,
  input DIR,
  input NXT,
  input STP,
  input [7:0] DATA
);

// ========================================================================
  // 1. TOKEN DETECTION (Shift Register)
  // ========================================================================
  logic [23:0] token_history;
  
  always_ff @(posedge phyclk) begin
    if (!rst) begin
      token_history <= 24'd0;
    end
    
    // THE FIX: Clear the history the moment the bus turns around!
    // This forces 'token_detected' to drop to 0, unblocking the state machine.
    else if (!DIR) begin
      token_history <= 24'd0;
    end
    
    // ONLY shift when Host is transmitting data and PHY accepts it
    else if (DIR && NXT) begin 
      token_history <= {token_history[15:0], DATA};
    end
  end

  logic token_detected;
  assign token_detected = (token_history == 24'h69_87_18);


// ========================================================================
  // 2. THE PACKET MEASUREMENT COUNTER
  // ========================================================================
  logic armed;
  logic measuring;
  logic [15:0] nxt_count;
  logic [7:0]  captured_pid;

  always_ff @(posedge phyclk) begin
    if (!rst) begin
      armed <= 1'b0;
      measuring <= 1'b0;
      nxt_count <= 16'd0;
      captured_pid <= 8'd0;
    end else begin
      
      // 1. ARMING CONDITION
      if (token_detected) begin
        armed <= 1'b1;
      end
      
      // 2. START CONDITION (AND SAFE DISARM)
      // If we are armed, and the FPGA sends its FIRST byte (the PID)
      else if (armed && !DIR && NXT) begin
        
        armed <= 1'b0; // ALWAYS disarm instantly so we don't scan the payload!
        
        // ONLY start measuring if the PID is exactly 47 or 4B
        if (DATA == 8'h47 || DATA == 8'h4B) begin
          measuring <= 1'b1;
          nxt_count <= 16'd0;
          captured_pid <= DATA;
        end
      end
      
      // 3. STOP CONDITION
      else if (measuring && STP) begin
        measuring <= 1'b0;
      end
      
      // 4. COUNTING CONDITION
      else if (measuring && !DIR && NXT) begin
        nxt_count <= nxt_count + 1'b1;
      end
      
    end
  end


  // ========================================================================
  // 3. THE SVA EVALUATION (The Final Check)
  // ========================================================================
  
  // This rule triggers on the exact clock cycle STP goes high while measuring.
  property prop_check_packet_length;
    @(posedge phyclk) disable iff (!rst)
    (measuring && STP) |-> (nxt_count == 16'd1026);
  endproperty

  // The final assertion
  assert_packet_length: assert property (prop_check_packet_length)
    else $fatal(1, "[%0t] SVA FATAL: Video packet (PID %h) length violation! Counted %0d NXT pulses before STP. Expected exactly 1026.", $time, captured_pid, nxt_count);

endmodule