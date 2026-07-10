cmake_minimum_required(VERSION 3.16)
project(OrionOS-Software-Center)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Widgets
    Quick
    QuickControls2
    QuickWidgets
    Svg
    WebEngine
    WebEngineWidgets
    Network
    Qml
    QuickTemplates2
    QuickControls2Impl
    Graphicaleffects
)

find_package(KF6 REQUIRED COMPONENTS
    Config
    CoreAddons
    I18n
    IconThemes
    KIO
    ItemModels
    Notifications
    WidgetsAddons
    XmlGui
)

# Find Python
find_package(Python3 REQUIRED COMPONENTS Interpreter Development)

# Source files
set(SOURCES
    src/main.cpp
    src/mainwindow.cpp
    src/application.cpp
    src/backend/pacmanbackend.cpp
    src/backend/flatpakbackend.cpp
    src/backend/appimagebackend.cpp
    src/backend/packagekitbackend.cpp
    src/models/packagemodel.cpp
    src/models/categorymodel.cpp
    src/models/installedmodel.cpp
    src/models/updatesmodel.cpp
    src/models/sourcesmodel.cpp
    src/delegates/packageitemdelegate.cpp
    src/delegates/categoryitemdelegate.cpp
    src/utils/utils.cpp
    src/utils/network.cpp
    src/utils/settings.cpp
    src/widgets/packageview.cpp
    src/widgets/categoryview.cpp
    src/widgets/installedview.cpp
    src/widgets/updatesview.cpp
    src/widgets/sourcesview.cpp
    src/widgets/searchbar.cpp
    src/widgets/statusbar.cpp
    src/dialogs/aboutdialog.cpp
    src/dialogs/settingsdialog.cpp
    src/dialogs/transactiondialog.cpp
    src/dialogs/sourcesdialog.cpp
)

# Headers
set(HEADERS
    src/mainwindow.h
    src/application.h
    src/backend/pacmanbackend.h
    src/backend/flatpakbackend.h
    src/backend/appimagebackend.h
    src/backend/packagekitbackend.h
    src/models/packagemodel.h
    src/models/categorymodel.h
    src/models/installedmodel.h
    src/models/updatesmodel.h
    src/models/sourcesmodel.h
    src/delegates/packageitemdelegate.h
    src/delegates/categoryitemdelegate.h
    src/utils/utils.h
    src/utils/network.h
    src/utils/settings.h
    src/widgets/packageview.h
    src/widgets/categoryview.h
    src/widgets/installedview.h
    src/widgets/updatesview.h
    src/widgets/sourcesview.h
    src/widgets/searchbar.h
    src/widgets/statusbar.h
    src/dialogs/aboutdialog.h
    src/dialogs/settingsdialog.h
    src/dialogs/transactiondialog.h
    src/dialogs/sourcesdialog.h
)

# Resources
set(RESOURCES
    resources/resources.qrc
)

# QML files
set(QML_FILES
    qml/main.qml
    qml/ApplicationWindow.qml
    qml/views/HomeView.qml
    qml/views/PackageView.qml
    qml/views/CategoryView.qml
    qml/views/InstalledView.qml
    qml/views/UpdatesView.qml
    qml/views/SourcesView.qml
    qml/views/SearchView.qml
    qml/components/PackageCard.qml
    qml/components/CategoryCard.qml
    qml/components/ActionButton.qml
    qml/components/SearchBar.qml
    qml/components/StatusBar.qml
    qml/components/NavigationBar.qml
    qml/components/LoadingIndicator.qml
    qml/components/ErrorView.qml
    qml/dialogs/AboutDialog.qml
    qml/dialogs/SettingsDialog.qml
    qml/dialogs/TransactionDialog.qml
    qml/dialogs/SourcesDialog.qml
)

# Create executable
add_executable(${PROJECT_NAME}
    ${SOURCES}
    ${HEADERS}
    ${RESOURCES}
    ${QML_FILES}
)

# Link libraries
target_link_libraries(${PROJECT_NAME}
    PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::QuickWidgets
    Qt6::Svg
    Qt6::WebEngine
    Qt6::WebEngineWidgets
    Qt6::Network
    Qt6::Qml
    Qt6::QuickTemplates2
    Qt6::QuickControls2Impl
    Qt6::Graphicaleffects
    KF6::Config
    KF6::CoreAddons
    KF6::I18n
    KF6::IconThemes
    KF6::KIO
    KF6::ItemModels
    KF6::Notifications
    KF6::WidgetsAddons
    KF6::XmlGui
    Python3::Python
)

# Install targets
install(TARGETS ${PROJECT_NAME} DESTINATION bin)

# Install QML files
install(DIRECTORY qml/ DESTINATION share/${PROJECT_NAME}/qml)

# Install resources
install(DIRECTORY resources/ DESTINATION share/${PROJECT_NAME}/resources)

# Install desktop file
install(FILES data/orionos-software-center.desktop DESTINATION share/applications)

# Install icon
install(FILES data/orionos-software-center.svg DESTINATION share/icons/hicolor/scalable/apps)

# Install polkit policy
install(FILES data/org.orionos.softwarecenter.policy DESTINATION share/polkit-1/actions)

# Install systemd service
install(FILES data/orionos-software-center.service DESTINATION lib/systemd/user)

# Install scripts
install(PROGRAMS scripts/orionos-appimage-integration DESTINATION bin)
install(PROGRAMS scripts/orionos-flatpak-integration DESTINATION bin)
