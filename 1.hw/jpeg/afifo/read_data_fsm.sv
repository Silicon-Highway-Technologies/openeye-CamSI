module read_data_fsm (
  input logic clk,
  input logic reset,
  input logic [23:0] write_address, // to somewhat handle rollover //
  input logic write_valid,
  output logic [23:0] read_address,
  output logic read_valid,
  input image_valid_out
);

logic [2:0] current_state, next_state;

// Define state parameters
parameter idle = 3'b000;
parameter raise_read_valid = 3'b001;
parameter address_incr = 3'b011;
parameter incr_cornercase = 3'b100;
parameter raise_read_valid_cornercase = 3'b101;
parameter address_incr_cornercase = 3'b110;

// Sequential logic for state transitions
always @(posedge clk) begin
  if (!reset) 
    current_state <= idle;
  else 
    current_state <= next_state;
end

logic read_started;
logic address_inc_flag;

logic image_processed;
logic image_isread;

// Combinational logic for next_state determination
always @(*) begin
  next_state = current_state;
  read_started = 0;
  read_valid = 0;
  address_inc_flag = 0;
  image_isread = 0;

  case (current_state)

    // idle state: the initial state, stay here until a chunk has been written //
    idle: begin
      read_started = 0;
      read_valid = 0;
      address_inc_flag = 1;
      image_isread = 1; // even if this is the first image this is used as it does not affect the rest of the design //
      if (write_valid) 
        next_state = raise_read_valid;
    end

    // raise read valid: when a chunk has been written, raise read_valid to start reading    //
    // this state is only for one cycle, in which the address must not be incremented        //
    // if, on this cycle, a new write valid signal appears, but we have not read the entire  //
    // current chunk, this is a cornercase which is handled by separate states               //
    raise_read_valid: begin
      read_valid = 1'b1;
      read_started = 1'b1;
      address_inc_flag = 0;

      if (write_valid && (read_address != write_address - 1))
        next_state = incr_cornercase;
      else
        next_state = address_incr;
    end

    // address_incr: in this state, we allow new addresses to be read, because the data in these //
    // addresses has been written. We do not change state until a write_valid signal arrives     //
    // if, on this cycle, a new write valid signal appears, but we have not read the entire  //
    // current chunk, this is a cornercase which is handled by separate states               //
    address_incr: begin 
      address_inc_flag = 1;
      read_started = 1;
      read_valid = 0;
      if (write_valid && (read_address == write_address - 1))
        next_state = raise_read_valid;
      else if (write_valid && (read_address != write_address - 1))
        next_state = incr_cornercase;
      else if ((read_address[1:0] == 2'b11) && (read_address == write_address + 2'd3) && (image_processed == 1)) // when an image has been fully read we move to the next //
        next_state = idle;   
    end

    // incr_cornercase: if a new byte is written while we are still reading previous data //
    // then we no longer wait for a new write_valid signal, because it has passed!        //
    // instead we count the addresses we have read and if we have read all four addresses //
    // that correspond to each chunk, then we proceed to raise the read_valid signal for  //
    // the next chunk (which we know has been written)                                    //
    incr_cornercase: begin
      address_inc_flag = 1;
      read_started = 1;
      read_valid = 0;

      if (read_address[1:0] == 2'b11)
        next_state = raise_read_valid_cornercase;             

    end

    // raise read valid cornercase: we raise read_valid for one cycle and then change state //
    raise_read_valid_cornercase: begin
      read_valid = 1'b1;
      read_started = 1'b1;
      address_inc_flag = 0;
    
      next_state = address_incr_cornercase;
    end

    // address_incr_cornercase: maybe there is overlap between this state and incr_cornercase    //
    // this is the state in which we can leave from the cornercase if we have read all the       //
    // bytes that have been written, but there still may be cornercases which are very confusing //
    address_incr_cornercase: begin 
      address_inc_flag = 1;
      read_started = 1;
      read_valid = 0;
      if (write_valid && (read_address == write_address - 1))
        next_state = raise_read_valid;
      else if ((read_address[1:0] == 2'b11) && (read_address == write_address + 2'd3) && (image_processed == 1)) // when an image has been fully read we move to the next //
        next_state = idle;
      else if ((read_address[1:0] == 2'b11) && (read_address == write_address + 2'd3))
        next_state = address_incr;
      else if ((read_address[1:0] == 2'b11))
        next_state = raise_read_valid_cornercase;
    end

  endcase
end

// if address_inc_flag is active, we generally icnrease the address, but NEVER past //
// the current write_address + 3, because the next addresses contain GARBAGE        //
always @(posedge clk) begin
  if (!reset || image_isread) begin
    read_address <= 16'b0;
  end
  else if (read_started && read_address < write_address + 2'd3 && address_inc_flag) begin
    read_address <= read_address + 1'b1;
  end

end

// smaller fsm that shows when an image has been fully processed //
always @(posedge clk) begin

  if (reset == 0 || image_isread) image_processed <= 0;

  else if (image_valid_out) image_processed <= 1;

end


endmodule