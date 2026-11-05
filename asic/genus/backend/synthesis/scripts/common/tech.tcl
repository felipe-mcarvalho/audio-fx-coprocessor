# Configuracao da biblioteca GPDK045.
create_library_domain {worst best}

set_db lib_search_path "${LIB_DIR} ${LEF_DIR}"
set_db [get_db library_domains worst] .library ${WORST_LIST}
set_db [get_db library_domains best] .library ${BEST_LIST}

set_db [get_db library_domains worst] .operating_conditions ${WORST_LIB_OPERATING_CONDITION}
set_db [get_db library_domains best] .operating_conditions ${BEST_LIB_OPERATING_CONDITION}

set_db lef_library ${LEF_LIST}
set_db qrc_tech_file ${QRC_LIST}
set_db interconnect_mode ple
