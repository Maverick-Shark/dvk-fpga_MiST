## Generated SDC file "top.sdc"

## Copyright (C) 2018  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 18.0.0 Build 614 04/24/2018 SJ Standard Edition"

## DATE    "Sat Nov 28 21:14:47 2020"

##
## DEVICE  "EP3C25E144C8"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

#create_clock -name {clk} -period 20.000 -waveform { 0.000 10.000 } [get_ports {CLK_27[0]}]

set sys_clk "pll1|altpll_component|auto_generated|pll1|clk[3]"
create_clock -name {clk} -period 37.037 -waveform { 0.000 18.500 } [get_ports {CLK_27}]
create_clock -name {SPI_SCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]
set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks $sys_clk]

#**************************************************************
# Create Generated Clock
#**************************************************************
create_generated_clock -source [get_pins {pll1|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 100 -divide_by 27 -master_clock {clk} [get_pins {pll1|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -source [get_pins {pll1|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 100 -divide_by 27 -phase 180.000 -master_clock {clk} [get_pins {pll1|altpll_component|auto_generated|pll1|clk[1]}] 
create_generated_clock -source [get_pins {pll1|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 25 -divide_by 54 -master_clock {clk} [get_pins {pll1|altpll_component|auto_generated|pll1|clk[2]}] 
create_generated_clock -source [get_pins {pll1|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 50 -divide_by 27 -master_clock {clk} [get_pins {pll1|altpll_component|auto_generated|pll1|clk[3]}] 

#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {clk}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {clk}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {clk}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
set_clock_uncertainty -rise_from [get_clocks {clk}] -rise_to [get_clocks {clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk}] -fall_to [get_clocks {clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {clk}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
set_clock_uncertainty -fall_from [get_clocks {clk}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {clk}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
set_clock_uncertainty -fall_from [get_clocks {clk}] -rise_to [get_clocks {clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk}] -fall_to [get_clocks {clk}]  0.020  


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************

#set_output_delay -add_delay -max -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[2]}]  0.0100 [get_ports {sdcard1_mosi}]
#set_output_delay -add_delay -max -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[2]}]  0.0100 [get_ports {sdcard_mosi}]


#**************************************************************
# Set Clock Groups
#**************************************************************

#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

