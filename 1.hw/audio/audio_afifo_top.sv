module audio_afifo_top(
  input phyclk,
  input rst,
  input clk_24MHz,
  input afifo_write_en,
  input afifo_read,
  input [7:0] audio_8bit,
  output logic [7:0] data_to_send,
  output logic afifo_empty
);

// theoretically the audio does not need to be so large for audio //
logic [11:0] wptr, rptr;
logic afifo_full;

afifo #(
  .DSIZE(8),       // Data width
  .ASIZE(11)        // Address size
) u_afifo (
  .i_wclk(clk_24MHz),
  .i_wrst_n(rst),
  .i_wr(afifo_write_en),
  .i_wdata(audio_8bit),
  .o_wfull(afifo_full),
  .i_rclk(phyclk),
  .i_rrst_n(rst),
  .i_rd(afifo_read),
  .o_rdata(data_to_send),
  .o_rempty(afifo_empty),
  .wptr(wptr),
  .rptr(rptr)
);

endmodule