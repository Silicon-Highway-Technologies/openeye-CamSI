module audio_packet_counter(
  input clk,
  input rst,
  input audio_afifo_read,
  input finished_transmitting,
  output logic audio_packet_done
);

// in theory this counter is necessary but in reality we do not send so many audio bytes //

logic [7:0] audio_byte_cnt;

always @(posedge clk) begin

    if (!rst || finished_transmitting) begin // reset if a packet has been transmitted //
        audio_byte_cnt <= 8'd0;
    end 

    else if (audio_afifo_read) begin // increment if we are currently transmitting audio data //
        audio_byte_cnt <= audio_byte_cnt + 8'd1;
    end
end

assign audio_packet_done = (audio_byte_cnt == 8'd96);



endmodule