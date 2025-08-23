new_project \
    -name {main_prog} \
    -location {D:\sch16t_110\designer\impl1\main_prog_fp} \
    -mode {single}
set_programming_file -file {D:\sch16t_110\designer\impl1\main_prog.pdb}
set_programming_action -action {PROGRAM}
run_selected_actions
save_project
close_project
