
// Description: Dual Look-Up Table Gamma Corrector for 8-bit RAW data.
// Features a standard Gamma (0.45) and a Shadow-Boost Gamma (0.35) 
// for extracting details from dark backgrounds. Selectable via flag.

module rgb_gamma #(
    parameter GAIN_SHIFT = 0,
    parameter BRIGHTNESS_LIFT = 10
)(
    input  logic        clk,
    input  logic        rst,
    
    input  logic        shadow_boost_en, // 0 = Standard Gamma, 1 = Shadow Boost!
    
    input  logic [23:0] rgb_in,   
    input  logic        rgb_valid_in,
    
    output logic [23:0] rgb_out,  
    output logic        rgb_valid_out
);

    // =========================================================================
    // LUT 1: Standard Gamma (~0.45)
    // =========================================================================
    (* rom_style = "distributed" *) 
    const logic [7:0] gamma_rom_std [0:255] = '{
        8'd0,   8'd18,  8'd25,  8'd30,  8'd35,  8'd39,  8'd43,  8'd46,  8'd49,  8'd52,  8'd55,  8'd58,  8'd60,  8'd63,  8'd65,  8'd68, 
        8'd70,  8'd72,  8'd74,  8'd76,  8'd79,  8'd81,  8'd83,  8'd85,  8'd87,  8'd88,  8'd90,  8'd92,  8'd94,  8'd96,  8'd98,  8'd99, 
        8'd101, 8'd103, 8'd105, 8'd106, 8'd108, 8'd110, 8'd111, 8'd113, 8'd115, 8'd116, 8'd118, 8'd120, 8'd121, 8'd123, 8'd124, 8'd126, 
        8'd127, 8'd129, 8'd130, 8'd132, 8'd133, 8'd135, 8'd136, 8'd138, 8'd139, 8'd140, 8'd142, 8'd143, 8'd145, 8'd146, 8'd147, 8'd149, 
        8'd150, 8'd151, 8'd152, 8'd153, 8'd154, 8'd155, 8'd156, 8'd157, 8'd158, 8'd159, 8'd160, 8'd161, 8'd162, 8'd163, 8'd164, 8'd165, 
        8'd166, 8'd167, 8'd168, 8'd168, 8'd169, 8'd170, 8'd171, 8'd172, 8'd172, 8'd173, 8'd174, 8'd175, 8'd175, 8'd176, 8'd177, 8'd178, 
        8'd179, 8'd179, 8'd180, 8'd181, 8'd181, 8'd182, 8'd183, 8'd183, 8'd184, 8'd185, 8'd185, 8'd186, 8'd187, 8'd187, 8'd188, 8'd189, 
        8'd189, 8'd190, 8'd191, 8'd191, 8'd192, 8'd192, 8'd193, 8'd194, 8'd194, 8'd195, 8'd195, 8'd196, 8'd197, 8'd197, 8'd198, 8'd198, 
        8'd199, 8'd200, 8'd200, 8'd201, 8'd201, 8'd202, 8'd202, 8'd203, 8'd203, 8'd204, 8'd204, 8'd205, 8'd205, 8'd206, 8'd206, 8'd207, 
        8'd208, 8'd208, 8'd209, 8'd209, 8'd210, 8'd210, 8'd211, 8'd211, 8'd212, 8'd212, 8'd213, 8'd213, 8'd214, 8'd214, 8'd215, 8'd215, 
        8'd216, 8'd216, 8'd217, 8'd217, 8'd218, 8'd218, 8'd219, 8'd219, 8'd220, 8'd220, 8'd221, 8'd221, 8'd222, 8'd222, 8'd223, 8'd223, 
        8'd224, 8'd224, 8'd225, 8'd225, 8'd226, 8'd226, 8'd227, 8'd227, 8'd228, 8'd228, 8'd229, 8'd229, 8'd230, 8'd230, 8'd231, 8'd231, 
        8'd232, 8'd232, 8'd233, 8'd233, 8'd233, 8'd234, 8'd234, 8'd235, 8'd235, 8'd236, 8'd236, 8'd237, 8'd237, 8'd238, 8'd238, 8'd239, 
        8'd239, 8'd240, 8'd240, 8'd240, 8'd241, 8'd241, 8'd242, 8'd242, 8'd243, 8'd243, 8'd244, 8'd244, 8'd245, 8'd245, 8'd246, 8'd246, 
        8'd247, 8'd247, 8'd247, 8'd248, 8'd248, 8'd249, 8'd249, 8'd250, 8'd250, 8'd251, 8'd251, 8'd252, 8'd252, 8'd252, 8'd253, 8'd253, 
        8'd254, 8'd254, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255
    };

    // =========================================================================
    // LUT 2: Shadow Boost Gamma (~0.35) -> Massively lifts the dark pixels
    // =========================================================================
    (* rom_style = "distributed" *) 
    const logic [7:0] gamma_rom_boost [0:255] = '{
        8'd0,   8'd37,  8'd47,  8'd54,  8'd60,  8'd65,  8'd69,  8'd73,  8'd77,  8'd80,  8'd83,  8'd86,  8'd89,  8'd91,  8'd94,  8'd96, 
        8'd98,  8'd100, 8'd102, 8'd104, 8'd106, 8'd108, 8'd110, 8'd112, 8'd114, 8'd115, 8'd117, 8'd119, 8'd120, 8'd122, 8'd123, 8'd125, 
        8'd126, 8'd128, 8'd129, 8'd131, 8'd132, 8'd134, 8'd135, 8'd136, 8'd138, 8'd139, 8'd140, 8'd142, 8'd143, 8'd144, 8'd145, 8'd146, 
        8'd148, 8'd149, 8'd150, 8'd151, 8'd152, 8'd153, 8'd154, 8'd156, 8'd157, 8'd158, 8'd159, 8'd160, 8'd161, 8'd162, 8'd163, 8'd164, 
        8'd165, 8'd166, 8'd167, 8'd168, 8'd169, 8'd169, 8'd170, 8'd171, 8'd172, 8'd173, 8'd174, 8'd175, 8'd176, 8'd177, 8'd178, 8'd178, 
        8'd179, 8'd180, 8'd181, 8'd182, 8'd183, 8'd183, 8'd184, 8'd185, 8'd186, 8'd187, 8'd187, 8'd188, 8'd189, 8'd190, 8'd190, 8'd191, 
        8'd192, 8'd193, 8'd193, 8'd194, 8'd195, 8'd196, 8'd196, 8'd197, 8'd198, 8'd198, 8'd199, 8'd200, 8'd201, 8'd201, 8'd202, 8'd203, 
        8'd203, 8'd204, 8'd205, 8'd205, 8'd206, 8'd207, 8'd207, 8'd208, 8'd209, 8'd209, 8'd210, 8'd211, 8'd211, 8'd212, 8'd212, 8'd213, 
        8'd214, 8'd214, 8'd215, 8'd216, 8'd216, 8'd217, 8'd217, 8'd218, 8'd219, 8'd219, 8'd220, 8'd220, 8'd221, 8'd222, 8'd222, 8'd223, 
        8'd223, 8'd224, 8'd225, 8'd225, 8'd226, 8'd226, 8'd227, 8'd227, 8'd228, 8'd229, 8'd229, 8'd230, 8'd230, 8'd231, 8'd231, 8'd232, 
        8'd232, 8'd233, 8'd233, 8'd234, 8'd234, 8'd235, 8'd235, 8'd236, 8'd236, 8'd237, 8'd237, 8'd238, 8'd238, 8'd239, 8'd239, 8'd240, 
        8'd240, 8'd241, 8'd241, 8'd242, 8'd242, 8'd243, 8'd243, 8'd244, 8'd244, 8'd245, 8'd245, 8'd246, 8'd246, 8'd247, 8'd247, 8'd248, 
        8'd248, 8'd249, 8'd249, 8'd250, 8'd250, 8'd251, 8'd251, 8'd251, 8'd252, 8'd252, 8'd253, 8'd253, 8'd254, 8'd254, 8'd255, 8'd255, 
        8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 
        8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 
        8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255, 8'd255
    };

    logic [10:0] r_ext, g_ext, b_ext;
    logic [7:0]  r_pre, g_pre, b_pre;

    // White Balance Multipliers (Tune these fractions to perfect your colors)
    // Currently set to: Red x 1.5 (3/2) and Blue x 1.8 (9/5)
    localparam RED_MULT_NUM  = 1; 
    localparam RED_MULT_DEN  = 1; 
    
    localparam BLUE_MULT_NUM = 1; 
    localparam BLUE_MULT_DEN = 1;

    always_comb begin
        // 1. Apply White Balance, then Shift (Gain), then Add Pedestal
        r_ext = ((( {3'b000, rgb_in[23:16]} * RED_MULT_NUM ) / RED_MULT_DEN ) << GAIN_SHIFT) + BRIGHTNESS_LIFT;
        g_ext = (   {3'b000, rgb_in[15:8]}                                    << GAIN_SHIFT) + BRIGHTNESS_LIFT;
        b_ext = ((( {3'b000, rgb_in[7:0]}   * BLUE_MULT_NUM) / BLUE_MULT_DEN) << GAIN_SHIFT) + BRIGHTNESS_LIFT;

        // 2. Clamp to the absolute 8-bit Max (255) to prevent overflow
        r_pre = (r_ext > 11'd255) ? 8'd255 : r_ext[7:0];
        g_pre = (g_ext > 11'd255) ? 8'd255 : g_ext[7:0];
        b_pre = (b_ext > 11'd255) ? 8'd255 : b_ext[7:0];
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            rgb_out <= '0;
            rgb_valid_out <= 1'b0;
        end else begin
            // MUX: Select which ROM to read based on the switch/flag
            if (shadow_boost_en) begin
                rgb_out[23:16] <= gamma_rom_boost[r_pre];
                rgb_out[15:8]  <= gamma_rom_boost[g_pre];
                rgb_out[7:0]   <= gamma_rom_boost[b_pre];
            end else begin
                rgb_out[23:16] <= gamma_rom_std[r_pre];
                rgb_out[15:8]  <= gamma_rom_std[g_pre];
                rgb_out[7:0]   <= gamma_rom_std[b_pre];
            end
            
            rgb_valid_out  <= rgb_valid_in;
        end
    end

endmodule