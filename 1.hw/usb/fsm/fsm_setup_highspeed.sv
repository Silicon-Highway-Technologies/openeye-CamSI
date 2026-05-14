module fsm_setup_highspeed(

    input clk,
    input rst,
    input DIR,
    input NXT,
    input [7:0] DATA,
    output logic stp_value,
    output logic [7:0] data_value,
    output logic active
);

// this fsm is used for high-speed setup //
// after we set it, we use a different FSM for the packet handling //
`include "parameters_fsm_setup_highspeed.vh"

logic read_reg_flag;
logic [4:0] next_state, current_state;
logic write_to_reg_flag;
logic [5:0] write_reg_address;
logic stp_regwrite;
logic [7:0] output_data_regwrite;
logic [7:0] data_to_reg;
logic [5:0] read_reg_address;
logic stp_regread;
logic [7:0] output_data_regread;
logic regread_done;
logic turnaround;
logic [7:0] rxcmd;
logic chirpcounterdone, chirpcounteractive;
logic jk_done;
logic count_jk;
logic se0counterdone, se0counteractive;

// fsm to write to a register //
register_write_fsm register_write_fsm_inst(
  .clk(clk),
  .reset(rst),
  .dir(DIR),
  .nxt(NXT),
  .stp(stp_regwrite),
  .write_to_reg_flag(write_to_reg_flag),
  .register_address(write_reg_address),
  .data_to_reg(data_to_reg), // input //
  .data_out(output_data_regwrite)
);

// fsm to read from a register //
register_read_fsm register_read_fsm_inst(
  .clk(clk),
  .reset(rst),
  .dir(DIR),
  .nxt(NXT),
  .data_in(DATA),
  .data_out(output_data_regread),
  .stp(stp_regread),
  .read_data_flag(read_reg_flag),
  .register_address(read_reg_address),
  .done(regread_done)
);

// count ~1.5ms, required so that we send ZERO during this time //
// to apply the chirp from our side. 1-7ms is required.//
counter_for_chirp counter_for_chirp_inst(
  .clk(clk),
  .rst(rst),
  .counter_active(chirpcounteractive),
  .done(chirpcounterdone)
);

// count 1.5us to verify that we have detecte a se0 //
counter_for_se0 counter_for_se0_inst(
  .clk(clk),
  .rst(rst),
  .counter_active(se0counteractive),
  .done(se0counterdone)
);

// count 3 pairs of J-K chirps send by the host //
jk_counter jk_counter_inst(
  .clk(clk),
  .rst(rst),
  .start(count_jk),
  .data_in(DATA),
  .done(jk_done)
);

// module to detect the cycle in which DIR activates or deactivates //
// this cycle is a "turnaround" cycle, meaning that DATA on this cycle must be ignored //
detect_turnaround detect_turnaround_inst(
  .clk(clk),
  .rst(rst),
  .dir(DIR),
  .turnaround(turnaround)
);

always @(posedge clk) begin

  if (!rst) current_state <= idleinitial;

  else current_state <= next_state;

end

always_comb begin

  data_value = 8'b0000_0000;
  stp_value = 1'b0;
  next_state = current_state;
  read_reg_flag = 0;
  read_reg_address = 6'b0;
  write_to_reg_flag = 0;
  write_reg_address = 6'b0;
  data_to_reg = 8'b0;
  chirpcounteractive = 1'b0;
  count_jk = 1'b0;
  se0counteractive = 1'b0;
  active = 1'b1;

  case (current_state)

  // idle state: wait until DIR is asserted, post-reset //
  idleinitial: begin

    if (DIR) begin
      next_state = detectRXCMDinitial;
    end

  end

  // after DIR is asserted, we assume that a RXCMD is sent to us //
  // but we do not actually decode it //
  detectRXCMDinitial: begin

    // we do not need to read it, just receive it //
    if (!DIR) begin
        next_state = countinitialse0;
    end    
  end

  // we assume that the initial RXCMD signalled a SE0 //
  // for it to be valid, we must wait 2.5us //
  // during this time, another RXCMD must not be asserted //
  countinitialse0: begin

    // count 2.5us from SE0 start to proceed

    se0counteractive = 1'b1;

    if (se0counterdone && (!DIR)) begin
      next_state = setidpullup;
      se0counteractive = 1'b0;
    end
  end

  // the first register we write is the ID pull up //
  // this is not documented in the manual and was figured out through trial and error //
  // I think that our PHY does not have a resistor somewhere which is normally required //
  // this is why we have to set this variable, to make up for it //
  setidpullup: begin
    stp_value = stp_regwrite;
    data_value = output_data_regwrite;

    if (!DIR) begin
      write_to_reg_flag = 1'b1;
      write_reg_address = 6'h0A;
      data_to_reg = 8'b00000001;
      if (stp_value) next_state = hack_disconnect;
    end    

  end

  // write h45 to registers to make USB think we disconnected //
  // this is required because, when FPGA is programmed, the USB is already connected //
  // this was very hard to figure out and required a lot of trial and error //
  // writing 45 means that termselect is 1, so the 1.5kOhm resistor is connected to D+ //
  hack_disconnect: begin
    stp_value = stp_regwrite;
    data_value = output_data_regwrite;

    write_to_reg_flag = 1'b1;
    write_reg_address = 6'h04;
    data_to_reg = 8'b0100_0101; // h45
    if (stp_value) next_state = waitforse0;

  end

  // wait until we receive a RXCMD with linestate SE0 //
  waitforse0: begin

    if ((DIR) && (!turnaround) && (DATA[1:0] == 2'b00)) begin
        next_state = countsecondse0;
    end 
  end

  // again, count 2.5us to verify the SE0 //
  countsecondse0: begin

    se0counteractive = 1'b1;
    if (se0counterdone && (DIR == 0)) begin
      
      next_state = clearopmode0;
      se0counteractive = 1'b0;

    end
  end

  // the below register writes are all documented in the ULPI manual //
  // and are required for the high-speed setup //

  // clear the opmode LSB by writing to the clear register for the specific bit //
  clearopmode0: begin
    stp_value = stp_regwrite;
    data_value = output_data_regwrite;

    write_to_reg_flag = 1'b1;
    write_reg_address = 6'h06;
    data_to_reg = 8'b00001000; // h08
    if (stp_value) next_state = setopmode1;
  end

  // set the opmode MSB by writing to the set register for the specific bit //
  setopmode1: begin
    stp_value = stp_regwrite;
    data_value = output_data_regwrite;

    write_to_reg_flag = 1'b1;
    write_reg_address = 6'h05;
    data_to_reg = 8'b00010000; // h10
    if (stp_value) next_state = clearxcvr;
  end  

  // clear both xcvr bits by writing to the clear register for both //
  clearxcvr: begin
    stp_value = stp_regwrite;
    data_value = output_data_regwrite;

    write_to_reg_flag = 1'b1;
    write_reg_address = 6'h06;
    data_to_reg = 8'b00000011; // 03
    if (stp_value) next_state = settermselect;
  end
  
  // set the termselect bit by writing to the set register //
  settermselect: begin
    stp_value = stp_regwrite;
    data_value = output_data_regwrite;

    write_to_reg_flag = 1'b1;
    write_reg_address = 6'h05;
    data_to_reg = 8'b00000100; // h04

    if (stp_value)  next_state = senddata_chirp;
  end  

  // we have finished writing to registers //
  // and we must now send the chirp from our side //
  // first send TXCMD to indicate data transmission //
  senddata_chirp: begin
    // send a TXCMD at this point //

    data_value = 8'h40;
    stp_value = 1'b0;

    if (NXT) begin
      next_state = senddata_zero;
    end
  end

  // send chirp (zero) for 1.5ms //
  senddata_zero: begin
    // hold counter for 1-7ms //

    chirpcounteractive = 1'b1;
    data_value = 8'h00;
    stp_value = 1'b0;    

    if (chirpcounterdone) begin
      next_state = waitfordir;
      stp_value = 1'b1;
    end
  end  

  // wait for DIR to be asserted //
  waitfordir: begin
    stp_value = 1'b0;
    data_value = 8'h00;       
    if (DIR) begin
      next_state = detect_jk;
      count_jk = 1'b1;
    end
  end

  // after we have sent our chirp, the host must send 3 pairs of J and K chirps //
  // we must detect them to proceed //
  detect_jk: begin
    stp_value = 1'b0;
    count_jk = 1'b1;
    data_value = 8'h00;

    if (jk_done) next_state = readrxcmd;

  end

  // read the next RXCMD, which must be a SE0 //
  readrxcmd: begin
    stp_value = 1'b0;
    data_value = 8'h00;     

    if (DIR && (!turnaround) && (DATA[1:0] == 2'b00)) begin // linestate 00 -> write 40 
        next_state = setbits40;
    end

  end

  // after the chirp exchange, we clear the registers (set them to 0) //
  // when we do this, high-speed is activated and the host starts transmitting packets //
  setbits40: begin

    stp_value = stp_regwrite;
    data_value = output_data_regwrite;
    if (!DIR) begin
      write_to_reg_flag = 1'b1;
      write_reg_address = 6'h04;
      data_to_reg = 8'b0100_0000;
      if (stp_value) next_state = terminalstate;
    end
  end

  // read registers for debugging purposes //
  readregisters: begin
    stp_value = stp_regread;
    data_value = output_data_regread;

    read_reg_flag = 1;
    read_reg_address = 6'h04; // read function control
    // read_reg_address = 6'h15; // read linestate
    // read_reg_address = 6'h13; // read interrupt status
    // read_reg_address = 6'h0A; // read OTG control

    if (regread_done) begin // Wait for the sub-FSM to finish!

        // next_state = setidpullup;
    end     

  end

  terminalstate: begin
    
    active = 1'b0;
  end

  endcase

end


endmodule