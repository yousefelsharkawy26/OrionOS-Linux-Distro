#ifndef APPLICATION_H
#define APPLICATION_H

#include <QObject>
#include <QList>
#include <QVariant>
#include <QSharedPointer>

class PackageBackend;
class PackageModel;
class CategoryModel;
class InstalledModel;
class UpdatesModel;
class SourcesModel;

class Application : public QObject
{
    Q_OBJECT
    
public:
    explicit Application(QObject *parent = nullptr);
    ~Application() override;
    
    // Backends
    Q_INVOKABLE PackageBackend* pacmanBackend() const;
    Q_INVOKABLE PackageBackend* flatpakBackend() const;
    Q_INVOKABLE PackageBackend* appImageBackend() const;
    
    // Models
    Q_INVOKABLE PackageModel* packageModel() const;
    Q_INVOKABLE CategoryModel* categoryModel() const;
    Q_INVOKABLE InstalledModel* installedModel() const;
    Q_INVOKABLE UpdatesModel* updatesModel() const;
    Q_INVOKABLE SourcesModel* sourcesModel() const;
    
    // Settings
    Q_INVOKABLE void saveSettings(const QString &key, const QVariant &value);
    Q_INVOKABLE QVariant loadSettings(const QString &key, const QVariant &defaultValue = QVariant());
    
    // System integration
    Q_INVOKABLE void launchApplication(const QString &desktopFile);
    Q_INVOKABLE void openUrl(const QString &url);
    Q_INVOKABLE void openTerminal(const QString &workingDir = QString());
    
    // Package operations
    Q_INVOKABLE void installPackage(const QString &packageId, const QString &backendName);
    Q_INVOKABLE void removePackage(const QString &packageId, const QString &backendName);
    Q_INVOKABLE void updatePackage(const QString &packageId, const QString &backendName);
    Q_INVOKABLE void updateAllPackages();
    
    // Search and filter
    Q_INVOKABLE void searchPackages(const QString &query);
    Q_INVOKABLE void filterByCategory(const QString &category);
    Q_INVOKABLE void clearFilters();
    
    // Sources management
    Q_INVOKABLE void addSource(const QString &type, const QString &url, const QString &name = QString());
    Q_INVOKABLE void removeSource(const QString &type, const QString &name);
    Q_INVOKABLE void refreshSources();
    
    // Transaction management
    Q_INVOKABLE void cancelTransaction();
    
signals:
    void transactionStarted(const QString &message);
    void transactionProgress(const QString &message, int progress);
    void transactionFinished(bool success, const QString &message);
    void transactionError(const QString &error);
    void sourcesChanged();
    void updatesAvailable(int count);
    
private slots:
    void onTransactionMessage(const QString &message);
    void onTransactionProgress(int progress);
    void onTransactionFinished(bool success, const QString &message);
    void onUpdatesAvailable(int count);
    
private:
    void setupBackends();
    void setupModels();
    void setupConnections();
    
    QSharedPointer<PackageBackend> m_pacmanBackend;
    QSharedPointer<PackageBackend> m_flatpakBackend;
    QSharedPointer<PackageBackend> m_appImageBackend;
    
    QSharedPointer<PackageModel> m_packageModel;
    QSharedPointer<CategoryModel> m_categoryModel;
    QSharedPointer<InstalledModel> m_installedModel;
    QSharedPointer<UpdatesModel> m_updatesModel;
    QSharedPointer<SourcesModel> m_sourcesModel;
};

#endif // APPLICATION_H
