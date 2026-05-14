module ignore_sof(
  input clk,
  input rst,
  input [7:0] data,
  input dir,
  output logic ignore
);

logic [1:0] counter;

always @(posedge clk) begin
  if (!rst) begin
    counter <= 2'd0;
    ignore  <= 1'b0;
  end else begin
    // Priority 1: If we are currently counting down, keep ignoring
    if (counter > 0) begin
      counter <= counter - 1'b1;
      ignore  <= 1'b1;
    end
    
    // Priority 2: Detect new SOF (0xA5) only if DIR is High (RX Mode)
    // We only trigger if counter is 0 to avoid re-triggering mid-packet
    else if (dir && (data == 8'hA5)) begin
      counter <= 2'd3; // Load 2 to ignore the NEXT 2 bytes (Frame Num)
      ignore  <= 1'b1; // Assert ignore for THIS byte (PID)
    end
    
    // Priority 3: Otherwise, do not ignore
    else begin
      ignore <= 1'b0;
    end
  end
end

endmodule