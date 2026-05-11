module amplifier(
  input signed [15:0] raw_audio_16bit,
  output logic signed [15:0] amplified_audio_16bit
);

always @(*) begin
  // 32767 / 4 = 8191 //
  if (raw_audio_16bit > 16'sd8191) begin // clamp //
    amplified_audio_16bit = 16'sd32767;
  end 
  else if (raw_audio_16bit < -16'sd8192) begin // clamp //
    amplified_audio_16bit = -16'sd32768;
  end 
  else begin
    // amplify (multiply) by four //
    amplified_audio_16bit = raw_audio_16bit <<< 2; 
  end
end

endmodule