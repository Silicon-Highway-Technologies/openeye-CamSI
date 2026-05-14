module detect_turnaround(
    input clk,
    input rst,
    input dir,
    output logic turnaround
);

logic [1:0] current_state, next_state;

parameter dirinactive = 2'b00;
parameter dirturnaround_active = 2'b01;
parameter diractive = 2'b10;
parameter dirturnaround_inactive = 2'b11;


// mini-FSM that controls the turnaround cycle after DIR rises and after DIR falls
always @(posedge clk) begin

    if (!rst) current_state <= dirinactive;

    else current_state <= next_state;

end

always @(*) begin

    turnaround = 1'b0;
    next_state = current_state;

    case(current_state)

        dirinactive: begin

            if (dir) begin
                next_state = diractive;
                turnaround = 1'b1;
            end

        end

        diractive: begin

            if (!dir) begin
                next_state = dirinactive;
                turnaround = 1'b1;
            end

        end

    endcase

end

endmodule