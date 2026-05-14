module send_data_fsm(
  input clk,
  input reset,
  input start_transmitting,
  output logic finished_transmitting,
  input [7:0] data_in,
  output logic [7:0] data_out,
  input nxt,
  output logic stp,
  input afifo_empty,            // Empty flag from actual AFIFO
  input send_zlp,
  output logic sending_crc,
  output logic afifo_read       // Read flag sent to actual AFIFO
);

// FSM parameters //
localparam SEND_IDLE        = 3'b000;
localparam SEND_DATA_ACTIVE = 3'b001;
localparam SEND_CRCLOW      = 3'b011;
localparam SEND_CRCHIGH     = 3'b100;
localparam SEND_END         = 3'b101; 

logic [2:0] current_state, next_state;
logic [15:0] current_crc;
logic [15:0] crc_seed;
logic [15:0] next_crc_val;

logic [7:0] data_out_reg;
logic       stp_reg;

assign data_out = data_out_reg;
assign stp = stp_reg;


// crc calculation //
function automatic [15:0] next_crc_usb(input [7:0] d, input [15:0] c);
  logic [15:0] temp_c;
  integer i;
  begin
    temp_c = c;
    for (i = 0; i < 8; i = i + 1) begin
      if (temp_c[0] ^ d[i])
        temp_c = (temp_c >> 1) ^ 16'hA001; 
      else
        temp_c = temp_c >> 1;
    end
    next_crc_usb = temp_c;
  end
endfunction

// crc is FFFF on the first iteration by default //
assign crc_seed = (current_state == SEND_IDLE) ? 16'hFFFF : current_crc;
assign next_crc_val = next_crc_usb(data_in, crc_seed);

always @(posedge clk) begin
  if (!reset) current_state <= SEND_IDLE;
  else current_state <= next_state;
end

// here change only next state and some flags, not the actual data //
always @(*) begin
  next_state = current_state;
  afifo_read = 1'b0;
  finished_transmitting = 1'b0;
  sending_crc = 1'b0;

  case(current_state)
    SEND_IDLE: begin
      if (start_transmitting && !afifo_empty) begin
        if (nxt) begin
          if (send_zlp) begin
            next_state = SEND_CRCLOW;
            sending_crc = 1'b1;
          end else begin
            next_state = SEND_DATA_ACTIVE;
            afifo_read = 1'b1;
          end
        end
      end
    end

    SEND_DATA_ACTIVE: begin
      if (nxt) begin
        if (afifo_empty) begin
          next_state = SEND_CRCLOW;
          sending_crc = 1'b1;
        end else begin
          afifo_read = 1'b1;
        end
      end
    end

    SEND_CRCLOW: begin
      sending_crc = 1'b1;
      if (nxt) begin
        next_state = SEND_CRCHIGH;
      end
    end

    SEND_CRCHIGH: begin
      if (nxt) begin
        next_state = SEND_END;
      end   
    end

    SEND_END: begin
      finished_transmitting = 1'b1;
      next_state = SEND_IDLE;
    end
  endcase
end

// we need a separate FSM for data_out to fix the really long combinational path //
// which caused timing violations //
// also for the crc which needs to be aligned perfectly with data_out //
always_ff @(posedge clk) begin
  if (!reset) begin
    data_out_reg <= 8'b0;
    stp_reg      <= 1'b0;
    current_crc  <= 16'hFFFF;
  end 
  else begin
    stp_reg <= 1'b0;

    case(current_state)
    
      SEND_IDLE: begin
        if (start_transmitting && !afifo_empty) begin
          if (nxt) begin
            if (send_zlp) begin
              data_out_reg <= ~current_crc[7:0]; 
            end else begin
              data_out_reg <= data_in;
              current_crc  <= next_crc_val;
            end
          end else begin
             data_out_reg <= {2'b01, 2'b00, 4'b0011}; // always PID DATA0
          end
        end else begin
          data_out_reg <= 8'b0;
        end
      end

      SEND_DATA_ACTIVE: begin
        if (nxt) begin
          if (afifo_empty) begin
            data_out_reg <= ~current_crc[7:0]; 
          end else begin
            data_out_reg <= data_in;
            current_crc  <= next_crc_val;
          end
        end
      end

      SEND_CRCLOW: begin
        if (nxt) begin
          data_out_reg <= ~current_crc[15:8];
        end
      end

      SEND_CRCHIGH: begin
        if (nxt) begin
          stp_reg <= 1'b1;      
          data_out_reg <= 8'b0; 
        end
      end 

      SEND_END: begin
        data_out_reg <= 8'b0;
        current_crc  <= 16'hFFFF; // reset the CRC every time a packet is completed //
      end
    endcase
  end
end

endmodule