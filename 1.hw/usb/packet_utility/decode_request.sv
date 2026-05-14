
module decode_request(
  input clk,
  input rst,
  input reset_request,
  input active,
  input new_byte,
  input [7:0] data_in,
  output logic [6:0] address,
  output logic [4:0] request
);

`include "request_parameters.vh"

logic [3:0] bytecounter;
logic [7:0] bmRequestType;
logic [7:0] bRequest;
logic [15:0] wValue; 
logic [15:0] windex;
logic [15:0] wLength;

logic [4:0] decoded_request;

always @(posedge clk) begin

  if (!rst || !active) bytecounter <= 4'b0;

  else if (active && new_byte) bytecounter <= bytecounter + 1'b1;

end

always @(posedge clk) begin

  if (!rst || reset_request) request <= NO_REQUEST;

  else request <= decoded_request;

end

always @(posedge clk) begin

  if (!rst || reset_request) begin
    bmRequestType <= 8'b0;
    bRequest <= 8'b0;

    wValue <= 16'b0;
    windex <= 16'b0;
    wLength <= 16'b0;
  end

  else if (new_byte) begin

    // ignore when counter = 1 because this is CRC //
    if (bytecounter == 4'd1) bmRequestType <= data_in;
    else if (bytecounter == 4'd2) bRequest <= data_in;
    else if (bytecounter == 4'd3) wValue[7:0] <= data_in;
    else if (bytecounter == 4'd4) wValue[15:8] <= data_in;  
    else if (bytecounter == 4'd5) windex[7:0] <= data_in;
    else if (bytecounter == 4'd6) windex[15:8] <= data_in;   
    else if (bytecounter == 4'd7) wLength[7:0] <= data_in;
    else if (bytecounter == 4'd8) wLength[15:8] <= data_in;  

  end 
        
end

always @(*) begin

  if ((bmRequestType == 8'h80) && (bRequest == 8'h06) && (wValue == 16'h0100)) decoded_request = GET_DEVICE_DESCRIPTOR;
  else if ((bmRequestType == 8'h00) && (bRequest == 8'h05)) decoded_request = SET_ADDRESS;
  else if ((bmRequestType == 8'h80) && (bRequest == 8'h06) && (wValue == 16'h0200) && (wLength == 16'h0009)) decoded_request = GET_CONFIG_DESCRIPTOR_9BYTES;
  else if ((bmRequestType == 8'h80) && (bRequest == 8'h06) && (wValue == 16'h0200) && (wLength == 16'h00FF)) decoded_request = GET_CONFIG_DESCRIPTOR_255BYTES;
  else if ((bmRequestType == 8'h80) && (bRequest == 8'h06) && (wValue == 16'h0200)) decoded_request = GET_CONFIG_DESCRIPTOR_FULL;
  else if ((bRequest == 8'h09)) decoded_request = SET_CONFIGURATION;
  else if ((bRequest == 8'h0B)) decoded_request = SET_INTERFACE;
  else if ((bmRequestType == 8'hA1) && (bRequest == 8'h81) && (wLength == 16'h001A)) decoded_request = GET_CUR_VIDEO_PROBE;
  else if ((bmRequestType == 8'hA1) && (bRequest == 8'h81) && (wLength == 16'h0001)) decoded_request = GET_CUR_AUDIO_MUTE;
  else if ((bmRequestType == 8'hA1) && (bRequest == 8'h81) && (wLength == 16'h0002)) decoded_request = GET_CUR_AUDIO_VOL;
  else if ((bmRequestType == 8'hA1) && (bRequest == 8'h82) && (wLength == 16'h001A)) decoded_request = GET_MIN_VIDEO_PROBE;
  else if ((bmRequestType == 8'hA1) && (bRequest == 8'h82) && (wLength == 16'h0002)) decoded_request = GET_MIN_AUDIO_VOL;  
  else if ((bmRequestType == 8'hA1) && (bRequest == 8'h83) && (wLength == 16'h001A)) decoded_request = GET_MAX_VIDEO_PROBE;
  else if ((bmRequestType == 8'hA1) && (bRequest == 8'h83) && (wLength == 16'h0002)) decoded_request = GET_MAX_AUDIO_VOL;
  else if ((bmRequestType == 8'hA1) && (bRequest == 8'h84)) decoded_request = GET_RES;
  else if ((bmRequestType == 8'h21) && (bRequest == 8'h01)) decoded_request = SET_CUR;
  else decoded_request = UNKNOWN_REQUEST;


end

// also get the address from SET_ADDRESS in this module //
always @(posedge clk) begin

    if (!rst) address <= 7'b0;

    else if (decoded_request == SET_ADDRESS) address <= wValue[6:0];

end


endmodule