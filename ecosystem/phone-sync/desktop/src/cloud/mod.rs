use anyhow::Result;
use reqwest;
use tracing::{info, warn, error};

pub async fn run(cloud_url: String, keys: crate::encryption::KeyManager) -> Result<()> {
    info!("Starting cloud service with URL: {}", cloud_url);
    
    // Connect to cloud service
    connect_to_cloud(&cloud_url, keys).await
}

async fn connect_to_cloud(cloud_url: &str, keys: crate::encryption::KeyManager) -> Result<()> {
    info!("Connecting to cloud service: {}", cloud_url);
    
    // Create HTTP client
    let client = reqwest::Client::new();
    
    // Register device
    let device_id = keys.device_id();
    let public_key = BASE64.encode(keys.public_key_bytes());
    
    let register_url = format!("{}/api/v1/device/register", cloud_url);
    let register_body = serde_json::json!({
        "device_id": device_id,
        "device_name": hostname::get()?.to_string_lossy(),
        "device_type": "desktop",
        "public_key": public_key
    });
    
    let response = client.post(&register_url)
        .json(&register_body)
        .send()
        .await?;
    
    if response.status().is_success() {
        info!("Device registered successfully");
        
        // Start listening for messages
        listen_for_cloud_messages(&cloud_url, &device_id, &client).await?;
    } else {
        error!("Failed to register device: {}", response.status());
    }
    
    Ok(())
}

async fn listen_for_cloud_messages(cloud_url: &str, device_id: &str, client: &reqwest::Client) -> Result<()> {
    info!("Listening for cloud messages");
    
    loop {
        // Poll for messages
        let messages_url = format!("{}/api/v1/device/{}/messages", cloud_url, device_id);
        
        match client.get(&messages_url).send().await {
            Ok(response) => {
                if response.status().is_success() {
                    let messages: Vec<serde_json::Value> = response.json().await?;
                    
                    for message in messages {
                        info!("Received cloud message: {:?}", message);
                        
                        // Process message
                        process_cloud_message(message).await?;
                    }
                }
            }
            Err(e) => {
                warn!("Failed to poll messages: {}", e);
            }
        }
        
        tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
    }
}

async fn process_cloud_message(message: serde_json::Value) -> Result<()> {
    // Process message based on type
    if let Some(message_type) = message["type"].as_str() {
        match message_type {
            "clipboard" => {
                info!("Received clipboard message via cloud");
                // Handle clipboard
            }
            "notification" => {
                info!("Received notification via cloud");
                // Handle notification
            }
            _ => {
                warn!("Unknown cloud message type: {}", message_type);
            }
        }
    }
    
    Ok(())
}

use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;
