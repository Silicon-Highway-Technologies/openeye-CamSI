module audio_top (
  input sysclk,
  input rst,
  input mdata,
  output logic [7:0] audio_8bit,
  output logic afifo_write_en,
  output logic mclk
);

logic [23:0] mapped_data, integrated_data, decimated_data;
logic [23:0] combed_data;
logic pcm_pulse, pdm_pulse;
logic clk_24MHz;

logic signed [15:0] raw_audio_16bit;
logic signed [15:0] amplified_audio_16bit;

// generate 24MHz clock //
audio_clocking audio_clocking_inst(
  .sysclk(sysclk),
  .rst(rst),
  .clk_24MHz(clk_24MHz),
  .pdm_pulse(pdm_pulse),
  .mclk(mclk)
);

// pdm mapping - increase or decrease current accumulated value based on input //
pdm_mapper pdm_mapper_inst (
  .clk(clk_24MHz),
  .rst(rst),
  .pdm_pulse(pdm_pulse),
  .mdata(mdata),
  .pdm_mapped(mapped_data)
);

// integrator adds the mapped PDM values //
cic_integrators cic_integrators_inst (
  .clk(clk_24MHz),
  .rst(rst),
  .pdm_pulse(pdm_pulse),
  .din(mapped_data),
  .dout(integrated_data)
);

// decimator samples on 48kHz rate //
cic_decimator cic_decimator_inst (
  .clk(clk_24MHz),
  .rst(rst),
  .pdm_pulse(pdm_pulse),
  .din(integrated_data),
  .dout(decimated_data),
  .pcm_pulse(pcm_pulse)
);

// low-pass filtering //
cic_comb_filters cic_comb_filters_inst (
  .clk(clk_24MHz),
  .rst(rst),
  .pcm_pulse(pcm_pulse),
  .din(decimated_data),
  .dout(combed_data)
);

// DC centering //
dc_blocker dc_blocker_inst(
  .clk(clk_24MHz),
  .rst(rst),
  .pcm_pulse(pcm_pulse),
  .din(combed_data),
  .dout(raw_audio_16bit)
);

// amplifying //
amplifier amplifier_inst(
  .raw_audio_16bit(raw_audio_16bit),
  .amplified_audio_16bit(amplified_audio_16bit)
);

// send the 16bit audio over two 8bit chunks //
audio_to_8bit audio_to_8bit_inst(
  .clk_24MHz(clk_24MHz),
  .rst(rst),
  .pcm_pulse(pcm_pulse),
  .din(amplified_audio_16bit),
  .dout(audio_8bit),
  .afifo_write_en(afifo_write_en)
);

endmodule