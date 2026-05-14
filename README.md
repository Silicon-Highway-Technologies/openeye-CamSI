## FPGA-ISP-UVC-USB2 Project

<p align="center">
   <img width="230" src="0.doc/artwork/sihi_logo.png" style="margin-right: 20px;">
   <img width="240" src="0.doc/artwork/open-eye-logo.png">
</p>

### Project Overview 

The **USB UVC project** is designed to create an innovative and adaptable webcam that easily connects to any laptop, providing **high-quality video without the need for special drivers**. Unlike ordinary USB webcams that often come with proprietary software and limited functionality, this project aims to deliver a flexible, open-source solution that can be tailored and improved by anyone. The webcam will offer superior video quality with features like automatic brightness adjustment, color correction, and real-time video compression, making it ideal for video calls, streaming, and other visual applications. By focusing on open-source principles, this project ensures that the technology is accessible, modifiable, and transparent, allowing for continuous community-driven enhancements. 

The technical objective of the project is to capture MIPI CSI2 image data from image sensors—specifically the `Sony IMX219` and `OmniVision OV2740`—along with audio from a microphone. The system will transmit both video and audio streams to a USB host (e.g., a PC) via a **USB 2.0 interface**. 

Before transmission, the image data will undergo basic processing, such as:
- Auto white balance
- Color correction
- Gamma correction

To reduce bandwidth requirements between the FPGA and the USB interface, the processed images will be **JPEG-compressed**. The final output will consist of two separate (unsynchronized) **audio and video streams**, delivered over USB 2.0 to the host device. 

#### About OpenEye

The flow of the original Openeye project is described in [this block diagram](/0.doc/FPGA-Block-Diagram.png).  

Important modules include: 

- `i2c`, which writes the configuration of the I2C registers, so that the sensor can start up and be tuned to the desired settings.  

- `csi_rx`, which is responsible for the transmission of the data from the sensor through the MIPI interface. 

- `isp`, which currently includes only the module `raw2rgb`, which translates raw data (received from MIPI) to RGB pixel data (represented with 8 bits). The Simple Color Balance algorithm will be instantiated here soon.

- `rgb2hdmi` includes an ASYNC fifo which buffers each line and sends the data to HDMI.

- `hdmi_top` which configures the data transmission through HDMI.

## Objective I 
### Validate Basic development hardware Setup 

The target of this part is to validate and familiarize with the implementation provided by https://github.com/chili-chips-ba/openeye-CamSI/tree/main with `2-lane RPiV2.1`, based on `Sony IMX219`. 

#### Used Hardware 

- 2-lane RPiV2.1, based on Sony IMX219 sensor 

- PuZhi PZ-A7100T Starlite Evaluation Kit Xilinx Artix-7 XC7A100T FPGA Development Board Core Board MIPI

<p align="center">
   <img width="500" src="0.doc\pictures_sihi\puzhiboard.png">
</p>

<p align="center">
   <img width="500" src="0.doc/pictures_sihi/imx219.png">
</p>

#### Connectivity Incompatibility

The `Puzhi PZ-A7100T Starlite Evaluation Kit` features a **0.5 mm-pitch CSI (Camera Serial Interface) connector**, whereas the `Raspberry Pi` camera module uses a **1.0 mm FFC (Flat Flexible Cable) pitch**. 

To resolve this, a **pitch adapter or a custom interposer board** is typically required, adding design complexity and potential signal integrity concerns. This highlights the importance of verifying interface compatibility early in the hardware development process to avoid costly rework or integration issues. 

<p align="center">
   <img width="500" src="0.doc/pictures_sihi/05mm_1mm.png">
</p>

To bridge the pitch mismatch between the `Raspberry Pi` camera module and the `Puzhi PZ-A7100T Starlite Evaluation Kit`, we employ a **two-stage breakout solution**:
- The first breakout board accepts the camera's `1.0 mm-pitch FFC` and breaks out the CSI signals to accessible headers or pads.
- The second board receives these signals and routes them to a `0.5 mm-pitch FFC connector` compatible with the FPGA’s CSI interface. 

While this solution enables interconnection without custom PCB design, it introduces additional signal routing, which may affect signal integrity. Careful consideration of trace length, impedance matching, and shielding is necessary to maintain CSI signal quality. 

<p align="center">
   <img width="140" src="0.doc/pictures_sihi/setup1.png">
   <img width="130" src="0.doc/pictures_sihi/setup2.png">
   <img width="200" src="0.doc/pictures_sihi/setup3.png">
</p>

The following pictures show an overview of the entire setup: 

<p align="center">
   <img width="500" src="0.doc/pictures_sihi/setupdiagram.png">
</p>

<p align="center">
   <img width="500" src="0.doc/pictures_sihi/setupphoto.png">
</p>

**Investigated Resolutions:**

- [x] 1280x720p @ 60Hz
- [x] 1920x1080p @ 30Hz
- [x] 1920x1080p @ 60Hz (Not Supported)

The resolution can be chosen in the file [top_pkg.sv](/1.hw/top_pkg.sv).

#### 1280x720p @ 60Hz

