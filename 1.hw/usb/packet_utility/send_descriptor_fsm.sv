module send_descriptor_fsm
  import top_pkg::*;
(

  input clk,
  input rst,
  input dir,
  input active,
  input nxt,
  input [4:0] request,
  input [2:0] config_descriptor_packet_counter,
  output logic stp,
  output logic [7:0] data_out

);

// here we send the descriptor data //
// which vary based on the request //

`include "pid.vh"
`include "request_parameters.vh"
`include "settings.vh"

logic [1:0] current_state, next_state;

logic pid_active;
logic [7:0] bytecounter, countermax;

parameter idle = 2'b00;
parameter send_data = 2'b01;
parameter send_stp = 2'b10;

always @(posedge clk) begin
  if (!rst) current_state <= idle;
  else current_state <= next_state;
end

always @(*) begin

  next_state = current_state;
  stp = 1'b0;
  pid_active = 1'b0;

  case(current_state)

    idle: begin
      if (active && (!dir)) begin
        next_state = send_data;
        pid_active = 1'b1;
      end
    end

    send_data: begin
      if (bytecounter == countermax && nxt)
          next_state = send_stp;
    end

    send_stp: begin
      stp = 1'b1;
      next_state = idle;
    end

  endcase


end

// assign max counter value for stop based on state //

always @(*) begin

	case(request)
    GET_DEVICE_DESCRIPTOR: countermax = 8'd21;
    GET_CONFIG_DESCRIPTOR_9BYTES: countermax = 8'd12;
		GET_CONFIG_DESCRIPTOR_255BYTES: begin
      if (config_descriptor_packet_counter == 3'b011) countermax = 8'd66;
      else countermax = 8'd67;
    end    
		GET_CONFIG_DESCRIPTOR_FULL: begin
      if (config_descriptor_packet_counter == 3'b100) countermax = 8'd4;
      else countermax = 8'd67;
    end
    GET_CUR_VIDEO_PROBE: countermax = 8'd29;
    GET_CUR_AUDIO_MUTE: countermax = 8'd4;
    GET_CUR_AUDIO_VOL: countermax = 8'd5;
    GET_MIN_VIDEO_PROBE: countermax = 8'd29;
    GET_MAX_VIDEO_PROBE: countermax = 8'd29;
    GET_MIN_AUDIO_VOL: countermax = 8'd5;
    GET_MAX_AUDIO_VOL: countermax = 8'd5;
    GET_RES: countermax = 8'd5;
    SET_ADDRESS: countermax = 8'd0;
    SET_CUR: countermax = 8'd0;
    SET_INTERFACE: countermax = 8'd0;
    SET_CONFIGURATION: countermax = 8'd0;

    default: countermax = 8'd0;
	endcase

end



always @(posedge clk) begin

    if (!rst || stp) bytecounter <= 8'b0;

    else if ((active && nxt) || (pid_active)) bytecounter <= bytecounter + 1'b1;

end

always @ (posedge clk) begin
    if (!rst) begin
        data_out <= 8'h00;
    end
    
    else begin

        if ((current_state == idle) && active && !dir) begin
          if ((request == GET_CONFIG_DESCRIPTOR_FULL || request == GET_CONFIG_DESCRIPTOR_255BYTES) && (config_descriptor_packet_counter[0] == 1'b1)) //  odd packets //
            data_out <= 8'h43; // DATA0
          else
            data_out <= 8'h4B; // PID_DATA1
        end

        else if ((current_state == send_data) && nxt) begin
            
						if (request == GET_DEVICE_DESCRIPTOR) begin // get descriptor device //

							if      (bytecounter == 8'd1)  data_out <= 8'h12; // bLength
							else if (bytecounter == 8'd2)  data_out <= 8'h01; // bDescriptorType
							else if (bytecounter == 8'd3)  data_out <= 8'h00; // bcdUSB (Low)
							else if (bytecounter == 8'd4)  data_out <= 8'h02; // bcdUSB (High)
              else if (bytecounter == 8'd5)  data_out <= 8'hEF; // bDeviceClass
              else if (bytecounter == 8'd6)  data_out <= 8'h02; // bDeviceSubClass
              else if (bytecounter == 8'd7)  data_out <= 8'h01; // bDeviceProtocol
							else if (bytecounter == 8'd8)  data_out <= 8'h40; // bMaxPacketSize0
							else if (bytecounter == 8'd9)  data_out <= 8'hCC; // idVendor (Low)
							else if (bytecounter == 8'd10) data_out <= 8'hCA; // idVendor (High)
							else if (bytecounter == 8'd11) data_out <= 8'h87; // idProduct (Low)
							else if (bytecounter == 8'd12) data_out <= 8'h34; // idProduct (High)
							else if (bytecounter == 8'd13) data_out <= 8'h00; // bcdDevice (Low)
							else if (bytecounter == 8'd14) data_out <= 8'h01; // bcdDevice (High)
							else if (bytecounter == 8'd15) data_out <= 8'h00; // iManufacturer
							else if (bytecounter == 8'd16) data_out <= 8'h00; // iProduct
							else if (bytecounter == 8'd17) data_out <= 8'h00; // iSerialNumber
							else if (bytecounter == 8'd18) data_out <= 8'h01; // bNumConfigurations

							// --- CRC16 CHECKSUM ---
							else if (bytecounter == 8'd19) data_out <= 8'h92; // CRC Byte 1 (Low)
							else if (bytecounter == 8'd20) data_out <= 8'h7B; // CRC Byte 2 (High)

							else if (bytecounter == 8'd21) data_out <= 8'h00; // Drive 0 before STP
						end

					else if (request == GET_CONFIG_DESCRIPTOR_FULL || request == GET_CONFIG_DESCRIPTOR_255BYTES) begin
            
            if (config_descriptor_packet_counter == 3'b000) begin
              // --- PART 1: CONFIGURATION DESCRIPTOR (9 bytes) ---
              if      (bytecounter == 8'd1)  data_out <= 8'h09; // bLength
              else if (bytecounter == 8'd2)  data_out <= 8'h02; // bDescriptorType (Configuration)
              else if (bytecounter == 8'd3)  data_out <= 8'h01; // wTotalLength (Low) - 257 bytes
              else if (bytecounter == 8'd4)  data_out <= 8'h01; // wTotalLength (High)
              else if (bytecounter == 8'd5)  data_out <= 8'h04; // bNumInterfaces (4)
              else if (bytecounter == 8'd6)  data_out <= 8'h01; // bConfigurationValue (1)
              else if (bytecounter == 8'd7)  data_out <= 8'h00; // iConfiguration (0)
              else if (bytecounter == 8'd8)  data_out <= 8'hC0; // bmAttributes (self powered)
              else if (bytecounter == 8'd9)  data_out <= 8'h00; // bMaxPower 

              // --- PART 2: INTERFACE ASSOCIATION DESCRIPTOR (8 bytes) ---
              else if (bytecounter == 8'd10)  data_out <= 8'h08; // bLength
              else if (bytecounter == 8'd11)  data_out <= 8'h0B; // bDescriptorType (IAD)
              else if (bytecounter == 8'd12)  data_out <= 8'h00; // bFirstInterface (0)
              else if (bytecounter == 8'd13)  data_out <= 8'h02; // bInterfaceCount (2 interfaces bound together)
              else if (bytecounter == 8'd14)  data_out <= 8'h0E; // bFunctionClass (Video)
              else if (bytecounter == 8'd15)  data_out <= 8'h03; // bFunctionSubClass (Video Interface Collection)
              else if (bytecounter == 8'd16)  data_out <= 8'h00; // bFunctionProtocol (0)
              else if (bytecounter == 8'd17)  data_out <= 8'h00; // iFunction (0)

              // --- PART 3: VIDEO CONTROL INTERFACE (9 bytes) ---
              else if (bytecounter == 8'd18)  data_out <= 8'h09; // bLength
              else if (bytecounter == 8'd19)  data_out <= 8'h04; // bDescriptorType (Interface)
              else if (bytecounter == 8'd20)  data_out <= 8'h00; // bInterfaceNumber (0)
              else if (bytecounter == 8'd21)  data_out <= 8'h00; // bAlternateSetting (0)
              else if (bytecounter == 8'd22)  data_out <= 8'h00; // bNumEndpoints (0 - uses EP0)
              else if (bytecounter == 8'd23)  data_out <= 8'h0E; // bInterfaceClass (Video)
              else if (bytecounter == 8'd24)  data_out <= 8'h01; // bInterfaceSubClass (VideoControl)
              else if (bytecounter == 8'd25)  data_out <= 8'h00; // bInterfaceProtocol (0)
              else if (bytecounter == 8'd26)  data_out <= 8'h00; // iInterface (0)

              // --- PART 4: CLASS-SPECIFIC VC HEADER (13 bytes) ---
              else if (bytecounter == 8'd27)  data_out <= 8'h0D; // bLength
              else if (bytecounter == 8'd28)  data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd29)  data_out <= 8'h01; // bDescriptorSubtype (VC_HEADER)
              else if (bytecounter == 8'd30)  data_out <= 8'h00; // bcdUVC (Low - 1.00)
              else if (bytecounter == 8'd31)  data_out <= 8'h01; // bcdUVC (High)
              else if (bytecounter == 8'd32)  data_out <= 8'h25; // wTotalLength (Low - 37 bytes for VC block)
              else if (bytecounter == 8'd33)  data_out <= 8'h00; // wTotalLength (High)
              else if (bytecounter == 8'd34)  data_out <= 8'h80; // dwClockFrequency (Filler)
              else if (bytecounter == 8'd35)  data_out <= 8'h8D; // dwClockFrequency
              else if (bytecounter == 8'd36)  data_out <= 8'h5B; // dwClockFrequency
              else if (bytecounter == 8'd37)  data_out <= 8'h00; // dwClockFrequency
              else if (bytecounter == 8'd38)  data_out <= 8'h01; // bInCollection (1 VS interface)
              else if (bytecounter == 8'd39)  data_out <= 8'h01; // baInterfaceNr (Interface 1)     

              // --- PART 5: VC INPUT TERMINAL / CAMERA SENSOR (15 bytes) ---
              else if (bytecounter == 8'd40)  data_out <= 8'h0F; // bLength
              else if (bytecounter == 8'd41)  data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd42)  data_out <= 8'h02; // bDescriptorSubtype (VC_INPUT_TERMINAL)
              else if (bytecounter == 8'd43)  data_out <= 8'h01; // bTerminalID (1)
              else if (bytecounter == 8'd44)  data_out <= 8'h01; // wTerminalType (Low - Camera Sensor 0x0202)
              else if (bytecounter == 8'd45)  data_out <= 8'h02; // wTerminalType (High)
              else if (bytecounter == 8'd46)  data_out <= 8'h00; // bAssocTerminal (0)
              else if (bytecounter == 8'd47)  data_out <= 8'h00; // iTerminal (0)
              else if (bytecounter == 8'd48)  data_out <= 8'h00; // wObjectiveFocalLength (Low)
              else if (bytecounter == 8'd49)  data_out <= 8'h00; // wObjectiveFocalLength (High)
              else if (bytecounter == 8'd50)  data_out <= 8'h00; // wOcularFocalLength (Low)
              else if (bytecounter == 8'd51)  data_out <= 8'h00; // wOcularFocalLength (High)
              else if (bytecounter == 8'd52)  data_out <= 8'h02; // bControlSize (0)
              else if (bytecounter == 8'd53)  data_out <= 8'h00; // bmControls
              else if (bytecounter == 8'd54)  data_out <= 8'h00; // bmControls      

              // --- PART 6: VC OUTPUT TERMINAL / USB STREAM (9 bytes) ---
              else if (bytecounter == 8'd55)  data_out <= 8'h09; // bLength
              else if (bytecounter == 8'd56)  data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd57)  data_out <= 8'h03; // bDescriptorSubtype (VC_OUTPUT_TERMINAL)
              else if (bytecounter == 8'd58)  data_out <= 8'h02; // bTerminalID (2)
              else if (bytecounter == 8'd59)  data_out <= 8'h01; // wTerminalType (Low - USB Streaming 0x0101)
              else if (bytecounter == 8'd60)  data_out <= 8'h01; // wTerminalType (High)
              else if (bytecounter == 8'd61)  data_out <= 8'h00; // bAssocTerminal (0)
              else if (bytecounter == 8'd62)  data_out <= 8'h01; // bSourceID (1 - points to Input Terminal)
              else if (bytecounter == 8'd63)  data_out <= 8'h00; // iTerminal (0)   

              // --- PART 7: VIDEO STREAMING INTERFACE (9 bytes) ---
              else if (bytecounter == 8'd64)   data_out <= 8'h09; // bLength                                     

              // --- CRC16 CHECKSUM ---
              else if (bytecounter == 8'd65) data_out <= 8'hB2; // CRC Byte 1 (Low) 
              else if (bytecounter == 8'd66) data_out <= 8'h54; // CRC Byte 2 (High)             

              // --- STOP PADDING ---
              else if (bytecounter == 8'd67) data_out <= 8'h00; // Drive 0 before STP			
            end	
            else if (config_descriptor_packet_counter == 3'b001) begin

              // --- PART 7: VIDEO STREAMING INTERFACE (9 bytes) - continued from first packet ---
              if (bytecounter == 8'd1)   data_out <= 8'h04; // bDescriptorType (Interface)
              else if (bytecounter == 8'd2)   data_out <= 8'h01; // bInterfaceNumber (1)
              else if (bytecounter == 8'd3)   data_out <= 8'h00; // bAlternateSetting (0)
              else if (bytecounter == 8'd4)  data_out <= 8'h00; // bNumEndpoints (0 - Zero Bandwidth!)
              else if (bytecounter == 8'd5)   data_out <= 8'h0E; // bInterfaceClass (Video)
              else if (bytecounter == 8'd6)   data_out <= 8'h02; // bInterfaceSubClass (VideoStreaming)
              else if (bytecounter == 8'd7)   data_out <= 8'h00; // bInterfaceProtocol (0)
              else if (bytecounter == 8'd8)   data_out <= 8'h00; // iInterface (0)

              // --- PART 8: CLASS-SPECIFIC VS HEADER (14 bytes) ---
              else if (bytecounter == 8'd9)  data_out <= 8'h0E; // bLength
              else if (bytecounter == 8'd10)  data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd11)  data_out <= 8'h01; // bDescriptorSubtype (VS_INPUT_HEADER)
              else if (bytecounter == 8'd12)  data_out <= 8'h01; // bNumFormats (1)
              else if (bytecounter == 8'd13)  data_out <= 8'h3D; // wTotalLength (Low - 61 bytes)
              else if (bytecounter == 8'd14)  data_out <= 8'h00; // wTotalLength (High)
              else if (bytecounter == 8'd15)  data_out <= 8'h81; // bEndpointAddress (EP1 IN)
              else if (bytecounter == 8'd16)  data_out <= 8'h00; // bmInfo
              else if (bytecounter == 8'd17)  data_out <= 8'h02; // bTerminalLink (2 - points to ID 2)
              else if (bytecounter == 8'd18)  data_out <= 8'h00; // bStillCaptureMethod (0)
              else if (bytecounter == 8'd19)  data_out <= 8'h00; // bTriggerSupport (0)
              else if (bytecounter == 8'd20)  data_out <= 8'h00; // bTriggerUsage (0)
              else if (bytecounter == 8'd21)  data_out <= 8'h01; // bControlSize (1)
              else if (bytecounter == 8'd22)  data_out <= 8'h00; // bmaControls

              // --- PART 9: VS FORMAT MJPEG (11 bytes) ---
              else if (bytecounter == 8'd23)  data_out <= 8'h0B; // bLength
              else if (bytecounter == 8'd24)  data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd25)  data_out <= 8'h06; // bDescriptorSubtype (VS_FORMAT_MJPEG)
              else if (bytecounter == 8'd26)  data_out <= 8'h01; // bFormatIndex (1)
              else if (bytecounter == 8'd27)  data_out <= 8'h01; // bNumFrameDescriptors (1)
              else if (bytecounter == 8'd28)  data_out <= 8'h01; // bmFlags (Fixed Framerate)
              else if (bytecounter == 8'd29)  data_out <= 8'h01; // bDefaultFrameIndex (1)
              else if (bytecounter == 8'd30)  data_out <= 8'h00; // bAspectRatioX (0)
              else if (bytecounter == 8'd31)  data_out <= 8'h00; // bAspectRatioY (0)
              else if (bytecounter == 8'd32)  data_out <= 8'h00; // bmInterlaceFlags (0)
              else if (bytecounter == 8'd33)  data_out <= 8'h00; // bCopyProtect (0) 

              // --- PART 10: VS FRAME MJPEG ---
              else if (bytecounter == 8'd34)   data_out <= 8'h1E; // bLength
              else if (bytecounter == 8'd35)   data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd36)   data_out <= 8'h07; // bDescriptorSubtype (VS_FRAME_MJPEG)
              else if (bytecounter == 8'd37)   data_out <= 8'h01; // bFrameIndex (1)
              else if (bytecounter == 8'd38)   data_out <= 8'h00; // bmCapabilities (0)

            `ifdef HDMI_720p60
              else if (bytecounter == 8'd39)   data_out <= 8'h00; // wWidth (Low - 1280)
              else if (bytecounter == 8'd40)   data_out <= 8'h05; // wWidth (High)
              else if (bytecounter == 8'd41)   data_out <= 8'hD0; // wHeight (Low - 720)
              else if (bytecounter == 8'd42)   data_out <= 8'h02; // wHeight (High)
            `elsif HDMI_1080p30
              else if (bytecounter == 8'd39)   data_out <= 8'h00; // wWidth (Low - 1920)
              else if (bytecounter == 8'd40)   data_out <= 8'h07; // wWidth (High)
              else if (bytecounter == 8'd41)   data_out <= 8'h38; // wHeight (Low - 1080)
              else if (bytecounter == 8'd42)   data_out <= 8'h04; // wHeight (High)
            `endif

              else if (bytecounter == 8'd43)  data_out <= 8'h00; // dwMinBitRate (Low)
              else if (bytecounter == 8'd44)  data_out <= 8'h1C; // dwMinBitRate
              else if (bytecounter == 8'd45)  data_out <= 8'h4E; // dwMinBitRate
              else if (bytecounter == 8'd46)  data_out <= 8'h0E; // dwMinBitRate (High - 240Mbps)
              else if (bytecounter == 8'd47)  data_out <= 8'h00; // dwMaxBitRate (Low)
              else if (bytecounter == 8'd48)  data_out <= 8'h1C; // dwMaxBitRate
              else if (bytecounter == 8'd49)  data_out <= 8'h4E; // dwMaxBitRate
              else if (bytecounter == 8'd50)  data_out <= 8'h0E; // dwMaxBitRate (High - 240Mbps)

            `ifdef HDMI_720p60
              else if (bytecounter == 8'd51)  data_out <= 8'h20; // dwMaxVideoFrameBufferSize (Low)
              else if (bytecounter == 8'd52)  data_out <= 8'hA1; // dwMaxVideoFrameBufferSize 
              else if (bytecounter == 8'd53)  data_out <= 8'h07; // dwMaxVideoFrameBufferSize 
              else if (bytecounter == 8'd54)  data_out <= 8'h00; // dwMaxVideoFrameBufferSize (High - 500,000 bytes)
            `elsif HDMI_1080p30
              else if (bytecounter == 8'd51)  data_out <= 8'h40; // dwMaxVideoFrameBufferSize (Low)
              else if (bytecounter == 8'd52)  data_out <= 8'h42; // dwMaxVideoFrameBufferSize 
              else if (bytecounter == 8'd53)  data_out <= 8'h0F; // dwMaxVideoFrameBufferSize 
              else if (bytecounter == 8'd54)  data_out <= 8'h00; // dwMaxVideoFrameBufferSize (High - 1,000,000 bytes)
            `endif 

            `ifdef HDMI_720p60
              else if (bytecounter == 8'd55)  data_out <= 8'h0A; // dwDefaultFrameInterval (Low)
              else if (bytecounter == 8'd56)  data_out <= 8'h8B; // dwDefaultFrameInterval
              else if (bytecounter == 8'd57)  data_out <= 8'h02; // dwDefaultFrameInterval
              else if (bytecounter == 8'd58)  data_out <= 8'h00; // dwDefaultFrameInterval (High - 60fps)
              else if (bytecounter == 8'd59)  data_out <= 8'h01; // bFrameIntervalType (1 discrete framerate)
              else if (bytecounter == 8'd60)  data_out <= 8'h0A; // dwFrameInterval (Low)
              else if (bytecounter == 8'd61)  data_out <= 8'h8B; // dwFrameInterval
              else if (bytecounter == 8'd62)  data_out <= 8'h02; // dwFrameInterval
              else if (bytecounter == 8'd63)  data_out <= 8'h00; // dwFrameInterval (High - 60fps)   
            `elsif HDMI_1080p30
              else if (bytecounter == 8'd55)  data_out <= 8'h15; // dwDefaultFrameInterval (Low)
              else if (bytecounter == 8'd56)  data_out <= 8'h16; // dwDefaultFrameInterval
              else if (bytecounter == 8'd57)  data_out <= 8'h05; // dwDefaultFrameInterval
              else if (bytecounter == 8'd58)  data_out <= 8'h00; // dwDefaultFrameInterval (High - 30fps)
              else if (bytecounter == 8'd59)  data_out <= 8'h01; // bFrameIntervalType (1 discrete framerate)
              else if (bytecounter == 8'd60)  data_out <= 8'h15; // dwFrameInterval (Low)
              else if (bytecounter == 8'd61)  data_out <= 8'h16; // dwFrameInterval
              else if (bytecounter == 8'd62)  data_out <= 8'h05; // dwFrameInterval
              else if (bytecounter == 8'd63)  data_out <= 8'h00; // dwFrameInterval (High - 60fps)  
            `endif

              // --- PART 11: VS COLOR MATCHING (6 bytes) ---
              else if (bytecounter == 8'd64)  data_out <= 8'h06; // bLength                               


              // --- CRC16 CHECKSUM ---
            `ifdef HDMI_720p60
              else if (bytecounter == 8'd65) data_out <= 8'hC3; // CRC Byte 1 (Low) 
              else if (bytecounter == 8'd66) data_out <= 8'h61; // CRC Byte 2 (High)
            `elsif HDMI_1080p30
              else if (bytecounter == 8'd65) data_out <= 8'h9D; // CRC Byte 1 (Low) 
              else if (bytecounter == 8'd66) data_out <= 8'h86; // CRC Byte 2 (High)
            `endif 

              // --- STOP PADDING ---
              else if (bytecounter == 8'd67) data_out <= 8'h00; // Drive 0 before STP			                     
            end
            else if (config_descriptor_packet_counter == 3'b010) begin// if == 3'b010

              // --- PART 11: VS COLOR MATCHING (6 bytes) - continued from packet 2 ---
              if (bytecounter == 8'd1)  data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd2)  data_out <= 8'h0D; // bDescriptorSubtype (VS_COLORFORMAT)
              else if (bytecounter == 8'd3)  data_out <= 8'h01; // bColorPrimaries (BT.709)
              else if (bytecounter == 8'd4)  data_out <= 8'h01; // bTransferCharacteristics (BT.709)
              else if (bytecounter == 8'd5)  data_out <= 8'h04; // bMatrixCoefficients (SMPTE 170M)

              // --- NEW PART: VS INTERFACE (ALT SETTING 1) (9 bytes) ---
              else if (bytecounter == 8'd6)  data_out <= 8'h09; // bLength
              else if (bytecounter == 8'd7)  data_out <= 8'h04; // bDescriptorType (Interface)
              else if (bytecounter == 8'd8)  data_out <= 8'h01; // bInterfaceNumber (1)
              else if (bytecounter == 8'd9)  data_out <= 8'h01; // bAlternateSetting (1 - Active ISOC!)
              else if (bytecounter == 8'd10) data_out <= 8'h01; // bNumEndpoints (1 ISOC IN)
              else if (bytecounter == 8'd11) data_out <= 8'h0E; // bInterfaceClass (Video)
              else if (bytecounter == 8'd12) data_out <= 8'h02; // bInterfaceSubClass (VideoStreaming)
              else if (bytecounter == 8'd13) data_out <= 8'h00; // bInterfaceProtocol (0)
              else if (bytecounter == 8'd14) data_out <= 8'h00; // iInterface (0)

              // --- PART 12: STANDARD ENDPOINT DESCRIPTOR (7 bytes) ---
              else if (bytecounter == 8'd15) data_out <= 8'h07; // bLength
              else if (bytecounter == 8'd16) data_out <= 8'h05; // bDescriptorType (Endpoint)
              else if (bytecounter == 8'd17) data_out <= 8'h81; // bEndpointAddress (EP1 IN)
              else if (bytecounter == 8'd18) data_out <= 8'h05; // bmAttributes (0x05 = Isochronous + Asynchronous)
              else if (bytecounter == 8'd19) data_out <= 8'h00; // wMaxPacketSize (Low)
              else if (bytecounter == 8'd20) data_out <= 8'h14; // wMaxPacketSize (High - 1024 bytes)
              else if (bytecounter == 8'd21) data_out <= 8'h01; // bInterval (1 = 1 microframe = 125us) 

              // --- PART 13: AUDIO IAD (8 bytes) ---
              else if (bytecounter == 8'd22) data_out <= 8'h08; // bLength
              else if (bytecounter == 8'd23) data_out <= 8'h0B; // bDescriptorType (IAD)
              else if (bytecounter == 8'd24) data_out <= 8'h02; // bFirstInterface (Interface 2)
              else if (bytecounter == 8'd25) data_out <= 8'h02; // bInterfaceCount (2 interfaces: Audio Control & Audio Streaming)
              else if (bytecounter == 8'd26) data_out <= 8'h01; // bFunctionClass (Audio)
              else if (bytecounter == 8'd27) data_out <= 8'h01; // bFunctionSubClass (AudioControl)
              else if (bytecounter == 8'd28) data_out <= 8'h00; // bFunctionProtocol (0)
              else if (bytecounter == 8'd29) data_out <= 8'h00; // iFunction (0)

              // --- PART 14: AUDIO CONTROL INTERFACE (9 bytes) ---
              else if (bytecounter == 8'd30) data_out <= 8'h09; // bLength
              else if (bytecounter == 8'd31) data_out <= 8'h04; // bDescriptorType (Interface)
              else if (bytecounter == 8'd32) data_out <= 8'h02; // bInterfaceNumber (2)
              else if (bytecounter == 8'd33) data_out <= 8'h00; // bAlternateSetting (0)
              else if (bytecounter == 8'd34) data_out <= 8'h00; // bNumEndpoints (0 - Uses EP0)
              else if (bytecounter == 8'd35) data_out <= 8'h01; // bInterfaceClass (Audio)
              else if (bytecounter == 8'd36) data_out <= 8'h01; // bInterfaceSubClass (AudioControl)
              else if (bytecounter == 8'd37) data_out <= 8'h00; // bInterfaceProtocol (0)
              else if (bytecounter == 8'd38) data_out <= 8'h00; // iInterface (0)

              // --- PART 15: AC HEADER (9 bytes) ---
              else if (bytecounter == 8'd39) data_out <= 8'h09; // bLength
              else if (bytecounter == 8'd40) data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd41) data_out <= 8'h01; // bDescriptorSubtype (HEADER)
              else if (bytecounter == 8'd42) data_out <= 8'h00; // bcdADC (Low - 1.00)
              else if (bytecounter == 8'd43) data_out <= 8'h01; // bcdADC (High)
              else if (bytecounter == 8'd44) data_out <= 8'h27; // wTotalLength (Low - 39 bytes for this AC block)
              else if (bytecounter == 8'd45) data_out <= 8'h00; // wTotalLength (High)
              else if (bytecounter == 8'd46) data_out <= 8'h01; // bInCollection (1 AudioStreaming interface)
              else if (bytecounter == 8'd47) data_out <= 8'h03; // baInterfaceNr (Interface 3 is the stream)

              // --- PART 16: AC INPUT TERMINAL - MICROPHONE (12 bytes) ---
              else if (bytecounter == 8'd48) data_out <= 8'h0C; // bLength
              else if (bytecounter == 8'd49) data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd50) data_out <= 8'h02; // bDescriptorSubtype (INPUT_TERMINAL)
              else if (bytecounter == 8'd51) data_out <= 8'h03; // bTerminalID (3)
              else if (bytecounter == 8'd52) data_out <= 8'h01; // wTerminalType (Low - 0x0201 Microphone)
              else if (bytecounter == 8'd53) data_out <= 8'h02; // wTerminalType (High)
              else if (bytecounter == 8'd54) data_out <= 8'h00; // bAssocTerminal (0)
              else if (bytecounter == 8'd55) data_out <= 8'h01; // bNrChannels (1 Channel - Mono)
              else if (bytecounter == 8'd56) data_out <= 8'h00; // wChannelConfig (Low)
              else if (bytecounter == 8'd57) data_out <= 8'h00; // wChannelConfig (High)
              else if (bytecounter == 8'd58) data_out <= 8'h00; // iChannelNames (0)
              else if (bytecounter == 8'd59) data_out <= 8'h00; // iTerminal (0)

              // --- NEW PART: FEATURE UNIT (9 bytes total, first 5 bytes here) ---
              else if (bytecounter == 8'd60) data_out <= 8'h09; // bLength
              else if (bytecounter == 8'd61) data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd62) data_out <= 8'h06; // bDescriptorSubtype (FEATURE_UNIT)
              else if (bytecounter == 8'd63) data_out <= 8'h04; // bUnitID (4 - Our new Feature Unit)
              else if (bytecounter == 8'd64) data_out <= 8'h03; // bSourceID (3 - Linked to Microphone Terminal)

              // --- CRC16 CHECKSUM FOR PACKET 2 ---
              else if (bytecounter == 8'd65) data_out <= 8'h42; // CRC Byte 1
              else if (bytecounter == 8'd66) data_out <= 8'hBB; // CRC Byte 2

              else if (bytecounter == 8'd67) data_out <= 8'h00; // Drive 0 before STP
            end                   

            else if (config_descriptor_packet_counter == 3'b011) begin

              // --- NEW PART: FEATURE UNIT (Last 4 bytes) ---
              if      (bytecounter == 8'd1)  data_out <= 8'h01; // bControlSize (1 byte per control)
              else if (bytecounter == 8'd2)  data_out <= 8'h03; // bmaControls[0] (Master: Mute & Volume!)
              else if (bytecounter == 8'd3)  data_out <= 8'h00; // bmaControls[1] (Channel 0: None)
              else if (bytecounter == 8'd4)  data_out <= 8'h00; // iFeature (0)            

              // --- PART 17: AC OUTPUT TERMINAL - USB (9 bytes) ---
              else if (bytecounter == 8'd5) data_out <= 8'h09; // bLength
              else if (bytecounter == 8'd6) data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd7) data_out <= 8'h03; // bDescriptorSubtype (OUTPUT_TERMINAL)
              else if (bytecounter == 8'd8) data_out <= 8'h05; // bTerminalID (5)
              else if (bytecounter == 8'd9) data_out <= 8'h01; // wTerminalType (Low - 0x0101 USB Streaming)                     
              else if (bytecounter == 8'd10) data_out <= 8'h01;  // wTerminalType (High)
              else if (bytecounter == 8'd11) data_out <= 8'h00;  // bAssocTerminal (0)
              else if (bytecounter == 8'd12) data_out <= 8'h04;  // bSourceID (4 - Linked to Feature Unit)
              else if (bytecounter == 8'd13) data_out <= 8'h00;  // iTerminal (0)

              // --- PART 18: AUDIO STREAMING INTERFACE - ALT 0 (9 bytes) ---
              else if (bytecounter == 8'd14) data_out <= 8'h09;  // bLength
              else if (bytecounter == 8'd15) data_out <= 8'h04;  // bDescriptorType (Interface)
              else if (bytecounter == 8'd16) data_out <= 8'h03;  // bInterfaceNumber (3)
              else if (bytecounter == 8'd17) data_out <= 8'h00;  // bAlternateSetting (0 - Zero Bandwidth)
              else if (bytecounter == 8'd18) data_out <= 8'h00;  // bNumEndpoints (0)
              else if (bytecounter == 8'd19) data_out <= 8'h01; // bInterfaceClass (Audio)
              else if (bytecounter == 8'd20) data_out <= 8'h02; // bInterfaceSubClass (AudioStreaming)
              else if (bytecounter == 8'd21) data_out <= 8'h00; // bInterfaceProtocol (0)
              else if (bytecounter == 8'd22) data_out <= 8'h00; // iInterface (0)

              // --- PART 19: AUDIO STREAMING INTERFACE - ALT 1 (9 bytes) ---
              else if (bytecounter == 8'd23) data_out <= 8'h09; // bLength
              else if (bytecounter == 8'd24) data_out <= 8'h04; // bDescriptorType (Interface)
              else if (bytecounter == 8'd25) data_out <= 8'h03; // bInterfaceNumber (3)
              else if (bytecounter == 8'd26) data_out <= 8'h01; // bAlternateSetting (1 - Active Bandwidth)
              else if (bytecounter == 8'd27) data_out <= 8'h01; // bNumEndpoints (1 ISOC IN)
              else if (bytecounter == 8'd28) data_out <= 8'h01; // bInterfaceClass (Audio)
              else if (bytecounter == 8'd29) data_out <= 8'h02; // bInterfaceSubClass (AudioStreaming)
              else if (bytecounter == 8'd30) data_out <= 8'h00; // bInterfaceProtocol (0)
              else if (bytecounter == 8'd31) data_out <= 8'h00; // iInterface (0)

              // --- PART 20: AS GENERAL HEADER (7 bytes) ---
              else if (bytecounter == 8'd32) data_out <= 8'h07; // bLength
              else if (bytecounter == 8'd33) data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd34) data_out <= 8'h01; // bDescriptorSubtype (AS_GENERAL)
              else if (bytecounter == 8'd35) data_out <= 8'h05; // bTerminalLink (5 - Linked to Output Terminal)
              else if (bytecounter == 8'd36) data_out <= 8'h01; // bDelay (1 frame)
              else if (bytecounter == 8'd37) data_out <= 8'h01; // wFormatTag (Low - 0x0001 PCM)
              else if (bytecounter == 8'd38) data_out <= 8'h00; // wFormatTag (High)

              // --- PART 21: AS FORMAT TYPE I - PCM 48kHz (11 bytes) ---
              else if (bytecounter == 8'd39) data_out <= 8'h0B; // bLength
              else if (bytecounter == 8'd40) data_out <= 8'h24; // bDescriptorType (CS_INTERFACE)
              else if (bytecounter == 8'd41) data_out <= 8'h02; // bDescriptorSubtype (FORMAT_TYPE)
              else if (bytecounter == 8'd42) data_out <= 8'h01; // bFormatType (Type I)
              else if (bytecounter == 8'd43) data_out <= 8'h01; // bNrChannels (1 - Mono)
              else if (bytecounter == 8'd44) data_out <= 8'h02; // bSubframeSize (2 bytes = 16 bit)
              else if (bytecounter == 8'd45) data_out <= 8'h10; // bBitResolution (16 bits)
              else if (bytecounter == 8'd46) data_out <= 8'h01; // bSamFreqType (1 discrete frequency)
              else if (bytecounter == 8'd47) data_out <= 8'h80; // tSamFreq (Low - 0x00BB80 = 48,000 Hz)
              else if (bytecounter == 8'd48) data_out <= 8'hBB; // tSamFreq (Mid)
              else if (bytecounter == 8'd49) data_out <= 8'h00; // tSamFreq (High)

              // --- PART 22: STANDARD ISOCHRONOUS AUDIO ENDPOINT (9 bytes) ---
              else if (bytecounter == 8'd50) data_out <= 8'h09; // bLength
              else if (bytecounter == 8'd51) data_out <= 8'h05; // bDescriptorType (Endpoint)
              else if (bytecounter == 8'd52) data_out <= 8'h82; // bEndpointAddress (EP2 IN)
              else if (bytecounter == 8'd53) data_out <= 8'h05; // bmAttributes (Isochronous, Asynchronous)
              else if (bytecounter == 8'd54) data_out <= 8'h64; // wMaxPacketSize (Low - 12 bytes/uFrame)
              else if (bytecounter == 8'd55) data_out <= 8'h00; // wMaxPacketSize (High)
              else if (bytecounter == 8'd56) data_out <= 8'h04; // bInterval (4 microframes)
              else if (bytecounter == 8'd57) data_out <= 8'h00; // bRefresh (0)
              else if (bytecounter == 8'd58) data_out <= 8'h00; // bSynchAddress (0)

              // --- PART 23: CLASS-SPECIFIC ISOCHRONOUS AUDIO ENDPOINT (7 bytes) ---
              else if (bytecounter == 8'd59) data_out <= 8'h07; // bLength
              else if (bytecounter == 8'd60) data_out <= 8'h25; // bDescriptorType (CS_ENDPOINT)
              else if (bytecounter == 8'd61) data_out <= 8'h01; // bDescriptorSubtype (EP_GENERAL)
              else if (bytecounter == 8'd62) data_out <= 8'h00; // bmAttributes (0)
              else if (bytecounter == 8'd63) data_out <= 8'h00; // bLockDelayUnits (0)

              if (request == GET_CONFIG_DESCRIPTOR_255BYTES) begin
                // else if (bytecounter == 8'd64) data_out <= 8'h00; // wLockDelay (Low)

                // --- CRC16 CHECKSUM FOR FINAL PACKET 3 ---
                if (bytecounter == 8'd64) data_out <= 8'h7E; // CRC Byte 1 (Low)
                else if (bytecounter == 8'd65) data_out <= 8'hF8; // CRC Byte 2 (High)

                // --- STOP PADDING ---
                else if (bytecounter == 8'd66) data_out <= 8'h00; // Drive 0 before STP
              end
              else begin 
                if (bytecounter == 8'd64) data_out <= 8'h00; // wLockDelay (Low)

                // --- CRC16 CHECKSUM FOR FINAL PACKET 3 ---
                else if (bytecounter == 8'd65) data_out <= 8'h38; // CRC Byte 1 (Low)
                else if (bytecounter == 8'd66) data_out <= 8'h9F; // CRC Byte 2 (High)

                // --- STOP PADDING ---
                else if (bytecounter == 8'd67) data_out <= 8'h00; // Drive 0 before STP
              end
            end  

            else if (request == GET_CONFIG_DESCRIPTOR_FULL && config_descriptor_packet_counter == 3'd4) begin
            
              // --- PART 23: CLASS-SPECIFIC EP (Final Byte) ---
              if      (bytecounter == 8'd1)  data_out <= 8'h00; // wLockDelay (High)

              else if (bytecounter == 8'd2)  data_out <= 8'h40; // CRC Low
              else if (bytecounter == 8'd3)  data_out <= 8'hBF; // CRC High

              // --- STOP PADDING ---
              else if (bytecounter == 8'd4)  data_out <= 8'h00; // Drive 0 before STP
            end
          end

					else if (request == GET_CONFIG_DESCRIPTOR_9BYTES) begin // get descriptor config, first 9 bytes only //

						// --- PART 1: CONFIGURATION DESCRIPTOR (9 bytes) ---
            if      (bytecounter == 8'd1)  data_out <= 8'h09; // bLength
            else if (bytecounter == 8'd2)  data_out <= 8'h02; // bDescriptorType (Configuration)
            else if (bytecounter == 8'd3)  data_out <= 8'h01; // wTotalLength (Low) - 257 bytes
            else if (bytecounter == 8'd4)  data_out <= 8'h01; // wTotalLength (High)
            else if (bytecounter == 8'd5)  data_out <= 8'h04; // bNumInterfaces (4)
            else if (bytecounter == 8'd6)  data_out <= 8'h01; // bConfigurationValue (1)
            else if (bytecounter == 8'd7)  data_out <= 8'h00; // iConfiguration (0)
            else if (bytecounter == 8'd8)  data_out <= 8'hC0; // bmAttributes (self powered)
            else if (bytecounter == 8'd9)  data_out <= 8'h00; // bMaxPower 

						// --- CRC16 CHECKSUM ---
						// See instructions below to calculate these two bytes!
						else if (bytecounter == 8'd10) data_out <= 8'hAF; // CRC Byte 1 (Low) 
						else if (bytecounter == 8'd11) data_out <= 8'hAB; // CRC Byte 2 (High)

						// --- STOP PADDING ---
						else if (bytecounter == 8'd12) data_out <= 8'h00; // Drive 0 before STP			
					end		

          else if (request == GET_CUR_VIDEO_PROBE || request == GET_MIN_VIDEO_PROBE || request == GET_MAX_VIDEO_PROBE) begin
              
            // --- UVC PROBE RESPONSE (26 Bytes) ---
            if      (bytecounter == 8'd1)  data_out <= 8'h01; // bmHint (Low) - Keep frame format
            else if (bytecounter == 8'd2)  data_out <= 8'h00; // bmHint (High)
            
            else if (bytecounter == 8'd3)  data_out <= 8'h01; // bFormatIndex (1 = MJPEG)
            
            else if (bytecounter == 8'd4)  data_out <= 8'h01; // bFrameIndex (1 = 720p)
            
          `ifdef HDMI_720p60
            else if (bytecounter == 8'd5)  data_out <= 8'h0A; // dwFrameInterval (Byte 0) - 60fps
            else if (bytecounter == 8'd6)  data_out <= 8'h8B; // dwFrameInterval (Byte 1)
            else if (bytecounter == 8'd7)  data_out <= 8'h02; // dwFrameInterval (Byte 2)
            else if (bytecounter == 8'd8)  data_out <= 8'h00; // dwFrameInterval (Byte 3)
          `elsif HDMI_1080p30
            else if (bytecounter == 8'd5)  data_out <= 8'h40; // dwFrameInterval (Byte 0) - 60fps
            else if (bytecounter == 8'd6)  data_out <= 8'h42; // dwFrameInterval (Byte 1)
            else if (bytecounter == 8'd7)  data_out <= 8'h0F; // dwFrameInterval (Byte 2)
            else if (bytecounter == 8'd8)  data_out <= 8'h00; // dwFrameInterval (Byte 3)
          `endif       

            else if (bytecounter == 8'd9)  data_out <= 8'h00; // wKeyFrameRate (Low)
            else if (bytecounter == 8'd10) data_out <= 8'h00; // wKeyFrameRate (High)
            
            else if (bytecounter == 8'd11) data_out <= 8'h00; // wPFrameRate (Low)
            else if (bytecounter == 8'd12) data_out <= 8'h00; // wPFrameRate (High)
            
            else if (bytecounter == 8'd13) data_out <= 8'h00; // wCompQuality (Low)
            else if (bytecounter == 8'd14) data_out <= 8'h00; // wCompQuality (High)
            
            else if (bytecounter == 8'd15) data_out <= 8'h00; // wCompWindowSize (Low)
            else if (bytecounter == 8'd16) data_out <= 8'h00; // wCompWindowSize (High)
            
            else if (bytecounter == 8'd17) data_out <= 8'h00; // wDelay (Low)
            else if (bytecounter == 8'd18) data_out <= 8'h00; // wDelay (High)
            
            else if (bytecounter == 8'd19) data_out <= 8'h20; // dwMaxVideoFrameSize (Byte 0) - 500,000 bytes
            else if (bytecounter == 8'd20) data_out <= 8'hA1; // dwMaxVideoFrameSize (Byte 1)
            else if (bytecounter == 8'd21) data_out <= 8'h07; // dwMaxVideoFrameSize (Byte 2)
            else if (bytecounter == 8'd22) data_out <= 8'h00; // dwMaxVideoFrameSize (Byte 3)
            
            else if (bytecounter == 8'd23) data_out <= 8'h00; // dwMaxPayloadTransferSize (Byte 0) - 512 bytes
            else if (bytecounter == 8'd24) data_out <= 8'h02; // dwMaxPayloadTransferSize (Byte 1)
            else if (bytecounter == 8'd25) data_out <= 8'h00; // dwMaxPayloadTransferSize (Byte 2)
            else if (bytecounter == 8'd26) data_out <= 8'h00; // dwMaxPayloadTransferSize (Byte 3)
            
            // --- CRC16 GOES HERE ---
          `ifdef HDMI_720p60
            else if (bytecounter == 8'd27) data_out <= 8'h91; // (Calculate CRC for these 26 bytes)
            else if (bytecounter == 8'd28) data_out <= 8'h64; 
          `elsif HDMI_1080p30
            else if (bytecounter == 8'd27) data_out <= 8'h9A; // (Calculate CRC for these 26 bytes)
            else if (bytecounter == 8'd28) data_out <= 8'hA6; 
          `endif

            else if (bytecounter == 8'd29) data_out <= 8'h00; // STP Padding
          end

          else if (request == GET_CUR_AUDIO_MUTE) begin
            if      (bytecounter == 8'd1) data_out <= 8'h00; // Unmuted!
            else if (bytecounter == 8'd2) data_out <= 8'h40; // CRC Low for 0x00
            else if (bytecounter == 8'd3) data_out <= 8'hBF; // CRC High for 0x00
            else if (bytecounter == 8'd4) data_out <= 8'h00; // Stop padding
          end

          else if (request == GET_CUR_AUDIO_VOL || request == GET_MIN_AUDIO_VOL || request == GET_MAX_AUDIO_VOL) begin
            if      (bytecounter == 8'd1) data_out <= 8'h00; // Vol LSB
            else if (bytecounter == 8'd2) data_out <= 8'h00; // Vol MSB (0x0000 = 0 dB)
            else if (bytecounter == 8'd3) data_out <= 8'hFE; // CRC Low 
            else if (bytecounter == 8'd4) data_out <= 8'h4F; // CRC High 
            else if (bytecounter == 8'd5) data_out <= 8'h00; // Stop padding
          end          

          else if (request == GET_RES) begin
            if      (bytecounter == 8'd1) data_out <= 8'h00; // Step Size LSB
            else if (bytecounter == 8'd2) data_out <= 8'h01; // Step Size MSB (1 Step)
            else if (bytecounter == 8'd3) data_out <= 8'h3F; // CRC Low 
            else if (bytecounter == 8'd4) data_out <= 8'h8F; // CRC High 
            else if (bytecounter == 8'd5) data_out <= 8'h00; // Stop padding
          end          

				end	
    end
end

endmodule