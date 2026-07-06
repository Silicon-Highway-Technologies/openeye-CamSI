`timescale 1ns / 1ps

module count_afifo_bytes #(
  parameter ASIZE = 11
)(
  // Write Domain (from Pixel Clock / JPEG side)
  input  logic             i_wclk,
  input  logic             i_wrst_n,
  input  logic [ASIZE:0]   wptr,

  // Read Domain (from 60 MHz USB side)
  input  logic             i_rclk,
  input  logic             i_rrst_n,
  input  logic [ASIZE:0]   rptr,

  // Output Data Count (Synchronized to 60 MHz Read Domain)
  output logic [ASIZE:0]   o_rcount
);

  // -------------------------------------------------------------------------
  // STEP 1: Convert wptr to Gray code and register it in the WRITE domain
  // -------------------------------------------------------------------------
  logic [ASIZE:0] wptr_gray_wr_clk;

  always_ff @(posedge i_wclk or negedge i_wrst_n) begin
      if (!i_wrst_n) begin
          wptr_gray_wr_clk <= '0;
      end else begin
          wptr_gray_wr_clk <= (wptr >> 1) ^ wptr;
      end
  end

  // -------------------------------------------------------------------------
  // STEP 2: Synchronize the Gray pointer into the READ domain (60 MHz)
  // -------------------------------------------------------------------------
  logic [ASIZE:0] wptr_gray_sync1;
  logic [ASIZE:0] wptr_gray_sync2;

  always_ff @(posedge i_rclk or negedge i_rrst_n) begin
      if (!i_rrst_n) begin
          wptr_gray_sync1 <= '0;
          wptr_gray_sync2 <= '0;
      end else begin
          wptr_gray_sync1 <= wptr_gray_wr_clk; // First flop
          wptr_gray_sync2 <= wptr_gray_sync1;  // Second flop (metastability safe)
      end
  end

  // -------------------------------------------------------------------------
  // STEP 3: Convert the synced Gray pointer back to Binary (Read domain)
  // -------------------------------------------------------------------------
  logic [ASIZE:0] wptr_bin_rd_clk;
  integer i;

  always_comb begin
      wptr_bin_rd_clk[ASIZE] = wptr_gray_sync2[ASIZE];
      for (i = ASIZE-1; i >= 0; i = i - 1) begin
          wptr_bin_rd_clk[i] = wptr_bin_rd_clk[i+1] ^ wptr_gray_sync2[i];
      end
  end

  // -------------------------------------------------------------------------
  // STEP 4: Calculate exactly how many bytes are in the FIFO
  // -------------------------------------------------------------------------
  always_ff @(posedge i_rclk or negedge i_rrst_n) begin
      if (!i_rrst_n) begin
          o_rcount <= '0;
      end else begin
          // Subtraction naturally handles pointer wrap-around
          o_rcount <= wptr_bin_rd_clk - rptr; 
      end
  end

endmodule