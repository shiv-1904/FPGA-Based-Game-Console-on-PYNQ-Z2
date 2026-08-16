## PS-Side Buttons (Mapped to gpio_io_i_0 vector)
## Button D19 -> Bit 0
set_property PACKAGE_PIN D19 [get_ports {gpio_io_i_0[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_io_i_0[0]}]

## Button D20 -> Bit 1
set_property PACKAGE_PIN D20 [get_ports {gpio_io_i_0[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_io_i_0[1]}]

## PL-Side Button (Mapped to u_btn_flap)
## Button L19
set_property PACKAGE_PIN L19 [get_ports u_btn_flap]
set_property IOSTANDARD LVCMOS33 [get_ports u_btn_flap]

set_property PACKAGE_PIN L20 [get_ports pl_btn_rst]
set_property IOSTANDARD LVCMOS33 [get_ports pl_btn_rst]

## =======================
## HDMI TMDS OUTPUT
## =======================
## HDMI TX (Output) - Physical Pins
set_property -dict {PACKAGE_PIN L16 IOSTANDARD TMDS_33} [get_ports TMDS_Clk_p_0]
set_property -dict {PACKAGE_PIN L17 IOSTANDARD TMDS_33} [get_ports TMDS_Clk_n_0]

set_property -dict {PACKAGE_PIN K17 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_p_0[0]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_n_0[0]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_p_0[1]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_n_0[1]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_p_0[2]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_n_0 [2]}])