module send_blank_data1_fsm(

    input clk,
    input rst,
    input dir,
    input active,
    input nxt,
    output logic stp,
    output logic [7:0] data_out

);

// this fsm sends the PID for DATA1 and then h00 twice //
// only used for the set_address request //

`include "pid.vh"

logic [2:0] current_state, next_state;

logic pid_active;

parameter idle = 3'b000;
parameter send_pid = 3'b001;
parameter send_blank1 = 3'b010;
parameter send_blank2 = 3'b011;
parameter send_stp = 3'b100;

always @(posedge clk) begin
    if (!rst) current_state <= idle;
    else current_state <= next_state;
end

always @(*) begin

    next_state = current_state;
    stp = 1'b0;
    data_out = 8'b0;

    case(current_state)

        idle: begin
            if (active && (!dir)) begin
                next_state = send_pid;
            end
        end


        send_pid: begin
            
            data_out = 8'h4B; // PID_DATA1
                if (nxt) next_state = send_blank1;

        end

        send_blank1: begin
            
            // data is 0 by default //
            if (nxt) next_state = send_blank2;
        end

        send_blank2: begin
            // data is 0 by default //
            if (nxt) next_state = send_stp;
        end

        send_stp: begin
            stp = 1'b1;
            next_state = idle;
        end

    endcase

end


endmodule