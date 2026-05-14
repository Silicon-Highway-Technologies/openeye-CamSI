module jk_counter(
    input clk,
    input rst,
    input start,
    input [7:0] data_in,
    output logic done
);

logic counteractive, counterdone;

logic [3:0] current_state, next_state;
logic error;


parameter idleinitial = 4'b0000;
parameter k1 = 4'b0001;
parameter idle1 = 4'b0010;
parameter j1 = 4'b0011;
parameter idle2 = 4'b0100;
parameter k2 = 4'b0101;
parameter idle3 = 4'b0110;
parameter j2 = 4'b0111;
parameter idle4 = 4'b1000;
parameter k3 = 4'b1001;
parameter idle5 = 4'b1010;
parameter j3 = 4'b1011;
parameter idle6 = 4'b1100;
parameter idlefinal = 4'b1101;
parameter error_state = 4'b1110;

parameter zero = 3'b100;

always @(posedge clk) begin

  if (!rst) current_state <= idleinitial;

  else current_state <= next_state;

end

always @(*) begin

  counteractive = 1'b0;
  done = 1'b0;
  next_state = current_state;
  error = 1'b0;

  case (current_state)

  idleinitial: begin

    // if (start && data_in[1:0] == 2'b10) begin
    if (start) begin
        next_state = k1;
    end


  end

  k1: begin

    if (data_in[1:0] == 2'b10) begin
      next_state = idle1;
      counteractive = 1'b1;
    end

    // else if (data_in != 8'b0) begin
    //   error = 1'b1;
    //   next_state = error_state;

    // end

  end

  idle1: begin
    counteractive = 1'b1;
    if (counterdone) next_state = j1;
  end

  j1: begin

    if (data_in[1:0] == 2'b01) begin
      next_state = idle2;
      counteractive = 1'b1;
    end

  end

  idle2: begin
    counteractive = 1'b1;
    if (counterdone) next_state = k2;
  end

  k2: begin

    if (data_in[1:0] == 2'b10) begin
      next_state = idle3;
      counteractive = 1'b1;
    end

  end

  idle3: begin
    counteractive = 1'b1;
    if (counterdone) next_state = j2;
  end

  j2: begin

    if (data_in[1:0] == 2'b01) begin
      next_state = idle4;
      counteractive = 1'b1;
    end

  end

  idle4: begin
    counteractive = 1'b1;
    if (counterdone) next_state = k3;
  end

  k3: begin

    if (data_in[1:0] == 2'b10) begin
      next_state = idle5;
      counteractive = 1'b1;
    end

  end

  idle5: begin
    counteractive = 1'b1;
    if (counterdone) next_state = j3;
  end

  j3: begin

    if (data_in[1:0] == 2'b01) begin
      next_state = idle6;
      counteractive = 1'b1;
    end

  end

  idle6: begin
    counteractive = 1'b1;
    if (counterdone) next_state = idlefinal;
  end  

  idlefinal: begin
    done = 1'b1;
  end

  error_state: begin


  end

  endcase

end

// counter that counts for how many cycles a j chirp is active //
logic [7:0] counter;

always @(posedge clk) begin

  if (!rst || !start || counterdone || !counteractive) begin
    counter <= 8'b0;
  end

  else if (counteractive) begin // if data is different //
    counter <= counter + 1'b1;
  end

end

assign counterdone = (counter == 8'd151);

endmodule