#include "application.h"
#include "backend/pacmanbackend.h"
#include "backend/flatpakbackend.h"
#include "backend/appimagebackend.h"
#include "models/packagemodel.h"
#include "models/categorymodel.h"
#include "models/installedmodel.h"
#include "models/updatesmodel.h"
#include "models/sourcesmodel.h"
#include "utils/settings.h"
#include <QProcess>
#include <QDesktopServices>
#include <QUrl>
#include <QDebug>

Application::Application(QObject *parent)
    : QObject(parent)
{
    setupBackends();
    setupModels();
    setupConnections();
}

Application::~Application()
{
}

void Application::setupBackends()
{
    // Initialize backends
    m_pacmanBackend = QSharedPointer<PacmanBackend>::create();
    m_flatpakBackend = QSharedPointer<FlatpakBackend>::create();
    m_appImageBackend = QSharedPointer<AppImageBackend>::create();
}

void Application::setupModels()
{
    // Initialize models
    m_packageModel = QSharedPointer<PackageModel>::create();
    m_categoryModel = QSharedPointer<CategoryModel>::create();
    m_installedModel = QSharedPointer<InstalledModel>::create();
    m_updatesModel = QSharedPointer<UpdatesModel>::create();
    m_sourcesModel = QSharedPointer<SourcesModel>::create();
    
    // Set backends for models
    m_packageModel->setBackends({
        m_pacmanBackend.data(),
        m_flatpakBackend.data(),
        m_appImageBackend.data()
    });
    
    m_installedModel->setBackends({
        m_pacmanBackend.data(),
        m_flatpakBackend.data(),
        m_appImageBackend.data()
    });
    
    m_updatesModel->setBackends({
        m_pacmanBackend.data(),
        m_flatpakBackend.data()
    });
    
    m_sourcesModel->setBackends({
        m_pacmanBackend.data(),
        m_flatpakBackend.data()
    });
}

void Application::setupConnections()
{
    // Connect backend signals
    connect(m_pacmanBackend.data(), &PackageBackend::transactionMessage,
            this, &Application::onTransactionMessage);
    connect(m_pacmanBackend.data(), &PackageBackend::transactionProgress,
            this, &Application::onTransactionProgress);
    connect(m_pacmanBackend.data(), &PackageBackend::transactionFinished,
            this, &Application::onTransactionFinished);
    connect(m_pacmanBackend.data(), &PackageBackend::updatesAvailable,
            this, &Application::onUpdatesAvailable);
    
    connect(m_flatpakBackend.data(), &PackageBackend::transactionMessage,
            this, &Application::onTransactionMessage);
    connect(m_flatpakBackend.data(), &PackageBackend::transactionProgress,
            this, &Application::onTransactionProgress);
    connect(m_flatpakBackend.data(), &PackageBackend::transactionFinished,
            this, &Application::onTransactionFinished);
    connect(m_flatpakBackend.data(), &PackageBackend::updatesAvailable,
            this, &Application::onUpdatesAvailable);
    
    connect(m_appImageBackend.data(), &PackageBackend::transactionMessage,
            this, &Application::onTransactionMessage);
    connect(m_appImageBackend.data(), &PackageBackend::transactionProgress,
            this, &Application::onTransactionProgress);
    connect(m_appImageBackend.data(), &PackageBackend::transactionFinished,
            this, &Application::onTransactionFinished);
}

PackageBackend* Application::pacmanBackend() const
{
    return m_pacmanBackend.data();
}

PackageBackend* Application::flatpakBackend() const
{
    return m_flatpakBackend.data();
}

PackageBackend* Application::appImageBackend() const
{
    return m_appImageBackend.data();
}

PackageModel* Application::packageModel() const
{
    return m_packageModel.data();
}

CategoryModel* Application::categoryModel() const
{
    return m_categoryModel.data();
}

InstalledModel* Application::installedModel() const
{
    return m_installedModel.data();
}

UpdatesModel* Application::updatesModel() const
{
    return m_updatesModel.data();
}

SourcesModel* Application::sourcesModel() const
{
    return m_sourcesModel.data();
}

void Application::saveSettings(const QString &key, const QVariant &value)
{
    Settings::instance().setValue(key, value);
}

