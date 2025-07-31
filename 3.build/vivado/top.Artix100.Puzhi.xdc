#========================================================================
# openeye-CamSI * NLnet-sponsored open-source core for Camera I/F with ISP
#  Constraints for Artix7-100, Puzhi board
#========================================================================

#-------------------------------------------------------------------------
# clk, reset and misc

set_property -dict {PACKAGE_PIN R4 IOSTANDARD DIFF_SSTL15} [get_ports sys_clk_p]
set_property -dict {PACKAGE_PIN T4 IOSTANDARD DIFF_SSTL15} [get_ports sys_clk_n]

set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports sys_rst_n]

set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS25} [get_ports cam_en]

#-------------------------------------------------------------------------
# I2C

set_property -dict {PACKAGE_PIN K14 IOSTANDARD LVCMOS25} [get_ports i2c_sda]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS25} [get_ports i2c_scl]

#-------------------------------------------------------------------------
#CSI 

set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVDS_25} [get_ports {cam_dphy_clk[1]}]
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVDS_25} [get_ports {cam_dphy_clk[0]}]

set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVDS_25} [get_ports {cam_dphy_dat[0][1]}]
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVDS_25} [get_ports {cam_dphy_dat[0][0]}]

set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVDS_25} [get_ports {cam_dphy_dat[1][1]}]
set_property -dict {PACKAGE_PIN M16 IOSTANDARD LVDS_25} [get_ports {cam_dphy_dat[1][0]}]

#-------------------------------------------------------------------------
# HDMI

set_property -dict {PACKAGE_PIN Y19 IOSTANDARD TMDS_33} [get_ports hdmi_clk_n]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD TMDS_33} [get_ports hdmi_clk_p]

set_property -dict {PACKAGE_PIN P15 IOSTANDARD TMDS_33} [get_ports {hdmi_dat_p[0]}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD TMDS_33} [get_ports {hdmi_dat_n[0]}]

set_property -dict {PACKAGE_PIN AA18 IOSTANDARD TMDS_33} [get_ports {hdmi_dat_p[1]}]
set_property -dict {PACKAGE_PIN AB18 IOSTANDARD TMDS_33} [get_ports {hdmi_dat_n[1]}]

set_property -dict {PACKAGE_PIN N13 IOSTANDARD TMDS_33} [get_ports {hdmi_dat_p[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD TMDS_33} [get_ports {hdmi_dat_n[2]}]


##-------------------------------------------------------------------------
## DEBUG pins & LEDs

set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS25} [get_ports {debug_pins[0]}]
set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS25} [get_ports {debug_pins[1]}]
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS25} [get_ports {debug_pins[2]}]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS25} [get_ports {debug_pins[3]}]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS25} [get_ports {debug_pins[4]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVCMOS25} [get_ports {debug_pins[5]}]
set_property -dict {PACKAGE_PIN J22 IOSTANDARD LVCMOS25} [get_ports {debug_pins[6]}]
set_property -dict {PACKAGE_PIN H22 IOSTANDARD LVCMOS25} [get_ports {debug_pins[7]}]

# set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS25} [get_ports {led[0]}]
# set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS25} [get_ports {led[1]}]
# set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS25} [get_ports {led[2]}]

#========================================================================
# End-of-File
#========================================================================