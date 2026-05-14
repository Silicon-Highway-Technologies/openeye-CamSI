module verify_address_and_endpoint(

    input clk,
    input rst,
    input new_byte,
    input [7:0] data,
    input [6:0] address,
    input active,
    input check_address,
    output logic valid_ep1,
    output logic valid_ep2,
    output logic valid_ep0
);

// during a setup packet, count the cycles regularly //
// but when the second byte arrives, verify that it matches the address //
// which was set by the set_address descriptor //

logic [2:0] cur, nxt;

parameter idle = 3'b000;
parameter cycle1 = 3'b001;
parameter cycle2_ep1 = 3'b010;
parameter cycle2_ep0_ep2 = 3'b011;
parameter finished_ep1 = 3'b100;
parameter finished_ep2 = 3'b101;
parameter finished_ep0 = 3'b111;

always @(posedge clk) begin

    if (!rst) cur <= idle;

    else cur <= nxt;

end

always @(*) begin

    valid_ep1 = 0;
    valid_ep2 = 0;
    valid_ep0 = 0;
    nxt = cur;

    case (cur)

        idle: begin

          if (active && new_byte) nxt = cycle1;
        end

        cycle1: begin

          if (new_byte) begin
            if ((check_address && (data[6:0] == address)) || (!check_address)) begin
              if (data[7] == 1'b0)  nxt = cycle2_ep0_ep2;
              else if (data[7] == 1'b1)  nxt = cycle2_ep1;
            end
            else nxt = idle; // if check_address AND address does not match
          end

          else nxt = idle;
        end

        cycle2_ep1: begin
          if (new_byte) begin
              // Endpoint 1 requires bits 3:1 to be 3'b000
              if (data[2:0] == 3'b000) nxt = finished_ep1;
              else nxt = idle;
          end
          else nxt = idle;
        end

        cycle2_ep0_ep2: begin
          if (new_byte) begin
              // Endpoint 2 requires bits 3:1 to be 3'b001
              if (data[2:0] == 3'b001) nxt = finished_ep2;
              else if (data[2:0] == 3'b000) nxt = finished_ep0;
              else nxt = idle;
          end
          else nxt = idle;
        end 

        finished_ep0: begin
          valid_ep0 = 1'b1;
          nxt = idle;
        end               

        finished_ep1: begin
          valid_ep1 = 1'b1;
          nxt = idle;
        end

        finished_ep2: begin
          valid_ep2 = 1'b1;
          nxt = idle;
        end        

    endcase
end



endmodule