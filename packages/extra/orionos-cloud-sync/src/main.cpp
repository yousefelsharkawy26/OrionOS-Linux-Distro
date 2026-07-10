#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("OrionOS Cloud Sync");
    app.setOrganizationName("OrionOS");
    app.setApplicationVersion("1.0.0");
    app.setWindowIcon(QIcon::fromTheme("orionos-cloud-sync"));

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
