
module register_write_fsm(
  input logic clk,
  input logic reset,
  input logic [7:0] data_to_reg,
  input logic dir,
  input logic nxt,
  output logic stp,
  output logic [7:0] data_out,
  input [5:0] register_address,
  input write_to_reg_flag
);

// `include "pid.vh"

// In this FSM there is still no consideration of DIR signal //

logic [2:0] next_state, current_state;

parameter idle = 3'b000;
parameter send_txcmd = 3'b001;
parameter write_to_reg = 3'b010;
parameter raise_stop = 3'b011;
parameter errorstate = 3'b111;

// Sequential logic for state transitions
always @(posedge clk) begin
  if (!reset) 
    current_state <= idle;
  else 
    current_state <= next_state;
end

always @(*) begin

  next_state = current_state;
  data_out = 8'b0;
  stp = 0;

  case(current_state)

    idle: begin
      // if DIR here, wait
      if (write_to_reg_flag) next_state = send_txcmd;
    end

    send_txcmd: begin

      if (dir) next_state = idle;
      else begin

        // send TXCMD //
        data_out[7:6] = 2'b10;
        data_out[5:0] = register_address;


        if (nxt) next_state = write_to_reg;
      end
    end

    write_to_reg: begin 
      data_out = data_to_reg;

      if (dir) next_state = errorstate;

      if (nxt) begin
        next_state = raise_stop;
      end

    end

  raise_stop: begin
    stp = 1;
    next_state = idle;
  end

  errorstate: begin

  end

  endcase

end

endmodule