QVariant Application::loadSettings(const QString &key, const QVariant &defaultValue)
{
    return Settings::instance().value(key, defaultValue);
}

void Application::launchApplication(const QString &desktopFile)
{
    QProcess::startDetached("gtk-launch", {desktopFile});
}

void Application::openUrl(const QString &url)
{
    QDesktopServices::openUrl(QUrl(url));
}

void Application::openTerminal(const QString &workingDir)
{
    QString terminal = Settings::instance().value("terminal", "konsole").toString();
    QStringList args;
    
    if (!workingDir.isEmpty()) {
        if (terminal == "konsole") {
            args << "--workdir" << workingDir;
        } else if (terminal == "gnome-terminal") {
            args << "--working-directory" << workingDir;
        } else if (terminal == "xfce4-terminal") {
            args << "--default-working-directory" << workingDir;
        }
    }
    
    QProcess::startDetached(terminal, args);
}

void Application::installPackage(const QString &packageId, const QString &backendName)
{
    PackageBackend *backend = nullptr;
    
    if (backendName == "pacman") {
        backend = m_pacmanBackend.data();
    } else if (backendName == "flatpak") {
        backend = m_flatpakBackend.data();
    } else if (backendName == "appimage") {
        backend = m_appImageBackend.data();
    }
    
    if (backend) {
        backend->installPackage(packageId);
    }
}

void Application::removePackage(const QString &packageId, const QString &backendName)
{
    PackageBackend *backend = nullptr;
    
    if (backendName == "pacman") {
        backend = m_pacmanBackend.data();
    } else if (backendName == "flatpak") {
        backend = m_flatpakBackend.data();
    } else if (backendName == "appimage") {
        backend = m_appImageBackend.data();
    }
    
    if (backend) {
        backend->removePackage(packageId);
    }
}

void Application::updatePackage(const QString &packageId, const QString &backendName)
{
    PackageBackend *backend = nullptr;
    
    if (backendName == "pacman") {
        backend = m_pacmanBackend.data();
    } else if (backendName == "flatpak") {
        backend = m_flatpakBackend.data();
    }
    
    if (backend) {
        backend->updatePackage(packageId);
    }
}

void Application::updateAllPackages()
{
    // Update all backends
    m_pacmanBackend->updateAllPackages();
    m_flatpakBackend->updateAllPackages();
}

void Application::searchPackages(const QString &query)
{
    m_packageModel->search(query);
}

void Application::filterByCategory(const QString &category)
{
    m_packageModel->filterByCategory(category);
}

void Application::clearFilters()
{
    m_packageModel->clearFilters();
}

void Application::addSource(const QString &type, const QString &url, const QString &name)
{
    if (type == "pacman") {
        m_pacmanBackend->addSource(url, name);
    } else if (type == "flatpak") {
        m_flatpakBackend->addSource(url, name);
    }
    
    emit sourcesChanged();
}

void Application::removeSource(const QString &type, const QString &name)
{
    if (type == "pacman") {
        m_pacmanBackend->removeSource(name);
    } else if (type == "flatpak") {
        m_flatpakBackend->removeSource(name);
    }
    
    emit sourcesChanged();
}

void Application::refreshSources()
{
    m_pacmanBackend->refreshSources();
    m_flatpakBackend->refreshSources();
    m_appImageBackend->refreshSources();
    
    emit sourcesChanged();
}

void Application::cancelTransaction()
{
    if (m_pacmanBackend->isTransactionRunning()) {
        m_pacmanBackend->cancelTransaction();
    } else if (m_flatpakBackend->isTransactionRunning()) {
        m_flatpakBackend->cancelTransaction();
    } else if (m_appImageBackend->isTransactionRunning()) {
        m_appImageBackend->cancelTransaction();
    }
}

void Application::onTransactionMessage(const QString &message)
{
    emit transactionProgress(message, -1);
}

void Application::onTransactionProgress(int progress)
{
    emit transactionProgress(QString(), progress);
}

void Application::onTransactionFinished(bool success, const QString &message)
{
    emit transactionFinished(success, message);
    
    // Refresh models after transaction
    m_packageModel->refresh();
    m_installedModel->refresh();
    m_updatesModel->refresh();
}

void Application::onUpdatesAvailable(int count)
{
    emit updatesAvailable(count);
}
