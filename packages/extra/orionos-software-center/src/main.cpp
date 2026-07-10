#include "application.h"
#include "mainwindow.h"
#include <QApplication>
#include <QCommandLineParser>
#include <QIcon>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    // Set application attributes
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
    QApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    
    QApplication app(argc, argv);
    
    // Set application info
    QCoreApplication::setApplicationName("OrionOS Software Center");
    QCoreApplication::setApplicationVersion("0.2.0");
    QCoreApplication::setOrganizationName("OrionOS");
    QCoreApplication::setOrganizationDomain("orionos.org");
    
    // Set style
    QQuickStyle::setStyle("org.kde.desktop");
    QIcon::setThemeName("breeze");
    
    // Command line parser
    QCommandLineParser parser;
    parser.setApplicationDescription("OrionOS Software Center");
    parser.addHelpOption();
    parser.addVersionOption();
    
    // Add options
    QCommandLineOption searchOption(QStringList() << "s" << "search",
                                   "Search for packages", "query");
    parser.addOption(searchOption);
    
    QCommandLineOption categoryOption(QStringList() << "c" << "category",
                                      "Show category", "category");
    parser.addOption(categoryOption);
    
    QCommandLineOption updatesOption(QStringList() << "u" << "updates",
                                     "Show updates");
    parser.addOption(updatesOption);
    
    QCommandLineOption installedOption(QStringList() << "i" << "installed",
                                       "Show installed packages");
    parser.addOption(installedOption);
    
    parser.process(app);
    
    // Create application
    Application orionApp;
    
    // Create main window
    MainWindow window;
    window.setMinimumSize(1024, 768);
    window.setWindowTitle(QCoreApplication::applicationName());
    window.setWindowIcon(QIcon::fromTheme("orionos-software-center"));
    
    // Handle command line options
    if (parser.isSet(searchOption)) {
        window.showSearch(parser.value(searchOption));
    } else if (parser.isSet(categoryOption)) {
        window.showCategory(parser.value(categoryOption));
    } else if (parser.isSet(updatesOption)) {
        window.showUpdates();
    } else if (parser.isSet(installedOption)) {
        window.showInstalled();
    }
    
    window.show();
    
    return app.exec();
}
