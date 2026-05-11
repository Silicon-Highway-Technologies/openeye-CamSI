module audio_to_8bit(
  input clk_24MHz,
  input rst,
  input pcm_pulse,
  input [15:0] din,

  output logic [7:0] dout,
  output logic afifo_write_en
);

logic state;
logic [15:0] saved_audio;

always @(posedge clk_24MHz) begin
  if (!rst) begin
    state <= 1'b0;
    afifo_write_en <= 1'b0;
    dout <= 8'd0;
  end 
  else begin

    afifo_write_en <= 1'b0;
    
    case (state)
      1'b0: begin
        if (pcm_pulse) begin
          saved_audio <= din; // save 16bit audio //
          dout <= din[7:0]; // send LSB first //
          afifo_write_en <= 1'b1; // write to afifo //
          state <= 1'b1; // immediately send the next 8bits as well //
        end
      end
      
      1'b1: begin
        dout <= saved_audio[15:8]; // send MSB second //
        afifo_write_en <= 1'b1; // write to afifo //
        state <= 1'b0; // wait for a new pulse //
      end
    endcase
  end
end

endmodule