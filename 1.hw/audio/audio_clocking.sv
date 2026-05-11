module audio_clocking(

  input sysclk,
  input rst,

  output logic mclk,
  output logic clk_24MHz,
  output logic pdm_pulse

);

logic clkfb;
logic locked;

// generate 24MHz clock from 200MHz clock //

MMCME2_BASE #(
  .BANDWIDTH("OPTIMIZED"),   // Jitter programming (OPTIMIZED, HIGH, LOW)
  .CLKFBOUT_MULT_F(24.0),     // Multiply value for all CLKOUT (2.000-64.000).
  .CLKFBOUT_PHASE(0.0),      // Phase offset in degrees of CLKFB (-360.000-360.000).
  .CLKIN1_PERIOD(5.0),       // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
  // CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
  .CLKOUT1_DIVIDE(40),
  .CLKOUT2_DIVIDE(1),
  .CLKOUT3_DIVIDE(1),
  .CLKOUT4_DIVIDE(1),
  .CLKOUT5_DIVIDE(1),
  .CLKOUT6_DIVIDE(1),
  .CLKOUT0_DIVIDE_F(1),    // Divide amount for CLKOUT0 (1.000-128.000).
  // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
  .CLKOUT0_DUTY_CYCLE(0.5),
  .CLKOUT1_DUTY_CYCLE(0.5),
  .CLKOUT2_DUTY_CYCLE(0.5),
  .CLKOUT3_DUTY_CYCLE(0.5),
  .CLKOUT4_DUTY_CYCLE(0.5),
  .CLKOUT5_DUTY_CYCLE(0.5),
  .CLKOUT6_DUTY_CYCLE(0.5),
  // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
  .CLKOUT0_PHASE(0.0),
  .CLKOUT1_PHASE(0.0),
  .CLKOUT2_PHASE(0.0),
  .CLKOUT3_PHASE(0.0),
  .CLKOUT4_PHASE(0.0),
  .CLKOUT5_PHASE(0.0),
  .CLKOUT6_PHASE(0.0),
  .CLKOUT4_CASCADE("FALSE"), // Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
  .DIVCLK_DIVIDE(5),         // Master division value (1-106)
  .REF_JITTER1(0.0),         // Reference input jitter in UI (0.000-0.999).
  .STARTUP_WAIT("FALSE")     // Delays DONE until MMCM is locked (FALSE, TRUE)
)
MMCME2_BASE_inst (
  .CLKOUT1(clk_24MHz),     // 1-bit output: new_clk (our new clock)
  .CLKFBOUT(clkfb),   // 1-bit output: Feedback clock
  // .CLKFBOUTB(clkfboutb), // 1-bit output: Inverted CLKFBOUT
  // Status Ports: 1-bit (each) output: MMCM status ports
  .LOCKED(locked),       // 1-bit output: LOCK
  // Clock Inputs: 1-bit (each) input: Clock input
  .CLKIN1(sysclk),       // 1-bit input: Clock
  // Control Ports: 1-bit (each) input: MMCM control ports
  .PWRDWN(1'b0),       // 1-bit input: Power-down
  .RST(!rst),             // 1-bit input: Reset
  // Feedback Clocks: 1-bit (each) input: Clock feedback ports
  .CLKFBIN(clkfb)      // 1-bit input: Feedback clock
);

// 10-cycle counter //

logic [3:0] miccounter; 

always @(posedge clk_24MHz) begin

  if (!rst) begin
    miccounter <= 4'b0;
    mclk <= 1'b0;
    pdm_pulse <= 1'b0;
  end

  else begin
    pdm_pulse <= 1'b0;

    if (miccounter == 4'd4) begin
      miccounter <= 4'b0;
      mclk <= ~mclk; 

      if (mclk == 1'b1) pdm_pulse <= 1'b1;
    end

    else begin
      miccounter <= miccounter + 1'b1;
    end
  end

end

endmodule