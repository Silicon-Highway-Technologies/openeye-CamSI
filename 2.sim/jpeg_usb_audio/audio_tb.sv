module audio_tb;

  localparam SYSCLK_PERIOD = 5; //   1/200MHz = 5ns //

  reg sysclk;
  reg rst;
  reg mdata;
  wire mclk;
  wire [7:0] audio_8bit;
  wire audio_afifo_write_en;

  integer dump_file;

  // array to hold 2.4 million 1-bit samples
  reg pdm_memory [0:2399999]; 
  integer pdm_index;

  audio_top audio_top_inst(
    .sysclk(sysclk),
    .rst(rst),
    .mdata(mdata),
    .mclk(mclk),
    .audio_8bit(audio_8bit),
    .afifo_write_en(audio_afifo_write_en)
  );

  initial begin
    pdm_index = 0;

    $display("Loading PDM stimulus file into memory...");
    $readmemb("../../../../../../2.sim/jpeg_usb_audio/pdm_stimulus.txt", pdm_memory);
    $display("PDM file loaded successfully!");
  end

  // Clock Generation
  always #(SYSCLK_PERIOD/2.0) sysclk = ~sysclk;

  // store PDM data in memory //
  always @(posedge mclk) begin
    if (pdm_index < 2400000) begin
        mdata <= pdm_memory[pdm_index];
        pdm_index <= pdm_index + 1;
      end else begin
        mdata <= 1'b0;
      end
  end

  initial begin
    dump_file = $fopen("../../../../../../2.sim/jpeg_usb_audio/audio_dump.txt", "w");
    
    if (dump_file == 0) begin
        $display("ERROR: Could not open dump file!");
        $finish;
    end    
  end    

  always @(posedge audio_top_inst.clk_24MHz) begin
    if (audio_afifo_write_en) $fdisplay(dump_file, "%h", audio_8bit);
  end  

  initial begin
    
    sysclk = 1'b0;
    rst = 1'b0;

    #100 rst = 1'b1;

    #1000000000 $fclose(dump_file);
    $finish;

  end

endmodule