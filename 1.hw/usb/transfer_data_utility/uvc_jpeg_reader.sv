module uvc_jpeg_reader (
  input clk,
  input rst,
  input nxt,
  input send_data_fsm_active,
  input fetch_next,
  input sending_crc,
  input send_new_frame,
  input send_UVC_header,

  input [7:0] jpeg_data_in,
  input jpeg_afifo_finished,
  input frame_transmitted,

  input audio_mode,
  input zlp_mode,  

  input [23:0] bytes_in_fifo,

  output logic sending_footer,

  output logic jpeg_send_data,

  output logic [4:0] debug_uvc_reader,

  output logic finished,       // Goes high to tell send_data_fsm to send CRC
  output logic  [7:0]  data_out,       // The payload byte
  output logic frame_complete  // Pulses high when the WHOLE image is done
);

`include "settings.vh"

localparam [9:0] JPEG_HEADER_LEN = 10'd623;
localparam [1:0] JPEG_FOOTER_LEN = 2'd2;

logic [7:0] jpeg_header [0:JPEG_HEADER_LEN - 1];
logic [7:0] jpeg_footer [0:JPEG_FOOTER_LEN - 1];

localparam READ_HEADER = 3'b000;
localparam READ_DATA = 3'b001;
localparam READ_FOOTER = 3'b010;
localparam FRAME_SENT = 3'b011;
localparam IDLE = 3'b100;
localparam WAIT_EOF_PACKET = 3'b101;

logic active;
logic header_incr, footer_incr;

assign active = (send_data_fsm_active && !audio_mode && !zlp_mode);

assign sending_footer = footer_incr;

logic [2:0] current_state, next_state;

initial begin

`ifdef RES_720P60
  `ifdef QF10
    $readmemh("../mem/headers_720p_qf10.mem", jpeg_header);
  `elsif QF25
    $readmemh("../mem/headers_720p_qf25.mem", jpeg_header);  
  `elsif QF50
    $readmemh("../mem/headers_720p_qf50.mem", jpeg_header);  
  `elsif QF100 
    $readmemh("../mem/headers_720p_qf100.mem", jpeg_header);          
  `endif
`elsif RES_1080P30
  `ifdef QF10
    $readmemh("../mem/headers_1080p_qf10.mem", jpeg_header);
  `elsif QF25
    $readmemh("../mem/headers_1080p_qf25.mem", jpeg_header);  
  `elsif QF50
    $readmemh("../mem/headers_1080p_qf50.mem", jpeg_header);  
  `elsif QF100 
    $readmemh("../mem/headers_1080p_qf100.mem", jpeg_header);          
  `endif
`endif

  $readmemh("../mem/footers.mem", jpeg_footer);

end

logic [1:0] footer_ptr;
logic [9:0] header_ptr;

logic [7:0] data_from_mem;

logic [15:0] global_ptr;
logic [10:0]  packet_byte_cnt;
logic is_eof;
logic [7:0] uvc_bitfield;

logic frame_complete_singlecycle;
logic fid_bit;
logic next_byte;
assign next_byte = nxt && active && (fetch_next || !jpeg_send_data) && (!send_UVC_header || packet_byte_cnt >= 11'd2);

assign is_eof = (bytes_in_fifo + JPEG_FOOTER_LEN <= 24'd3070) && (frame_transmitted);

assign uvc_bitfield = {1'b1, 5'b00000, is_eof, fid_bit};

always @(posedge clk) begin
  if (!rst || !active) begin
    packet_byte_cnt <= 11'd0;
  end
  else if (nxt && active && (fetch_next || !jpeg_send_data) && !sending_crc) begin
    packet_byte_cnt <= packet_byte_cnt + 1'b1;
  end

end

always @(posedge clk) begin

  if (!rst) fid_bit <= 1'b0;
  else if (frame_complete_singlecycle) fid_bit <= ~fid_bit;

end

always @(posedge clk) begin

  if (!rst || (frame_complete)) begin
    header_ptr <= 10'b0;
    footer_ptr <= 2'b00;
  end
  else if (next_byte) begin

    // increment counters only if at the corresponding state //
    header_ptr <= header_ptr + header_incr;
    footer_ptr <= footer_ptr + footer_incr;
  end

end

// multiplexer for data out, which can be a UVC header or JPEG data //
always @(*) begin
  
  if (send_UVC_header && packet_byte_cnt == 11'd0) begin
      data_out = 8'h02;           // Byte 0: UVC Header Length
  end else if (send_UVC_header && packet_byte_cnt == 11'd1) begin
      data_out = uvc_bitfield;    // Byte 1: UVC Bitfield (EOF, FID)
  end else begin
      data_out = data_from_mem; // Bytes 2-1023: JPEG Data
  end

end

// 1. Finish if we hit 1024 bytes (normal behavior)
// 2. Finish immediately if we enter the WAIT state and we are past byte 2 (this chops the payload packet early!)
// 3. Finish immediately if we are in the WAIT state and we just sent the 2nd byte of the NEW packet!
assign finished = ((packet_byte_cnt >= 11'd1024) || 
                   (current_state == WAIT_EOF_PACKET && packet_byte_cnt >= 11'd2) || 
                   (frame_complete_singlecycle));

// create an FSM to read header, data, footer in order //
always @(posedge clk) begin

  if (!rst) current_state <= READ_HEADER;
  else current_state <= next_state;

end

always @(*) begin

  next_state = current_state;
  data_from_mem = 8'b0;
  frame_complete = 1'b0;
  frame_complete_singlecycle = 1'b0;
  jpeg_send_data = 1'b0;
  header_incr = 1'b0;
  footer_incr = 1'b0;

  case (current_state)

  READ_HEADER: begin

    data_from_mem = jpeg_header[header_ptr];
    header_incr = 1'b1;

    if ((header_ptr == JPEG_HEADER_LEN - 1'b1) && (nxt)) begin
      next_state = READ_DATA;
    end   

  end

  READ_DATA: begin

    data_from_mem = jpeg_data_in;

    // we must NOT send JPEG data here only during the first two bytes the first packet (of multiple)
    jpeg_send_data = (packet_byte_cnt < 2'd2 && send_UVC_header) ? 1'b0 : 1'b1;

    if (jpeg_afifo_finished) begin      
      next_state = READ_FOOTER;
      jpeg_send_data = 1'b0;
      data_from_mem = jpeg_footer[footer_ptr];
      footer_incr = 1'b1;
    end     

  end

  READ_FOOTER: begin

    data_from_mem = jpeg_footer[footer_ptr];
    footer_incr = 1'b1;

    if ((footer_ptr == JPEG_FOOTER_LEN - 1'b1) && (nxt)) begin
      next_state = FRAME_SENT;
      frame_complete = 1'b1;
    end

  end

  FRAME_SENT: begin
    frame_complete_singlecycle = 1'b1;
    frame_complete = 1'b1;
    next_state = IDLE;
  end

  IDLE: begin
    frame_complete = 1'b1;
    if (send_new_frame) next_state = READ_HEADER;
  end


  endcase

end

assign debug_uvc_reader = {fid_bit, is_eof, current_state};


endmodule