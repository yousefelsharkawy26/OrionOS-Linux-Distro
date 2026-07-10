#include "pacmanbackend.h"
#include "utils/utils.h"
#include <QDebug>
#include <QFile>
#include <QRegularExpression>
#include <QStandardPaths>

PacmanBackend::PacmanBackend(QObject *parent)
    : PackageBackend(parent),
      m_process(new QProcess(this)),
      m_transactionRunning(false)
{
    // Setup process
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &PacmanBackend::onProcessFinished);
    connect(m_process, &QProcess::readyReadStandardOutput,
            this, &PacmanBackend::onProcessReadyReadStandardOutput);
    connect(m_process, &QProcess::readyReadStandardError,
            this, &PacmanBackend::onProcessReadyReadStandardError);
    
    // Initialize categories
    m_categories = {
        {"system", "System", "applications-system"},
        {"development", "Development", "applications-development"},
        {"games", "Games", "applications-games"},
        {"graphics", "Graphics", "applications-graphics"},
        {"internet", "Internet", "applications-internet"},
        {"multimedia", "Multimedia", "applications-multimedia"},
        {"office", "Office", "applications-office"},
        {"science", "Science", "applications-science"},
        {"security", "Security", "applications-security"},
        {"utilities", "Utilities", "applications-utilities"}
    };
    
    // Load sources
    refreshSources();
}

PacmanBackend::~PacmanBackend()
{
    if (m_process->state() == QProcess::Running) {
        m_process->terminate();
        m_process->waitForFinished(1000);
    }
}

QString PacmanBackend::name() const
{
    return "pacman";
}

QString PacmanBackend::displayName() const
{
    return tr("Pacman (Arch Linux)");
}

QString PacmanBackend::iconName() const
{
    return "package-archlinux";
}

bool PacmanBackend::isEnabled() const
{
    return true;
}

bool PacmanBackend::isAvailable() const
{
    return QFile::exists("/usr/bin/pacman");
}

QList<Package> PacmanBackend::packages() const
{
    return m_packages;
}

QList<Package> PacmanBackend::installedPackages() const
{
    return m_installedPackages;
}

QList<Package> PacmanBackend::updates() const
{
    return m_updates;
}

QList<Category> PacmanBackend::categories() const
{
    return m_categories;
}

QList<Source> PacmanBackend::sources() const
{
    return m_sources;
}

bool PacmanBackend::installPackage(const QString &packageId)
{
    if (m_transactionRunning) {
        return false;
    }
    
    emit transactionStarted(tr("Installing %1...").arg(packageId));
    m_transactionRunning = true;
    
    runAsRoot({"pacman", "-S", "--noconfirm", packageId});
    
    return true;
}

bool PacmanBackend::removePackage(const QString &packageId)
{
    if (m_transactionRunning) {
        return false;
    }
    
    emit transactionStarted(tr("Removing %1...").arg(packageId));
    m_transactionRunning = true;
    
    runAsRoot({"pacman", "-R", "--noconfirm", packageId});
    
    return true;
}

bool PacmanBackend::updatePackage(const QString &packageId)
{
    if (m_transactionRunning) {
        return false;
    }
    
    emit transactionStarted(tr("Updating %1...").arg(packageId));
    m_transactionRunning = true;
    
    runAsRoot({"pacman", "-S", "--noconfirm", packageId});
    
    return true;
}

bool PacmanBackend::updateAllPackages()
{
    if (m_transactionRunning) {
        return false;
    }
    
    emit transactionStarted(tr("Updating all packages..."));
    m_transactionRunning = true;
    
    runAsRoot({"pacman", "-Syu", "--noconfirm"});
    
    return true;
}

bool PacmanBackend::addSource(const QString &url, const QString &name)
{
    Q_UNUSED(name);
    
    // For pacman, we add to /etc/pacman.conf
    QString serverLine = QString("Server = %1").arg(url);
    
    // Check if already exists
    QFile pacmanConf("/etc/pacman.conf");
    if (!pacmanConf.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }
    
    QString content = pacmanConf.readAll();
    pacmanConf.close();
    
    if (content.contains(serverLine)) {
        return true;
    }
    
    // Add to [orionos] repo if it exists, otherwise create it
    if (content.contains("[orionos]")) {
        content.replace("[orionos]", QString("[orionos]\n%1").arg(serverLine));
    } else {
        content.append(QString("\n[orionos]\n%1\n").arg(serverLine));
    }
    
    // Write back as root
    if (!Utils::writeFileAsRoot("/etc/pacman.conf", content)) {
        return false;
    }
    
    refreshSources();
    return true;
}

