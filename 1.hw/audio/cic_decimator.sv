module cic_decimator (
  input clk,
  input rst,
  input pdm_pulse,
  input [23:0] din,
  output logic [23:0] dout,
  output logic pcm_pulse // 48khZ //
);

logic [5:0] counter;
logic counter_reset;

// 50-cycle counter //

assign counter_reset = (counter == 6'd49) && (pdm_pulse);

always @(posedge clk) begin

  if (!rst || counter_reset) counter <= 6'd0;
  else if (pdm_pulse) counter <= counter + 1'b1;

end

// 48kHz pulse is generated //
// and data is forwarded based on this pulse //

always @(posedge clk) begin
  if (!rst) begin
    pcm_pulse <= 1'b0;
    dout      <= 24'b0;
  end 
  else begin
    pcm_pulse <= 1'b0;
    
    if (pdm_pulse && counter_reset) begin
      dout      <= din; 
      pcm_pulse <= 1'b1; // 48khZ //
    end
  end

end

endmodule