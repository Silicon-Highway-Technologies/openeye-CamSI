module phase_incr(

  input clk,
  input rst,
  input new_phase_flag,
  output logic [4:0] current_phase
);

// this module increases the current phase when a flag is activated //

always @(posedge clk) begin

  if (!rst) current_phase <= 5'b0;

  else if (new_phase_flag) current_phase <= current_phase + 1'b1;

end

endmodule