bool PacmanBackend::removeSource(const QString &name)
{
    Q_UNUSED(name);
    
    // For pacman, we remove from /etc/pacman.conf
    QFile pacmanConf("/etc/pacman.conf");
    if (!pacmanConf.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }
    
    QString content = pacmanConf.readAll();
    pacmanConf.close();
    
    // Remove the [orionos] repo section
    QRegularExpression repoRegex("\[orionos\\].*?(?=\[|$")";
    content.remove(repoRegex);
    
    // Write back as root
    if (!Utils::writeFileAsRoot("/etc/pacman.conf", content)) {
        return false;
    }
    
    refreshSources();
    return true;
}

bool PacmanBackend::refreshSources()
{
    m_sources.clear();
    
    QFile pacmanConf("/etc/pacman.conf");
    if (!pacmanConf.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }
    
    QString content = pacmanConf.readAll();
    pacmanConf.close();
    
    QRegularExpression repoRegex("\[(\w+)\\]\s*([^\[]*)");
    QRegularExpressionMatchIterator i = repoRegex.globalMatch(content);
    
    while (i.hasNext()) {
        QRegularExpressionMatch match = i.next();
        QString repoName = match.captured(1);
        QString repoContent = match.captured(2);
        
        QRegularExpression serverRegex("Server\s*=\s*(\S+)");
        QRegularExpressionMatchIterator j = serverRegex.globalMatch(repoContent);
        
        while (j.hasNext()) {
            QRegularExpressionMatch serverMatch = j.next();
            QString serverUrl = serverMatch.captured(1);
            
            m_sources.append({
                repoName,
                serverUrl,
                "pacman",
                true
            });
        }
    }
    
    return true;
}

bool PacmanBackend::cancelTransaction()
{
    if (m_process->state() == QProcess::Running) {
        m_process->terminate();
        return m_process->waitForFinished(1000);
    }
    
    return false;
}

bool PacmanBackend::isTransactionRunning() const
{
    return m_transactionRunning;
}

void PacmanBackend::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    m_transactionRunning = false;
    
    if (exitStatus == QProcess::CrashExit || exitCode != 0) {
        QString error = m_process->readAllStandardError();
        if (error.isEmpty()) {
            error = tr("Unknown error occurred");
        }
        emit transactionError(error);
        emit transactionFinished(false, error);
    } else {
        emit transactionFinished(true, tr("Operation completed successfully"));
        
        // Refresh package lists
        QTimer::singleShot(1000, this, [this]() {
            // Refresh installed packages
            runPacmanCommand({"-Q"});
            
            // Refresh updates
            runPacmanCommand({"-Qu"});
        });
    }
}

void PacmanBackend::onProcessReadyReadStandardOutput()
{
    QString output = m_process->readAllStandardOutput();
    parsePacmanOutput(output);
}

void PacmanBackend::onProcessReadyReadStandardError()
{
    QString error = m_process->readAllStandardError();
    if (!error.isEmpty()) {
        emit transactionMessage(error.trimmed());
    }
}

void PacmanBackend::parsePacmanOutput(const QString &output)
{
    if (m_process->program() == "pacman" && m_process->arguments().contains("-S")) {
        // Installation output
        emit transactionProgress(output.trimmed(), -1);
    } else if (m_process->program() == "pacman" && m_process->arguments().contains("-Q")) {
        // Query output
        if (m_process->arguments().contains("-u")) {
            parsePacmanUpdates(output);
        } else {
            parsePacmanInstalled(output);
        }
    } else if (m_process->program() == "pacman" && m_process->arguments().contains("-Ss")) {
        // Search output
        parsePacmanSearch(output);
    }
}

void PacmanBackend::parsePacmanPackages(const QString &output)
{
    m_packages.clear();
    
    QStringList lines = output.split("\n", Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        Package package = parsePackageLine(line);
        if (!package.id.isEmpty()) {
            m_packages.append(package);
        }
    }
}

void PacmanBackend::parsePacmanUpdates(const QString &output)
{
    m_updates.clear();
    
    QStringList lines = output.split("\n", Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        if (line.contains(" -> ")) {
            QStringList parts = line.split(" -> ");
            if (parts.size() >= 2) {
                QString packageName = parts[0].trimmed();
                QString newVersion = parts[1].split(" ").first().trimmed();
                
                Package package;
                package.id = packageName;
                package.name = packageName;
                package.version = newVersion;
                package.backend = name();
                package.status = Package::UpdateAvailable;
                package.installedVersion = packageName + " " + parts[0].split(" ").last().trimmed();
                
                m_updates.append(package);
            }
        }
    }
    
    emit updatesAvailable(m_updates.size());
}

