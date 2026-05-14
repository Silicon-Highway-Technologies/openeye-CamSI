module short_packet_counter(

	input clk,
	input rst,
	input new_byte,
	input active,
	output logic done

);

// count two cycles for every packet with length 3 bytes //
// one byte has been already counted, which is the PID //

logic [2:0] cur, nxt;

parameter idle = 3'b000;
parameter cycle1 = 3'b001;
parameter cycle2 = 3'b010;
parameter finished = 3'b100;

always @(posedge clk) begin

	if (!rst) cur <= idle;

	else cur <= nxt;

end

always @(*) begin

	nxt = cur;
	done = 1'b0;

	case (cur)

		idle: begin

			if (active && new_byte) nxt = cycle1;
		end

		cycle1: begin

			if (new_byte) begin
				nxt = cycle2;
			end
		end

		cycle2: begin

			if (new_byte) nxt = finished;
				
		end

		finished: begin

			done = 1'b1;
			nxt = idle;
		end

	endcase
end


endmodule