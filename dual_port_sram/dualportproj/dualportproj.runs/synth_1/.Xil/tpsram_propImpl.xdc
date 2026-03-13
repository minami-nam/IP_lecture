set_property SRC_FILE_INFO {cfile:/home/minami/Coding_IPDesign/IP_lecture/dual_port_sram/dualportproj/dualportproj.srcs/constrs_1/new/cons1.xdc rfile:../../../dualportproj.srcs/constrs_1/new/cons1.xdc id:1} [current_design]
set_property src_info {type:XDC file:1 line:19 export:INPUT save:INPUT read:READ} [current_design]
set_max_delay -from [get_ports {wa[*] wd[*] we ra[*] re}] -to [all_registers -data_pins] -datapath_only 8.0
set_property src_info {type:XDC file:1 line:22 export:INPUT save:INPUT read:READ} [current_design]
set_max_delay -from [all_registers -clock_pins] -to [get_ports {rd[*]}] -datapath_only 8.0
set_property src_info {type:XDC file:1 line:27 export:INPUT save:INPUT read:READ} [current_design]
set_system_jitter 0.0
