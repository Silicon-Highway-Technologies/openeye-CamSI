module detect_sof(

  input clk,
  input rst,
  input DIR,
  input NXT,
  input [7:0] DATA,
  output logic ignore_sof,
  output logic new_microframe
);

`include "pid.vh"

logic [2:0] cur, nxt;
logic new_byte;

parameter IDLE = 3'b000;
parameter CYCLE1 = 3'b001;
parameter CYCLE2 = 3'b010;
parameter CYCLE3 = 3'b011;
parameter CYCLE4 = 3'b100;
parameter CYCLE5 = 3'b101;

assign new_byte = DIR && NXT;

always @(posedge clk) begin

  if (!rst) cur <= IDLE;

  else cur <= nxt;

end

always @(*) begin

  ignore_sof = 1'b0;
  new_microframe = 1'b0;
  nxt = cur;

  case(cur)

  IDLE: begin

    if (!DIR) nxt = CYCLE1;
  end

  CYCLE1: begin

    if (DIR) nxt = CYCLE2;
  end

  CYCLE2: begin

    if ((new_byte)) begin
      if (DATA == PID_SOF) begin
        nxt = CYCLE3;
        ignore_sof = 1'b1;
        new_microframe = 1'b1;
      end else begin
        nxt = IDLE;
      end
    end
    else if (!DIR) nxt = IDLE;
  end

  CYCLE3: begin

    ignore_sof = 1'b1;
    if (new_byte) nxt = CYCLE4;
    else if (!DIR) nxt = IDLE;
  end

  CYCLE4: begin

    ignore_sof = 1'b1;
    if (new_byte) nxt = CYCLE5;
    else if (!DIR) nxt = IDLE;
  end  

  CYCLE5: begin
    ignore_sof = 1'b1;
    if (!DIR) nxt = IDLE;
  end


  endcase

end

endmodule