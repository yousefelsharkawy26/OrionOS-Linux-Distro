use anyhow::Result;
use tokio::sync::broadcast;
use tracing::{info, warn, error};

pub async fn run(keys: crate::encryption::KeyManager) -> Result<()> {
    info!("Starting clipboard service");
    
    // Watch clipboard for changes
    watch_clipboard().await
}

async fn watch_clipboard() -> Result<()> {
    let mut last_content = String::new();
    
    loop {
        match get_clipboard_content().await {
            Ok(content) => {
                if content != last_content && !content.is_empty() {
                    info!("Clipboard changed: {} chars", content.len());
                    
                    // Send clipboard to connected devices
                    send_clipboard_to_devices(&content).await?;
                    
                    last_content = content;
                }
            }
            Err(e) => {
                warn!("Failed to read clipboard: {}", e);
            }
        }
        
        tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
    }
}

async fn get_clipboard_content() -> Result<String> {
    // Use xclip or xsel to get clipboard content
    let output = tokio::process::Command::new("xclip")
        .args(["-selection", "clipboard", "-o"])
        .output()
        .await?;
    
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        // Try xsel as fallback
        let output = tokio::process::Command::new("xsel")
            .args(["--clipboard", "--output"])
            .output()
            .await?;
        
        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            Err(anyhow::anyhow!("Failed to get clipboard content"))
        }
    }
}

async fn set_clipboard_content(content: &str) -> Result<()> {
    // Use xclip to set clipboard content
    let mut child = tokio::process::Command::new("xclip")
        .args(["-selection", "clipboard"])
        .stdin(std::process::Stdio::piped())
        .spawn()?;
    
    if let Some(mut stdin) = child.stdin.take() {
        stdin.write_all(content.as_bytes()).await?;
    }
    
    child.wait().await?;
    
    Ok(())
}

async fn send_clipboard_to_devices(content: &str) -> Result<()> {
    // This would send the clipboard content to connected devices
    // via Bluetooth or WiFi
    info!("Sending clipboard to devices: {} chars", content.len());
    
    // TODO: Implement actual sending logic
    
    Ok(())
}

pub async fn receive_clipboard(content: &str) -> Result<()> {
    info!("Received clipboard from device: {} chars", content.len());
    
    // Set local clipboard
    set_clipboard_content(content).await?;
    
    Ok(())
}
