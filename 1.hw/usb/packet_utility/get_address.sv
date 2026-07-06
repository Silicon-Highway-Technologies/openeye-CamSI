module get_address(
  input clk,
  input rst,
  input new_byte,
  input active,
  input [7:0] data_in,
  output logic [6:0] address
);


// counter that starts when DATA == DATA0 PID  //
// and counts each cycle afterwards (DIR == 1) //

logic [3:0] bytecounter;

always @(posedge clk) begin

  if (!rst) bytecounter <= 4'b0;

  else if (active && new_byte) bytecounter <= bytecounter + 1'b1;

end

// now get address when counter reaches 3 //

always @ (posedge clk) begin

  if (!rst) begin
    address <= 7'b0;
  end

  else if (new_byte) begin

    if (bytecounter == 4'd3) address <= data_in;

  end 

end

endmodule