void PacmanBackend::parsePacmanInstalled(const QString &output)
{
    m_installedPackages.clear();
    
    QStringList lines = output.split("\n", Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        Package package = parsePackageLine(line);
        if (!package.id.isEmpty()) {
            package.status = Package::Installed;
            m_installedPackages.append(package);
        }
    }
}

void PacmanBackend::parsePacmanSearch(const QString &output)
{
    m_packages.clear();
    
    QStringList blocks = output.split("\n\n", Qt::SkipEmptyParts);
    for (const QString &block : blocks) {
        QStringList lines = block.split("\n", Qt::SkipEmptyParts);
        if (lines.size() >= 2) {
            Package package = parsePackageLine(lines[0]);
            if (!package.id.isEmpty()) {
                // Parse description from second line
                if (lines.size() > 1) {
                    package.description = lines[1].trimmed();
                }
                
                // Check if installed
                QVariantMap details = parsePackageDetails(package.id);
                if (details.contains("installed") && details["installed"].toBool()) {
                    package.status = Package::Installed;
                    package.installedVersion = details["version"].toString();
                } else {
                    package.status = Package::Available;
                }
                
                m_packages.append(package);
            }
        }
    }
}

Package PacmanBackend::parsePackageLine(const QString &line)
{
    Package package;
    QStringList parts = line.split(" ", Qt::SkipEmptyParts);
    
    if (parts.size() >= 2) {
        package.id = parts[0];
        package.name = parts[0];
        package.version = parts[1];
        package.backend = name();
        
        // Try to determine category
        if (package.id.startsWith("linux-")) {
            package.category = "system";
        } else if (package.id.contains("-dev") || package.id.contains("-devel")) {
            package.category = "development";
        } else if (package.id.contains("game") || package.id.contains("steam")) {
            package.category = "games";
        } else if (package.id.contains("kde-") || package.id.contains("gnome-") || 
                  package.id.contains("xfce-") || package.id.contains("mate-")) {
            package.category = "desktop";
        } else {
            // Default category
            package.category = "utilities";
        }
    }
    
    return package;
}

QVariantMap PacmanBackend::parsePackageDetails(const QString &packageName)
{
    QVariantMap details;
    
    // Run pacman -Si to get package details
    QProcess process;
    process.start("pacman", {"-Si", packageName});
    if (process.waitForFinished()) {
        QString output = process.readAllStandardOutput();
        QStringList lines = output.split("\n", Qt::SkipEmptyParts);
        
        for (const QString &line : lines) {
            if (line.contains(":")) {
                QStringList parts = line.split(":", Qt::SkipEmptyParts);
                if (parts.size() >= 2) {
                    QString key = parts[0].trimmed().toLower().replace(" ", "_");
                    QString value = parts[1].trimmed();
                    
                    if (key == "name") {
                        details["name"] = value;
                    } else if (key == "version") {
                        details["version"] = value;
                    } else if (key == "description") {
                        details["description"] = value;
                    } else if (key == "architecture") {
                        details["architecture"] = value;
                    } else if (key == "url") {
                        details["url"] = value;
                    } else if (key == "licenses") {
                        details["license"] = value;
                    } else if (key == "groups") {
                        details["groups"] = value.split(" ", Qt::SkipEmptyParts);
                    } else if (key == "provides") {
                        details["provides"] = value.split(" ", Qt::SkipEmptyParts);
                    } else if (key == "depends_on") {
                        details["dependencies"] = value.split(" ", Qt::SkipEmptyParts);
                    } else if (key == "optional_depends") {
                        details["optional_dependencies"] = value.split(" ", Qt::SkipEmptyParts);
                    } else if (key == "conflicts_with") {
                        details["conflicts"] = value.split(" ", Qt::SkipEmptyParts);
                    } else if (key == "replaces") {
                        details["replaces"] = value.split(" ", Qt::SkipEmptyParts);
                    } else if (key == "download_size") {
                        details["download_size"] = value;
                    } else if (key == "installed_size") {
                        details["installed_size"] = value;
                    } else if (key == "packager") {
                        details["packager"] = value;
                    } else if (key == "build_date") {
                        details["build_date"] = value;
                    } else if (key == "install_date") {
                        details["install_date"] = value;
                        details["installed"] = true;
                    }
                }
            }
        }
    }
    
    // If no install date, package is not installed
    if (!details.contains("installed")) {
        details["installed"] = false;
    }
    
    return details;
}

void PacmanBackend::runPacmanCommand(const QStringList &args)
{
    m_process->start("pacman", args);
}

void PacmanBackend::runAsRoot(const QStringList &args)
{
    // Use pkexec to run as root
    QStringList fullArgs = {"--disable-internal-agent"};
    fullArgs.append(args);
    
    m_process->start("pkexec", fullArgs);
}
