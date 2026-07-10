cmake_minimum_required(VERSION 3.16)
project(orionos-cloud-sync VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

qt_add_executable(orionos-cloud-sync
    main.cpp
)

qt_add_resources(orionos-cloud-sync "qml"
    PREFIX "/qml"
    FILES
        ../qml/main.qml
        ../qml/AccountPage.qml
        ../qml/SyncPage.qml
        ../qml/SettingsPage.qml
)

target_link_libraries(orionos-cloud-sync PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

install(TARGETS orionos-cloud-sync RUNTIME DESTINATION bin)
