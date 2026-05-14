

module register_read_fsm(
  input logic clk,
  input logic reset,
  input logic [7:0] data_in,
  output logic [7:0] data_out,
  input logic dir,
  input logic nxt,
  output logic stp,
  input [5:0] register_address,
  input logic read_data_flag,
  output logic done
);

assign stp = 0;

logic [2:0] next_state, current_state;

parameter idle = 3'b000;
parameter send_rxcmd = 3'b001;
parameter receive_data_active = 3'b010;
parameter wait_one_cycle_before = 3'b011;
parameter wait_one_cycle_after = 3'b110;

// Sequential logic for state transitions
always @(posedge clk) begin
  if (!reset) 
    current_state <= idle;
  else 
    current_state <= next_state;
end

always_comb begin

  next_state = current_state;
  data_out = 8'b0;
  done = 0;

  case(current_state)

    idle: begin

      if ((!dir) && (read_data_flag)) next_state = send_rxcmd;
      // next_state = send_rxcmd;
    end

    send_rxcmd: begin
        if (dir) next_state = idle;

        else if (nxt == 1) begin

          // send TXCMD //
          data_out[7:6] = 2'b11;
          data_out[5:0] = register_address;
          next_state = wait_one_cycle_before;
        end

        else if (nxt == 0) begin
          // send TXCMD //
          data_out[7:6] = 2'b11;
          data_out[5:0] = register_address;
        end
    end

    wait_one_cycle_before: begin
      
      // must wait one cycle! //
      if (dir) next_state = receive_data_active;

    end

    receive_data_active: begin
    
      data_out = data_in;
      if (!dir) next_state = wait_one_cycle_after;
    end


    wait_one_cycle_after: begin
      
      done = 1;
      // must wait one cycle! //
      next_state = idle;

    end

  endcase

end

endmodule