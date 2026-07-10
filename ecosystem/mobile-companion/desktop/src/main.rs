use clap::Parser;
use std::path::PathBuf;

mod bluetooth;
mod clipboard;
mod file_transfer;
mod media_control;
mod notification;
mod remote_input;
mod sms;
mod screen_mirror;

#[derive(Parser)]
#[command(name = "orionos-mobile-companion")]
#[command(about = "OrionOS Mobile Companion - Desktop side of mobile integration")]
struct Cli {
    #[arg(short, long, default_value = "0.0.0.0")]
    host: String,

    #[arg(short, long, default_value = "8420")]
    port: u16,

    #[arg(long)]
    daemon: bool,

    #[arg(long)]
    bluetooth_only: bool,

    #[arg(long)]
    status: bool,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    env_logger::init();
    let cli = Cli::parse();

    if cli.status {
        print_status().await;
        return Ok(());
    }

    log::info!("Starting OrionOS Mobile Companion on {}:{}", cli.host, cli.port);

    let config = load_config()?;

    if cli.bluetooth_only {
        bluetooth::start_bluetooth_service(&config).await?;
    } else {
        let handles = vec![
            tokio::spawn(bluetooth::start_bluetooth_service(config.clone())),
            tokio::spawn(clipboard::start_clipboard_sync(config.clone())),
            tokio::spawn(file_transfer::start_file_server(config.clone())),
            tokio::spawn(media_control::start_media_server(config.clone())),
            tokio::spawn(notification::start_notification_bridge(config.clone())),
            tokio::spawn(remote_input::start_remote_input(config.clone())),
            tokio::spawn(sms::start_sms_bridge(config.clone())),
        ];

        for handle in handles {
            handle.await??;
        }
    }

    Ok(())
}

async fn print_status() {
    println!("=== OrionOS Mobile Companion Status ===");
    println!("Bluetooth: {}", check_bluetooth().await);
    println!("Clipboard sync: active");
    println!("File transfer: listening on port 8421");
    println!("Media control: listening on port 8422");
    println!("Notification bridge: active");
    println!("Remote input: listening on port 8423");
    println!("SMS bridge: active");
}

async fn check_bluetooth() -> &'static str {
    if bluer::Adapter::available().await.is_ok() { "available" } else { "unavailable" }
}

fn load_config() -> anyhow::Result<CompanionConfig> {
    let config_path = PathBuf::from("/etc/orionos/mobile-companion.conf");
    if config_path.exists() {
        let content = std::fs::read_to_string(&config_path)?;
        Ok(serde_json::from_str(&content)?)
    } else {
        Ok(CompanionConfig::default())
    }
}

#[derive(Clone, Debug, serde::Deserialize, serde::Serialize)]
struct CompanionConfig {
    pub bluetooth_name: String,
    pub enable_clipboard: bool,
    pub enable_file_transfer: bool,
    pub enable_media_control: bool,
    pub enable_notifications: bool,
    pub enable_remote_input: bool,
    pub enable_sms: bool,
    pub encryption_key: String,
    pub max_file_size_mb: u64,
    pub auto_accept_files: bool,
    pub notification_forward: bool,
}

impl Default for CompanionConfig {
    fn default() -> Self {
        Self {
            bluetooth_name: "OrionOS Desktop".to_string(),
            enable_clipboard: true,
            enable_file_transfer: true,
            enable_media_control: true,
            enable_notifications: true,
            enable_remote_input: true,
            enable_sms: true,
            encryption_key: String::new(),
            max_file_size_mb: 4096,
            auto_accept_files: false,
            notification_forward: true,
        }
    }
}
