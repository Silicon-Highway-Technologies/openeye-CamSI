module uvc_jpeg_reader (
    input clk,
    input rst,
    input active,
    input fetch_next,
    input sending_crc,
    input send_new_frame,
    input fid_bit,        // The Frame ID bit from your 60fps timer
    
    output logic finished,       // Goes high to tell send_data_fsm to send CRC
    output logic  [7:0]  data_out,       // The payload byte
    output logic frame_complete  // Pulses high when the WHOLE image is done
);

// this module reads the JPEG image from a frame and sends it in packets of 1024 bytes //
localparam [15:0] JPEG_BYTES = 16'd25380; // headers excluded //
localparam [9:0] JPEG_HEADER_LEN = 10'd623;
localparam [1:0] JPEG_FOOTER_LEN = 2'd2;
localparam [15:0] TOTAL_FRAME_BYTES = JPEG_HEADER_LEN + JPEG_BYTES + JPEG_FOOTER_LEN;

logic [7:0] jpeg_data [0:JPEG_BYTES - 1]; 
logic [7:0] jpeg_header [0:JPEG_HEADER_LEN - 1];
logic [7:0] jpeg_footer [0:JPEG_FOOTER_LEN - 1];

localparam READ_HEADER = 3'b000;
localparam READ_DATA = 3'b001;
localparam READ_FOOTER = 3'b010;
localparam FRAME_SENT = 3'b011;
localparam IDLE = 3'b100;
localparam WAIT_EOF_PACKET = 3'b101;

logic [2:0] current_state, next_state;

initial begin
    $readmemh("seagulls.mem", jpeg_data); 
    $readmemh("headers_720p_qf10.mem", jpeg_header);
    $readmemh("footers.mem", jpeg_footer);

end

logic [15:0] data_ptr;
logic [1:0] footer_ptr;
logic [9:0] header_ptr;

logic [7:0] data_from_mem;

logic [15:0] global_ptr;
logic [10:0]  packet_byte_cnt;
logic is_eof;
logic [7:0] uvc_bitfield;

logic frame_complete_singlecycle;

logic next_byte;
assign next_byte = active && fetch_next && (packet_byte_cnt >= 11'd2);

// is_eof will now be assigned in a separate packet //
assign is_eof = (current_state == WAIT_EOF_PACKET);

assign uvc_bitfield = {1'b1, 5'b00000, is_eof, fid_bit};

always @(posedge clk) begin
  if (!rst || !active) begin
    packet_byte_cnt <= 11'd0;
  end else if (active && fetch_next && !sending_crc) begin
    packet_byte_cnt <= packet_byte_cnt + 1'b1;
  end

end

always @(posedge clk) begin

  if (!rst || (frame_complete)) begin
    header_ptr <= 10'b0;
    data_ptr <= 16'b0;
    footer_ptr <= 2'b00;
  end
  else if (next_byte) begin

    // increment counters only if at the corresponding state //
    header_ptr <= header_ptr + (current_state == READ_HEADER);
    data_ptr <= data_ptr + (current_state == READ_DATA);
    footer_ptr <= footer_ptr + (current_state == READ_FOOTER);
  end

end

// Global Pointer Counter
always @(posedge clk) begin
  if (!rst || (global_ptr >= TOTAL_FRAME_BYTES)) begin
    global_ptr <= 17'd0;
  end
  else if (active && fetch_next && (packet_byte_cnt >= 11'd2)) begin
    global_ptr <= global_ptr + 1'b1;
  end
end

// multiplexer for data out, which can be a UVC header or JPEG data //
always @(*) begin
    
  if (packet_byte_cnt == 11'd0) begin
      data_out = 8'h02;           // Byte 0: UVC Header Length
  end else if (packet_byte_cnt == 11'd1) begin
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

  case (current_state)

  READ_HEADER: begin

    data_from_mem = jpeg_header[header_ptr];

    if (header_ptr == JPEG_HEADER_LEN - 1'b1) begin
      next_state = READ_DATA;
    end   

  end

  READ_DATA: begin

    data_from_mem = jpeg_data[data_ptr];

    if (data_ptr == JPEG_BYTES - 1'b1) begin
      next_state = READ_FOOTER;
    end    

  end

  READ_FOOTER: begin

    data_from_mem = jpeg_footer[footer_ptr];

    if (footer_ptr == JPEG_FOOTER_LEN - 1'b1) begin
      next_state = WAIT_EOF_PACKET;
      
    end

  end

  WAIT_EOF_PACKET: begin
    // We are now waiting for the NEXT packet to start. 
    // When the host asks for it, packet_byte_cnt will count 0, 1, 2.
    // The 'finished' flag above will automatically terminate it at byte 2!
    // We just need to transition to FRAME_SENT once those 2 bytes are actively sent.
    if (packet_byte_cnt == 11'd2 && active) begin
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


endmodule