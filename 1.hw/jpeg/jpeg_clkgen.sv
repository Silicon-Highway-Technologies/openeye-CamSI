module jpeg_clkgen(
  input  logic sysclk,
  input  logic reset,
  input  logic hdmi_clock,
  output logic pixel_clock,
  output logic jpeg_fast_clock,
  output logic jpeg_slow_clock
);

assign jpeg_slow_clock = hdmi_clock;
assign pixel_clock = hdmi_clock;

logic clkfb_out;
logic clkfb_buf;                   // <-- Feedback buffer wire
logic fast_clk_unbuf;              // <-- Output buffer wire
logic locked;

// 1. MUST use BUFG for the feedback loop to align phases properly
BUFG bufg_fb (
    .I(clkfb_out), 
    .O(clkfb_buf)
);

// 2. MUST use BUFG to put the 175MHz clock onto the global clock tree
BUFG bufg_fast_clk (
    .I(fast_clk_unbuf), 
    .O(jpeg_fast_clock)
);

MMCME2_BASE #(
  .BANDWIDTH("OPTIMIZED"),
  .DIVCLK_DIVIDE(2),
  .CLKFBOUT_MULT_F(7.000),
  .CLKFBOUT_PHASE(0.0),
  .CLKIN1_PERIOD(5.000),         // Note: Assumes exactly 200 MHz input!

  // Output Clock 0: 175.000 MHz
  .CLKOUT0_DIVIDE_F(4.000),
  .CLKOUT0_DUTY_CYCLE(0.5),
  .CLKOUT0_PHASE(0.0),

  .CLKOUT1_DIVIDE(1), .CLKOUT1_DUTY_CYCLE(0.5), .CLKOUT1_PHASE(0.0),
  .CLKOUT2_DIVIDE(1), .CLKOUT2_DUTY_CYCLE(0.5), .CLKOUT2_PHASE(0.0),
  .CLKOUT3_DIVIDE(1), .CLKOUT3_DUTY_CYCLE(0.5), .CLKOUT3_PHASE(0.0),
  .CLKOUT4_DIVIDE(1), .CLKOUT4_DUTY_CYCLE(0.5), .CLKOUT4_PHASE(0.0),
  .CLKOUT5_DIVIDE(1), .CLKOUT5_DUTY_CYCLE(0.5), .CLKOUT5_PHASE(0.0),
  .CLKOUT6_DIVIDE(1), .CLKOUT6_DUTY_CYCLE(0.5), .CLKOUT6_PHASE(0.0),
  
  .CLKOUT4_CASCADE("FALSE"), 
  .REF_JITTER1(0.0),
  .STARTUP_WAIT("FALSE")     
) 
mmcm_175mhz_inst (
  // Clock Inputs
  .CLKIN1(sysclk),
  .CLKFBIN(clkfb_buf),           // <-- Buffered feedback
  
  // Clock Outputs
  .CLKOUT0(fast_clk_unbuf),      // <-- Goes to BUFG first
  .CLKOUT1(), .CLKOUT2(), .CLKOUT3(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6(),
  .CLKFBOUT(clkfb_out),
  .CLKFBOUTB(),
  
  // Control Ports
  .PWRDWN(1'b0),
  .RST(reset),                   // <-- Hooked up the reset
  
  // Status Ports
  .LOCKED(locked)                // <-- Exported lock status
);

endmodule