After setting up the hardware connection, the first resolution could be tested straight away, as it was already configured and validated by the original contributors. 

We encountered a visual bug, that caused the visible screen to be split by a vertical line, start from the middle and then wrap around. We had to perform a hack in the code of the HDMI backend module to overcome this issue, which might be caused either from monitor inconsistency or from an original oversight on the HDMI module. 

<p align="center">
   <img width="500" src="0.doc/pictures_sihi/visualhdmibug.jpg">
</p>


During our debugging efforts, we familiarized ourselves with the I2C register configuration, explained in the [IMX219 manual](https://www.opensourceinstruments.com/Electronics/Data/IMX219PQ.pdf). Multiple registers are set, including:

- `0x0301` - `0x030d`, which are associated with the clock network of IMX219 and have to be set correctly to achieve the required frequencies for the MIPI clock and pixel clock.
- `0x0160-0161` and `0x0162-0163`, which set the frame length (in lines) and the line length (in pixels) that the sensor reads. The line length is, by default, 3448 pixels.
- `0x0164` - `0x016b`, which set the starting and ending horizontal and vertical points of the visible pixel data.
- `0x016c-016d` and `0x016e-016f`, which set the width and height of the image data output from the sensor.

According to the [video timings calculator](https://tomverbeure.github.io/video_timings_calculator), 720p60 requires a pixel clock of 74.25MHz. The total horizontal length on the HDMI side must be `1650` and the vertical length must be `850`. However, a custom configuration is used in this project, causing the pixel clock to be **86.11MHz**, and the horizontal HDMI blanking to be `1687` instead. 

The following equation is satisfied:

$$
\frac{86.11 \text{MHz}}{1687 \times 850} = 60fps
$$

On the I2C side, the numbers are a little different, as the values of the registers `frame_length_lines` and `line_length_pck` are used in this equation. Furthermore, a different clock frequency is used (**88MHz**) and, because the IMX219 sensor uses 2 lanes, it must be multiplied by two, leading to the following equation:

$$
\frac{2 \times 88 \text{MHz}}{3448 \times 850} = 60fps
$$

It should be noted that the sensor can be configured via I2C to show a **test pattern** image rather than the camera input. This can easily be toggled by setting the register `0x0601` to have the value `2` instead of `0`.

The testing was successful, as shown below. A visible issue is the overly green color of the video output. We assume that this has to do with the sensor, and that it will be fixed by our color balancing module.

<p align="center">
   <img width="500" src="0.doc/pictures_sihi/monitor_720p60.jpg">
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=S1D-_p-TuaU">
    <img src="0.doc\pictures_sihi\thumbnail_720p60.png" alt="720p60fps">
  </a>
</p>

#### 1920x1080p @ 30Hz

In contrast to 720p60, 1080p30 was not already validated and configured by the original contributors, therefore we had to implement it from scratch. This was a task that required time and effort, mostly on understanding the I2C and HDMI timing settings for 720p60 and figuring out how they must change for 1080p30.

Once again, even though the default pixel clock for 1080p30 is 74.25MHz, a custom configuration is utilized, so its value is actually **86.11MHz**. The default vertical length on the HDMI side is `1125`. The default horizontal length is `2200`, but we change it to `2553` to support the new pixel clock and satisfy the equation for 30fps:

$$
\frac{86.11 \text{MHz}}{2553 \times 1125} = 30fps
$$

A new pixel clock of **58MHz** was chosen for the I2C configuration, so that it can keep up with the required resolution and frame rate:

$$
\frac{2 \times 58 \text{MHz}}{3448 \times 1125} = 30fps
$$

An unexpected issue we faced was monitor incompatibility. Through our testing sessions, we tried three different monitors
- The first supported 720p60 but not 1080p30.
- The second supported 1080p30 but not 720p60.
- The third supported both.

Video streams were eventually displayed with success:

<p align="center">
   <img width="500" src="0.doc/pictures_sihi/monitor_1080p30.jpg">
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=J9FRGJO-vHU">
    <img src="0.doc\pictures_sihi\thumbnail_1080p30.png" alt="1080p30fps">
  </a>
</p>


#### 1920x1080p @ 60Hz

When it comes to 1080p60, we conclude that it cannot be satisfied because the frequency that it requires exceeds the maximum frequency that can be produced by the MMCM / PLL modules in the FPGA. 

#### Memory and Bandwidth restrictions

In the HDMI side, there is a **FIFO** used, to buffer each line, because storing the entire frame (1280 * 720 * 24 bits  or 1920 * 1080 * 24 bits) is unfeasible due to FPGA memory restrictions. Using this FIFO helped us transmit the image through the HDMI module and display it successfully.

We experienced no problems with the MIPI bandwidth, as our data rate was measured to be below the theoretical upper bound of 2.5Gbits/sec:

| Resolution | Horizontal Pixels | Vertical Pixels | Bits per Pixel | Frame Rate | Per Lane | Data Rate |
|------------|-------------------|-----------------|----------------|------------|----------|-----------|
| 720p60     | 1280              | 720             | 24             | 60         | 1/2      | 0.663 GB/s|
| 1080p30    | 1920              | 1080            | 24             | 30         | 1/2      | 0.746 GB/s|

---

## Objective II 
### Implement and Validate ISP (Image Signal Processing) Block
**Simple Color Balance** IP Block available software code was available from https://www.ipol.im/pub/art/2011/llmps-scb/?utm_source=doi. 

#### Algorithm Overview

A hardware implementation must work with “live” images, i.e. groups of pixels per frame, flowing through an image pipeline. The hardware implementation of the *SCB* thus works on a frame by frame basis, correcting the colours of frame `n` in frame `(n + 1)`. The gap between frames is sufficient to compute the colour balance frame ratios, i.e. 
`frameratio = 255/(max RGB – min RGB)` per RGB channel, using dividers. Then, colours are balanced “live”, during frame `(n + 1`), by multiplying the input pixel colour `i` by `(i – min) x frameratio`.

#### Behavioral Experiments

The pixel clock frequency of `86.11MHz` is sufficient to perform multiplications “live”, as pixels come in and go out through the SCB IP Block. This was checked using post-PNR simulations in **Vivado** as both timing was closed for the design and entire images were validated to be balanced correctly.

In the following two figures which were used during behavioral testing, the effect of the *SCB* algorithm can be seen. On the left is the original image, which appears to be faded out, and on the right is the balanced image, which appears brighter and livelier, due to the color balancing:

<p align="left">
  <img src="https://github.com/user-attachments/assets/aec2abe9-594f-43c7-a6d0-f2eaaf4e6a84">
&nbsp; &nbsp; &nbsp; &nbsp;
  <img src="https://github.com/user-attachments/assets/7f9973be-c9e4-400e-8ff4-6cfb03cb38a5">
</p>

Similarly, an artificial sequence of frames that represents a video, can be displayed in the following figures. The range of the RGB values changes from frame to frame, and the *SCB* algorithm tries to balance them, based on each previous frame.
- Input Frames:
<p float="left">
  <img src="https://github.com/user-attachments/assets/527ff207-5331-4c40-a34b-1ed341b4690a" width="18%" />
  <img src="https://github.com/user-attachments/assets/bc37ffe4-7ace-45fb-bc02-e044579ede9a" width="18%" /> 
  <img src="https://github.com/user-attachments/assets/a91d4c1c-d96a-48ae-99c4-b38b54a1ba86" width="18%" /> 
  <img src="https://github.com/user-attachments/assets/c8fb4cc7-178d-423f-b505-2e0584a19056" width="18%" /> 
  <img src="https://github.com/user-attachments/assets/16fd01d7-9381-43c8-a354-a948236908f8" width="18%" /> 
</p>

- Output Frames:
<p float="left">
  <img src="https://github.com/user-attachments/assets/0a874c4d-f052-4829-a3da-9bc904bac58f" width="18%" />
  <img src="https://github.com/user-attachments/assets/712e3aa3-fe47-4a54-9038-d62fdeaebd5a" width="18%" /> 
  <img src="https://github.com/user-attachments/assets/1839e3b2-f9a4-472e-8f36-52422991797e" width="18%" /> 
  <img src="https://github.com/user-attachments/assets/165a87a1-581e-4ee9-afe6-ae1686fefdc7" width="18%" /> 
  <img src="https://github.com/user-attachments/assets/7a8be7f0-7643-400a-bfc1-416880abc9df" width="18%" /> 
</p>

In the screenshot below, the processing of one of the frame lines is shown. Previously, one identical frame has already been loaded, to configure the min-max ranges. In the input frame, all RGB values are within the range `[64, 196]`, so the SCB algorithm translates them to the range `[0, 255]`, with minor precision inaccuracies that do not have a large visible impact. The balancing is performed using multipliers which have a single cycle delay, thus this algorithm converts each frame with a single-cycle delay.
<p align="left">
  <img width="70%" src="https://github.com/user-attachments/assets/14ace642-50b9-4f24-9c23-7e8b3e501cb5">
</p>

#### Experiments on FPGA

The testcases examined in the above section, albeit properly functional, do not accurately reflect the image processing of a video stream captured by a sensor such as IMX219. Due to the way that the sensor captures each frame, the color ranges may not always range in `[0, 255]`, which is the reason why the HDMI output shown in **Objective I** had a visible shade of green. This is also shown clearly in the video below:

<p align="center">
  <a href="https://www.youtube.com/watch?v=z4zpcXpZTCA">
    <img src="0.doc\pictures_sihi\thumbnail_withoutisp.png" alt="withoutisp">
  </a>
</p>

The **Simple Color Balance** algorithm manages to remove this green shade and restore the pixels to a value that is much closer to their real color, as shown in the video below:

<p align="center">
  <a href="https://www.youtube.com/watch?v=m1KUGW67iG4">
    <img src="0.doc\pictures_sihi\thumbnail_withisp.png" alt="withoutisp">
  </a>
</p>

The difference in brightness and color scaling is evident in the frame comparison below:

<p align="left">
  <img width="50%" src="0.doc\pictures_sihi\withoutisp.jpg">
  <img width="50%" src="0.doc\pictures_sihi\withisp.jpg">
</p>

#### Advantages of the Simple Color Balance Algorithm
- It is **easy to implement**, as the mathematical equations used are rather simple and easy to be expressed in hardware.
- It **does not require a different (faster) clock** than the pixel clock already used (`86.11MHz`). This is really important because other parts of the MIPI to HDMI flow require clocks of different frequencies, causing CDCs to rise as a potential concern.
- It **does not consume many LUTs** or many FPGA resources in general. Only `1.31%` of our PUZHI board were required, and no instance of more crucial resources such as BRAMs
- It is a "straight-through" module, meaning that **no frames are lost** and **no structure such as a FIFO is required** to forward the related signals.

#### Disdvantages of the Simple Color Balance Algorithm
- It is **sensitive to light**, meaning that the balancing is suboptimal when a source of light appears in the capture.
- As it performs color balance on a frame-by-frame level, subtle differences between the frames can have a negative impact on the visual outcome.

---

## Objective III
### Implement and Validate JPEG Module 

The **JPEG** code was originally implemented by Robert Metchev as part of another project and can be found [here](https://github.com/brilliantlabsAR/frame-codebase/tree/main/source/fpga/modules/camera/jpeg_encoder).

After a frame is captured from the sensor, and passed through the **MIPI-CSI2-ISP** pipeline, it must be compressed using the **JPEG** algorithm. If no compression was used, the transmission of raw data would not be manageable by the **high-speed USB interface** that must follow.

The [JPEG module](1.hw/jpeg/jpeg_encoder.sv) handles the two supported resolutions (**1280x720 - 60fps** and **1920x1080 - 30fps**) and four different quality factors (`10%`, `25%`, `50%` and `100%`).

To minimize the complexity of the flow, the JPEG input is chosen to be the same as the HDMI input. This means that the `pixel clock` has the value of **86.11MHz**. Additionally the JPEG uses two more clocks,
namely the `JPEG slow clock`, which can run at a slower rate than the pixel clock, and the `JPEG fast clock`, which must be at least twice as fast as the pixel clock. In this case, the slow clock is chosen to have the same value as the pixel clock, while the fast clock will run at **175MHz**. This configuration is the same for both resolutions.

#### JPEG Architecture and Submodules
The block diagram of the JPEG architecture is as shown below:

<p align="center">
   <img width="1000" src="0.doc/pictures_sihi/jpeg_blockdiagram_horizontal.png">
</p>

The data is first fed to a [circuit](1.hw/jpeg/jisp/rgb2yuv.sv) that converts it from the `RGB` format to the `YCbCr` format, meaning that
the **Red, Green and Blue** channels are transated to the **Y (Luma), Cb (Blue-difference Chroma) and Cr (Red-Difference Chroma)**. The Y channel holds most of the information about the details of the image,
while the other two are necessary for the accurate color representation.

In the next step, a part of the color information (Cb, Cr) is discarded while the brightness information (Y) is fully preserved. This step, called [**Subsampling**](1.hw/jpeg/jisp/subsample.sv), leverages the human eye's decreased
sensitivity to color resolution, to reduce the total amount of data representing a frame. **4:2:0 Subsampling** is used for the JPEG module, which operates as displayed in the figures below.

<p align="center">
  <img src="0.doc/pictures_sihi/chroma_subsampling.jpg" width="35%">
&nbsp; &nbsp; &nbsp; &nbsp;
  <img src="0.doc/pictures_sihi/subsampkling.drawio.png" width="52%">
</p>

The data is then fed to an [**MCU (Minimal Coded Unit) Buffer**](1.hw/jpeg/jisp/mcu_buffer.sv), which holds data in 16-line chunks. The JPEG algorithm works with 16x16 blocks, referred to as MCUs, therefore it is essential to be able to store 16 full lines at any given time. A **CDC synchronizer** is also included, in the case that the JPEG slow clock is chosen to be slower than the pixel clock.

Afterwards the data is translated from the spatial pixel domain into the frequency domain using a [**2-D DCT (Discrete Cosine Transform)**](1.hw/jpeg/jenc/dct_2d.sv), which is split in two 1-D passes, for the sake of hardware resource management. As a lot of mathematical operations are carried out in this step, the fast JPEG clock is required.

In the next step, the [**Quantization**](1.hw/jpeg/jisp/quant.sv) process is performed. High-frequency details that are not
noticeable by the human eye are discarded, according to pre-defined quantization matrices. The level of quantization is determined by the `Quality Factor` input.

The data is then encoded using [**Entropy Encoding**](1.hw/jpeg/jenc/entropy.sv) and a [**Huffman table**](1.hw/jpeg/jenc/huff_tables.sv), so that similar frequencies are groupped together. The compression in this step is lossless.

Finally, the generated Huffman codes which normally vary in length, are [packed in 8-bit units](1.hw/jpeg/jenc/byte_pack.sv). In this module, the required output signals are generated when the entire frame has been encoded. The data is constantly fed to the output when a byte is completed, so there is no requirement to store a full frame or raw data. This **minimizes BRAM utilization**, requiring only the memory that is necessary for the 16-line buffer, as well as smaller memories for the DCT operation, whose size is negligible. 

The reduction of the total bytes transmitted essentially happens in three stages:
- In the **Subsampling** module, the `4:2:0` scheme is used, which keeps 100% of the brightness data but deletes 75% of the color data. As a result, the size of the video stream is halved without a visible difference.
- In the **Quantization** module, the division of high-frequency details leads to data reduction.
- The **Entropy Encoder** and **Huffman Encode**r assign specific codes on patterns that appear often, packing the transmitted data as effectively as possible.

#### JPEG Simulation

The JPEG module was first verified in [simulation](2.sim/jpeg_usb_audio/jpeg_tb.sv), by sending multiple images of the same resolution one after another, as if a video is being transmitted. Both resolutions (720p60fps, 1080p30fps) were tested.

To verify that the pixel clock of `86.11MHz` is correct for these resolutions, we set each frame to be transmitted every *1/60th* or every *1/30th* of a second respectively. If each frame is successfully encoded before the new frame signal ticks, this means that the JPEG module works as expected. Indeed, this was proven through simulation.

An image is loaded in a Verilog testbench in text format, after conversion from ``.bmp`` format. The JPEG headers are not actually generated inside the JPEG module, so they have to be added through external software. If this happens, then a JPEG output frame can be displayed.

Four encoded frames of a picture in **720p** resolution are shown below, each encoded with a different `QF` value. 
<table>
  <tr>
    <th width="49%">QF = 10%</th>
    <th width="2%"></th>
    <th width="49%">QF = 25%</th>
  </tr>
  <tr>
    <td><img src="0.doc\pictures_sihi\jpeg_720p\seagulls_qf10.jpg" width="100%"></td>
    <td></td>
    <td><img src="0.doc\pictures_sihi\jpeg_720p\seagulls_qf25.jpg" width="100%"></td>
  </tr>
  <tr><td colspan="3" height="20"></td></tr> <!-- Vertical Space -->
  <tr>
    <th>QF = 50%</th>
    <td></td>
    <th>QF = 100%</th>
  </tr>
  <tr>
    <td><img src="0.doc\pictures_sihi\jpeg_720p\seagulls_qf50.jpg" width="100%"></td>
    <td></td>
    <td><img src="0.doc\pictures_sihi\jpeg_720p\seagulls_qf100.jpg" width="100%"></td>
  </tr>
</table>

Similarly, below are displayed four encoded frames in **1080p** resolution, with different `QF` values.
<table>
  <tr>
    <th width="49%">QF = 10%</th>
    <th width="2%"></th>
    <th width="49%">QF = 25%</th>
  </tr>
  <tr>
    <td><img src="0.doc\pictures_sihi\jpeg_1080p\horses_qf10.jpg" width="100%"></td>
    <td></td>
    <td><img src="0.doc\pictures_sihi\jpeg_1080p\horses_qf25.jpg" width="100%"></td>
  </tr>
  <tr><td colspan="3" height="20"></td></tr> <!-- Vertical Space -->
  <tr>
    <th>QF = 50%</th>
    <td></td>
    <th>QF = 100%</th>
  </tr>
  <tr>
    <td><img src="0.doc\pictures_sihi\jpeg_1080p\horses_qf50.jpg" width="100%"></td>
    <td></td>
    <td><img src="0.doc\pictures_sihi\jpeg_1080p\horses_qf100.jpg" width="100%"></td>
  </tr>
</table>

#### JPEG Validation on FPGA

Finally, the JPEG module was also verified on the FPGA, with the aid of the USB module. In this experiment, the `IMX219` sensor samples [this YouTube video](https://www.youtube.com/watch?v=Cyxixzi2dgQ), which acts an **60fps framerate tester**, in 720p60fps. In this video, each frame corresponds to one of 60 clock ticks. Multiple frames are encoded using `QF=10%` and transmitted over USB, in raw format, to a host. The JPEG headers are then added using external Python scripts, and the output images are displayed. As shown in the video below, the JPEG successfully captures every single tick of the clock, verifying that the chosen clocks support 60fps. Note that no color balancing is used in this setting, which explains the green color of the video.

<p align="center">
  <a href="https://www.youtube.com/watch?v=89hWuUNnUS8">
    <img width="70%" img src="0.doc\pictures_sihi\thumbnail_jpeg_sampling.jpg" alt="jpegsampling">
  </a>
</p>

Since the full flow is not assembled together yet, it is difficult to assess the timing validity of the JPEG in real hardware. We have got a first indication that it is working, as shown in the above experiment. However, should this pixel clock value (`86.11MHz`) prove too high, it is possible to drop to the standard pixel clock value of `74.25MHz`, though this would require changes to the entire pipeline, starting from the *I2C* configuration. 

#### JPEG Bandwidth Evaluation

Some mathematical operations can prove the importance of compression:

- **Pre Compression**:
  - By translating the data from `RGB` to `YUV`, each pixel requires 1.5 byte instead of 3 bytes
  - For `720p60fps`, each frame requires 1280 &times; 720 = 921.600 pixels per frame, so **~1.38MBs per frame**, while for `1080p30fps`, each frame consists of 1920 &times; 1080 pixels per frame, so **~2.07MBs per frame**.
  - The rates per second are calculated to be **~82.9MB/s** for `720p60fps` and **~62.19MB/s** for `1080p30`, both of which exceed the theoretical upper bound of 60MB/s on the USB side.

- **Post Compression**:
  - A 720p frame encoded at `QF = 50%` resulted in a file of approx. **60kB**, which translates to **3.6MB/s** at 60FPS.
  - A 1080p frame encoded at `QF = 50%` resulted in a file of approx. **290kB**, which translates to **8.7MB/s** at 30FPS.
  - Both of the above can easily be handled by the USB interface.

*Note: The size of a JPEG-encoded image is not standard and depends on the complexity of the image. The above values refer to the [images that were tested during the simulation](2.sim/jpeg_usb_audio/image_files/output_jpeg/).*
### Implement and Validate Audio Module 

To sample audio input in our FPGA, we use a *dedicated PCB board* provided by Thomas Ludemann. On this board, the microphone chip `SPK0641HT4H-1` is installed.

<p align="center">
   <img width="400" src="0.doc/pictures_sihi/board_mic.png">
</p>

 The IO signals used, which are all connected to the board via *GPIO* pins, are:

- A **clock** from the FPGA to the board (`mclk`), which runs at **2.4MHz**.
- The **microphone data** (`mdata`) fed from the board to the FPGA.
- A signal to disable the microphone (`mdis`) which is not used in our implementation.

The [audio module](1.hw/audio/audio_top.sv) is designed to capture a **raw 1-bit PDM (Pulse Density Modulation)** stream from the microphone and transform it into **16-bit, 48kHz PCM (Pulse Code Modulation)** audio which can be transferred over USB. 

This architecture operates using three different frequencies:
- The `24MHz` clock, which the only physical clock driving the audio core logic, acts as the **master clock**. It drives the PDM sampling pulse every 10 cycles and eliminates the need for complex CDC structures.
- The **PDM Sampling Pulse** runs at `2.4MHz` and dictates when to sample the 1-bit data stream from the microphone.
- The **PCM output pulse** runs exactly once for every 50 PDM pulses received (at `48kHz`). It signals that a 16-bit PCM audio word is ready to be transmitted to the output.

The [PDM mapping module](1.hw/audio/pdm_mapper.sv) maps the incoming 1 and 0 bits to signed numbers (+1 and -1), which are accumulated in the [integrator module](1.hw/audio/cic_integrators.sv). Then, in the [decimator module](1.hw/audio/cic_decimator.sv), the accumulated values are forwarded with a frequency of `48KHz`, and are converted to PCM using [low-pass filters](1.hw/audio/cic_comb_filters.sv). Finally, a [DC centering module](1.hw/audio/dc_blocker.sv) removes the DC bias and an [amplifying module](amplifier.sv) applies a digital gain to make the audio loud enough.

A **block diagram** of the module is shown below:

<p align="center">
   <img width="1000" src="0.doc/pictures_sihi/audio_top.png">
</p>

There are no timing issues when considering the connection with the USB interface. The rate on which the output data is transmitted (`48kHz`) is much slower than the USB clock (`60MHz`) so it is mathematically guaranteed that the generated audio can pass through USB.

To verify the audio core in [simulation](2.sim/jpeg_usb_audio/audio_tb.sv), the microphone data fed to the testbench represents a sound sample which lasts a single second and plays four beeping sounds. Indeed, when converting the output PCM data to a `.wav file`, the output is a loud, clear sequence of [beeping sounds](2.sim/jpeg_usb_audio/simulated_beep.wav).

---

## Objective IV
### Implement and Validate USB 2.0 Module

To connect the FPGA and a PC host, a **USB 2.0 PCB board** is used, which was provided to us by Thomas Ludemann. Such a board is required, because the standard I/O pins of the FPGA operate entirely on digital logic levels, and cannot drive the **USB 2.0 differential signals**, as they lack the native analog hardware. 

The external board utilizes a **USB3343 PHY transceiver**, which internally translates the analog USB signals into a digital **ULPI interface**, which operates at `60MHz`. The use of this chip allows the FPGA to directly communicate with the PC host.

The board is connected to the FPGA via an **FMC connector**.

<p align="center">
  <img src="0.doc/pictures_sihi/usb_front.png" width="45%">
&nbsp; &nbsp; &nbsp; &nbsp;
  <img src="0.doc/pictures_sihi/usb_back.png" width="45.3%">
</p>

The `ULPI` protocol reduces the amount of physical pins required for a USB interface, from over 30 pins required in the original `UTMI` protocol, to **12 pins**. This standard offers a much-needed abstraction from the analog electrical states of the USB cable, while continuously operating at `60MHz`. The 12 pins are:

- `CLK` (1 bit, PHY to FPGA)
- `DIR` (1 bit, PHY to FPGA)
- `NXT` (1 bit, PHY to FPGA),
- `STP` (1 bit, FPGA to PHY),
- `DATA` (8 bit, bidirectional)

Aside from these I/O signals, ULPI uses a large **register set** which can be accessed using `Register Read` or `Register Write` operation. When the link wants to access these registers, or transmit data over the bus, it must send a byte called **TXCMD** to notify the PHY about its intentions. Similarly, for any status changes, the PHY must transmit a byte called **RXCMD** to the host.

For video transmission, it is essential to support **USB 2.0 High Speed**. In theory, the maximum data transfer rate is `480Mbps` (60MB/s), which is a significant leap over `12Mbps` supported in the next fastest mode, which is Full Speed. In practice, the rate achieved ranges between `30-40MB/s`, due to overhead.

The [ULPI Manual](0.doc/USB/ULPI_v1_1.pdf) describes the process required to [set-up USB 2.0 High Speed](1.hw/usb/fsm/fsm_setup_highspeed.sv). This revolves around a process called **chirping**, in which the two **USB Data Lines** (`D+` and `D-`) are driven to specific voltage values by the link and by the host. After this process is completed, the two sides can exchange packets over the USB 2.0 High-Speed connection.

In the [next step](1.hw/usb/fsm/fsm_read_packets.sv), the host typically asks the device for information, by sending packets which form specific **requests**, shaped in standard templates named **Descriptors**. The device must be programmed to [decode these requests](1.hw/usb/packet_utility/decode_request.sv) and [respond to them accordingly](1.hw/usb/packet_utility/send_descriptor_fsm.sv). After the device responds to all requests, the host will have a good idea of the characteristics of the device, and what operations it will be used for. It explicitly declares its class and function to the host. For example, the device might identify as a **Video Class (UVC)** device for streaming video, an **Audio Class (UAC)** device for transmitting audio, or a **Custom (Vendor-Specific)** device.

The packets can be divided in four categories:
- **Token Packets** are always the first packets in a transaction, and they identify the target and the purpose of the transaction.
- **Data Packets** include the data transmitted in the Data stage of a transaction.
- **Handshake Packets** are used to signal if a transaction was acknowledged by the receiving side.
- **SOF Packets** are sent every `1ms` on Full-speed links, and every `125us` on High-Speed links, and can be used for scheduling.

Packets can consist of the following elements:
- **PID (8 bits)**: Every Packet must include an 8-bit `PID`, which shows the type of transaction.
- **Address (7 bits) and Endpoint (4 bits)**: Used in **Token Packets**. Address is used to distinguish between different devices, while there can be different endpoints in the same device.
- **CRC (5 or 16 bits)**: After every non-Handshake packet, a `CRC` must be send. This is a type of checksum which is decoded by the receiver to verify that no bytes were lost through the transaction.
- **Data (0-1024 &times; 8 bits).**

After the host has sent all the requests, the [data transmission](1.hw/usb/fsm/fsm_transfer_data.sv) can start. The data can be sent in either **Isochronous** or **Bulk** mode. Isochronous can achieve a higher data rate, and thus is recommented for Video streaming, while Bulk is more limited but still fast enough, and more reliable due to the inclusion of `ACK` / `NAK` packets. 

The top-level flow is shown below. The `ULPI` I/O signals are sufficient to control the whole flow. The `DIR` signal shows who has control of the `DATA` bus. The `NXT` signal is used to shpw when the `DATA` bus includes a valid byte. The link raises the `STP` signal when it has finished an operation. For better organization, the circuit is separated in **three phases**, each of which operates with its own FSM:

<p align="center">
   <img width="90%" src="0.doc/pictures_sihi/usb_top.drawio.png">
</p>

#### USB Video Class & USB Audio Class

In order to transmit video and audio simultaneously, the device has to declare itself to the host as a **Composite Device**. This means that the connection is divided into two independent **Interfaces**. Each interface acts as a standalone virtual device with its own endpoints, thus allowing the host PC to process the camera and the microphone as if they were two entirely separate devices, as shown in the below screenshot of the **USBTreeView** software :

<p align="center">
   <img width="40%" src="0.doc/pictures_sihi/usbtreeview_devices.png">
</p>

The first interface is configured as a **UVC (USB Video Class)** device. When the device responds to the specific `UVC` descriptors, the host recognizes this and loads its native webcam drivers. The device must then send the JPEG frames whenever the host tells them to. In **Isochronous** mode, the host sends an `IN` packet once per microframe (every `125 us`), allowing the device to send up to 1024 bytes. However, the JPEG frames must be wrapped around **UVC headers**, so that every program that can open a camera (like OBS, Zoom or the Windows Camera app) knows exactly when a frame begins and ends.

The second interface is configured as a **UAC (USB Audio Class)** device. Similarly, the host loads its native audio drivers whenever the device reads the `UAC` descriptors. The device can then send PCM audio data whenever asked. This audio data does not require specific headers. 

To distinguish between the two interfaces, the host assigns a **different endpoint number** to each interface. This endpoint number is included in the `IN` packet sent, so that the device can respond with either Video or Audio data. By sending alternate requests, the host can broadcast both **real-time video** and **real-time audio**. Note that the data required for video significantly overweigh the data required for audio, and this is also reflected in the frequency of `IN` packets send by the host in each endpoint. If the data is not yet ready, the device must respond with a **ZLP (Zero-length packet)**. 

<p align="center">
   <img width="60%" src="0.doc/pictures_sihi/usb_fsm.drawio.png">
</p>

#### USB Simulation

In the simulation, the [testbench environment](2.sim/jpeg_usb_audio/usb_tb.sv) is modelled as the **USB host**, while the [module instantiated](1.hw/usb/usb_top.sv) performs as the **USB device**. The host behaves exactly as a real USB host would, as observed by using a logic analyzer to monitor the values of the ULPI ports. The testbench mimics operations such as **chirping**, **RXCMD transmitting** and **packet transmitting**. Additionally, a memory block that holds the sequence of the requests sent by the host is instantiated and used inside the testbench:

<p align="center">
   <img width="60%" src="0.doc/pictures_sihi/usb_request_memory.png">
</p>

The aim of the simulation is to ensure that the behaviour of the USB device is exactly as documented in the [ULPI Manual](0.doc/USB/ULPI_v1_1.pdf) and the [USB3343 Data Sheet](0.doc/USB/USB334x-Data-Sheet-DS00002646A.pdf). All ULPI ports must rise and fall in a cycle-accurate manner. The device must pass through all three phases shown in the block diagram above, and eventually start transmitting video and audio data. It also must be able to respond to any requests out-of-the-box.

The device has to transmit video and audio data at the same time. For the sake of simplicity, the JPEG encoder is not used in this module, but a JPEG-encoded frame is instead loaded from a [memory file](1.hw/usb/mem/seagulls.mem). It is important to mention that the *JPEG headers* are obtained from a [separate memory file](1.hw/usb/mem/headers_720p_qf10.mem) and they are the same for every other frame in this configuration. As for audio, input `mdata` is given random values. While the video data is fetched straight from the memory when required, a short fifo must be used to store the audio data.

#### USB Validation

After step-by-step experiments using a Digital Analyzer, the USB device appears in the **Device Manager**, both as a Video and as an Audio device. Using the USBTreeView software, we can see the information of the device, as specified during the enumeration phase. The top-level information is shown below, while all the details can be found [in this text file](0.doc/USB/usb_camera_mic_report.txt). The `VID (Vendor ID)` and `Product ID (PID)` values, which together form the ID of the device, are chosen arbitrarily.

<p align="center">
   <img width="90%" src="0.doc/pictures_sihi/usbtreeview_info.png">
</p>

Another tool that proved invaluable for debugging and validation is **Wireshark**, which can track all USB traffic and examine all packets in detail. By targetting the address value that corresponds to this device, using the native Wireshark filters, we have a clear picture of the requests that the host sends:

<p align="center">
  <img src="0.doc/pictures_sihi/wireshark_traffic.png" width="70%">
</p>

<p align="center">
  <img src="0.doc/pictures_sihi/wireshark_example.png" width="70%">
</p>

The **FPGA setup** used is shown below. Both PCB boards (the USB PHY and the Microphone chip) are utilized. As shown, the Microphone board is connected via GPIO pins to the FPGA, the USB board is connected via the FMC connector, while the USB board is also connected to the PC host using a standard MicroUSB cable:

<p align="center">
  <img src="0.doc/pictures_sihi/usb_fpga_setup.jpg" width="50%">
</p>

A demonstration of the **full, working USB - UVC - UAC flow** is shown below. Here, the *JPEG test image* is loaded from the memory and broadcast into the **Windows Camera app**, while at the same time the **Windows Recorder app** can record and play the audio at real time:

<p align="center">
  <a href="https://www.youtube.com/watch?v=fiw-4s3qQ5s">
    <img width="70%" img src="0.doc\pictures_sihi\usb_uvc_uac_thumbnail.JPG" alt="usb_demo">
  </a>
</p>

#### USB Bandwidth Analysis

For **Video transmission**:

- The maximum packet size in Isochronous mode is *1024 bytes*.
- In High-Bandwidth Isochronous mode, the device can send **3 packets per microframe**.
- A microframe corresponds to 125us, so there are **8000 microframes per second**.

Therefore, the maximum bandwidth for video transmission is **1024 &times; 3 &times; 8000 = 24.57MB/s**.

For **Audio transmission**:

- The audio format is 16-bit, so each sample consists of 2 bytes.
- 48kHz sample rate translates to **48000 samples per second**.

The bandwidth required for audio transmission is **48000 &times; 2 = 96kB/s or &lt;  0.1MB/s**.
It is evident that, when transmitting both Video and Audio, the latter is negligible compared with the former. 

For `60FPS` to be supported, each frame has to occupy less than **24.75 / 60 = ~410kB**, while for `30FPS` the size of the frame must not exceed **24.57 / 30 = ~820kB**. As shown in the JPEG analysis, an encoded frame occupies around **60kB** for `720p` and **290kB** for `1080p`, so the transmission can be carried out without issues. In fact, a higher FPS is theoretically possible based on these numbers.

### Upcoming:
   - [X] Validate Basic Development Hardware Setup

   - [X] Implement and Validate ISP (Image Signal Processing) Block 

   - [X] Implement and Validate JPEG Module and Audio core 

   - [X] Implement and Validate USB2.0 Module 

   - [ ] Put together and Demonstrate working MIPI-JPEG-USB FPGA System 
