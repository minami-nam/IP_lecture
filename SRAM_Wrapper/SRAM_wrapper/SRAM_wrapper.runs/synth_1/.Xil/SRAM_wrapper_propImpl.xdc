set_property SRC_FILE_INFO {cfile:/home/minami/Coding_IPDesign/IP_lecture/SRAM_Wrapper/SRAM_wrapper/SRAM_wrapper.srcs/constrs_1/new/ooc.xdc rfile:../../../SRAM_wrapper.srcs/constrs_1/new/ooc.xdc id:1} [current_design]
set_property src_info {type:XDC file:1 line:14 export:INPUT save:INPUT read:READ} [current_design]
set_max_delay -from [get_ports {cs we ad[*] din[*]}] -to [all_registers -data_pins] -datapath_only 4.0
set_property src_info {type:XDC file:1 line:17 export:INPUT save:INPUT read:READ} [current_design]
set_max_delay -from [all_registers -clock_pins] -to [get_ports {dout[*]}] -datapath_only 4.0
set_property src_info {type:XDC file:1 line:23 export:INPUT save:INPUT read:READ} [current_design]
set_system_jitter 0.0
