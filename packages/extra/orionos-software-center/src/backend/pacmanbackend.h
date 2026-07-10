#ifndef PACMANBACKEND_H
#define PACMANBACKEND_H

#include "packagebackend.h"
#include <QProcess>
#include <QVariantMap>

class PacmanBackend : public PackageBackend
{
    Q_OBJECT
    
public:
    explicit PacmanBackend(QObject *parent = nullptr);
    ~PacmanBackend() override;
    
    // PackageBackend interface
    QString name() const override;
    QString displayName() const override;
    QString iconName() const override;
    bool isEnabled() const override;
    bool isAvailable() const override;
    
    QList<Package> packages() const override;
    QList<Package> installedPackages() const override;
    QList<Package> updates() const override;
    QList<Category> categories() const override;
    QList<Source> sources() const override;
    
    bool installPackage(const QString &packageId) override;
    bool removePackage(const QString &packageId) override;
    bool updatePackage(const QString &packageId) override;
    bool updateAllPackages() override;
    
    bool addSource(const QString &url, const QString &name = QString()) override;
    bool removeSource(const QString &name) override;
    bool refreshSources() override;
    
    bool cancelTransaction() override;
    bool isTransactionRunning() const override;
    
private slots:
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onProcessReadyReadStandardOutput();
    void onProcessReadyReadStandardError();
    
private:
    void parsePacmanOutput(const QString &output);
    void parsePacmanPackages(const QString &output);
    void parsePacmanUpdates(const QString &output);
    void parsePacmanInstalled(const QString &output);
    void parsePacmanSearch(const QString &output);
    
    Package parsePackageLine(const QString &line);
    QVariantMap parsePackageDetails(const QString &packageName);
    
    void runPacmanCommand(const QStringList &args);
    void runAsRoot(const QStringList &args);
    
    QProcess *m_process;
    bool m_transactionRunning;
    QList<Package> m_packages;
    QList<Package> m_installedPackages;
    QList<Package> m_updates;
    QList<Category> m_categories;
    QList<Source> m_sources;
};

#endif // PACMANBACKEND_H
