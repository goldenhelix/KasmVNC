add_subdirectory(tx)
add_subdirectory(common)
add_subdirectory(vncconfig)
add_subdirectory(vncpasswd)
add_subdirectory(kasmvncpasswd)
add_subdirectory(kasmxproxy)

install(PROGRAMS vncserver DESTINATION ${BIN_DIR})
install(FILES vncserver.man DESTINATION ${MAN_DIR}/man1 RENAME vncserver.1)
install(PROGRAMS openurl/kasmvnc-open-url DESTINATION ${BIN_DIR})
install(PROGRAMS openurl/xdg-open-shim DESTINATION ${BIN_DIR}
        RENAME kasmvnc-xdg-open)
install(FILES openurl/kasmvnc-open-url.desktop DESTINATION ${DATA_DIR}/applications)
install(FILES openurl/kasmvnc-open-url.helper DESTINATION ${DATA_DIR}/xfce4/helpers
        RENAME kasmvnc-open-url.desktop)
install(PROGRAMS download/kasmvnc-file-download DESTINATION ${BIN_DIR})
install(FILES download/thunar-uca.example.xml DESTINATION ${DATA_DIR}/kasmvnc
        RENAME thunar-uca.xml)
install(PROGRAMS upload/kasmvnc-upload-daemon DESTINATION ${BIN_DIR})
