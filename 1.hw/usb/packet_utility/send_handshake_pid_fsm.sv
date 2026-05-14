module send_handshake_pid_fsm(

    input clk,
    input rst,
    input dir,
    input active,
    input nxt,
    input [3:0] handshake_pid,
    output logic stp,
    output logic [7:0] data_out

);

// this module merges send_ACK_fsm, send_NAK_fsm and send_STALL_fsm //
// here the PID is passed as parameter //

`include "pid.vh"

logic [1:0] current_state, next_state;

parameter idle = 2'b00;
parameter send_ack = 2'b01;
parameter send_stp = 2'b10;

always @(posedge clk) begin
    if (!rst) current_state <= idle;
    else current_state <= next_state;
end

always @(*) begin

    next_state = current_state;
    data_out = 8'd0;
    stp = 1'b0;

    case(current_state)

        idle: begin
            if (active && (!dir)) begin
                next_state = send_ack;
            end
        end

        send_ack: begin

            data_out[7:4] = 4'b0100; // send a TXCMD //
            data_out[3:0] = handshake_pid;
            if (nxt)
                next_state = send_stp;

        end

        send_stp: begin
            stp = 1'b1;
            next_state = idle;
        end

    endcase


end

endmodule