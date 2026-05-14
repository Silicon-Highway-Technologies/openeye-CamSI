module debug_request(
    input clk,
    input rst,
    input new_byte,
    input active,
    input [7:0] data_in,
    output logic [7:0] bmRequestType,
    output logic [7:0] bRequest,
    output logic [15:0] wValue, 
    output logic [15:0] windex, 
    output logic [15:0] wLength
);


// counter that starts when DATA == DATA0 PID  //
// and counts each cycle afterwards (DIR == 1) //

logic [3:0] bytecounter;

always @(posedge clk) begin

    if (!rst) bytecounter <= 4'b0;

    else if (active && new_byte) bytecounter <= bytecounter + 1'b1;

end

// now assign each byte to the correct field //

always @ (posedge clk) begin

  if (!rst) begin
    bmRequestType <= 8'b0;
    bRequest <= 8'b0;

    wValue <= 16'b0;
    windex <= 16'b0;
    wLength <= 1'b0;
  end

  else if (new_byte) begin

    // ignore when counter = 1 because this is CRC //
    if (bytecounter == 4'd1) bmRequestType <= data_in;
    else if (bytecounter == 4'd2) bRequest <= data_in;
    else if (bytecounter == 4'd3) wValue[15:8] <= data_in;
    else if (bytecounter == 4'd4) wValue[7:0] <= data_in;  
    else if (bytecounter == 4'd5) windex[15:8] <= data_in;
    else if (bytecounter == 4'd6) windex[7:0] <= data_in;   
    else if (bytecounter == 4'd7) wLength[15:8] <= data_in;
    else if (bytecounter == 4'd8) wLength[7:0] <= data_in;  

  end 
        

end


endmodule