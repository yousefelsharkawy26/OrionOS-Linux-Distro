mod bluetooth;
mod cloud;
mod clipboard;
mod encryption;
mod input;
mod notification;
mod pairing;
mod sms;

use anyhow::Result;
use tracing::info;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    info!("Starting OrionOS Phone Sync service");

    // Load configuration
    let config = load_config().await?;
    info!("Configuration loaded: {:?}", config);

    // Initialize encryption
    let keys = encryption::KeyManager::new().await?;
    info!("Encryption keys initialized");

    // Start services
    let mut handles = vec![];

    // Bluetooth service
    if config.bluetooth_enabled {
        let keys_clone = keys.clone();
        handles.push(tokio::spawn(async move {
            bluetooth::run(keys_clone).await
        }));
    }

    // Clipboard service
    let keys_clone = keys.clone();
    handles.push(tokio::spawn(async move {
        clipboard::run(keys_clone).await
    }));

    // Notification service
    let keys_clone = keys.clone();
    handles.push(tokio::spawn(async move {
        notification::run(keys_clone).await
    }));

    // Cloud service
    if config.cloud_enabled {
        let keys_clone = keys.clone();
        handles.push(tokio::spawn(async move {
            cloud::run(config.cloud_url.clone(), keys_clone).await
        }));
    }

    // Wait for all services
    for handle in handles {
        handle.await??;
    }

    Ok(())
}

async fn load_config() -> Result<Config> {
    let config_path = dirs::config_dir()
        .unwrap_or_default()
        .join("orionos")
        .join("phone-sync")
        .join("config.json");

    if config_path.exists() {
        let content = tokio::fs::read_to_string(&config_path).await?;
        Ok(serde_json::from_str(&content)?)
    } else {
        // Create default config
        let config = Config::default();
        let content = serde_json::to_string_pretty(&config)?;
        tokio::fs::create_dir_all(config_path.parent().unwrap()).await?;
        tokio::fs::write(&config_path, content).await?;
        Ok(config)
    }
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct Config {
    pub device_name: String,
    pub bluetooth_enabled: bool,
    pub cloud_enabled: bool,
    pub cloud_url: String,
    pub wifi_enabled: bool,
    pub discovery_mode: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            device_name: hostname::get()
                .map(|h| h.to_string_lossy().to_string())
                .unwrap_or_else(|_| "OrionOS Desktop".to_string()),
            bluetooth_enabled: true,
            cloud_enabled: true,
            cloud_url: "https://sync.orionos.org".to_string(),
            wifi_enabled: true,
            discovery_mode: "auto".to_string(),
        }
    }
}
