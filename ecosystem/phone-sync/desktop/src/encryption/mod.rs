use aes_gcm::{aead::Aead, Aes256Gcm, KeyInit};
use anyhow::Result;
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tracing::{info, warn};
use x25519_dalek::{EphemeralSecret, PublicKey, StaticSecret};

#[derive(Clone)]
pub struct KeyManager {
    private_key: StaticSecret,
    public_key: PublicKey,
    device_id: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct StoredKeys {
    private_key: String,
    public_key: String,
    device_id: String,
}

impl KeyManager {
    pub async fn new() -> Result<Self> {
        let keys_dir = dirs::config_dir()
            .unwrap_or_default()
            .join("orionos")
            .join("phone-sync")
            .join("keys");
        
        tokio::fs::create_dir_all(&keys_dir).await?;
        
        let keys_file = keys_dir.join("keys.json");
        
        if keys_file.exists() {
            // Load existing keys
            let content = tokio::fs::read_to_string(&keys_file).await?;
            let stored: StoredKeys = serde_json::from_str(&content)?;
            
            let private_key_bytes = BASE64.decode(&stored.private_key)?;
            let private_key = StaticSecret::from(
                <[u8; 32]>::try_from(private_key_bytes)
                    .map_err(|_| anyhow::anyhow!("Invalid private key length"))?
            );
            let public_key = PublicKey::from(&private_key);
            
            info!("Loaded existing encryption keys");
            
            Ok(Self {
                private_key,
                public_key,
                device_id: stored.device_id,
            })
        } else {
            // Generate new keys
            let private_key = StaticSecret::random_from_rng(rand::thread_rng());
            let public_key = PublicKey::from(&private_key);
            let device_id = uuid::Uuid::new_v4().to_string();
            
            // Save keys
            let stored = StoredKeys {
                private_key: BASE64.encode(private_key.to_bytes()),
                public_key: BASE64.encode(public_key.as_bytes()),
                device_id: device_id.clone(),
            };
            
            let content = serde_json::to_string_pretty(&stored)?;
            tokio::fs::write(&keys_file, content).await?;
            
            info!("Generated new encryption keys");
            
            Ok(Self {
                private_key,
                public_key,
                device_id,
            })
        }
    }
    
    pub fn public_key_bytes(&self) -> Vec<u8> {
        self.public_key.as_bytes().to_vec()
    }
    
    pub fn device_id(&self) -> &str {
        &self.device_id
    }
    
    pub fn encrypt(&self, data: &[u8], recipient_public_key: &[u8]) -> Result<Vec<u8>> {
        // Perform key exchange
        let recipient_pk = PublicKey::from(
            <[u8; 32]>::try_from(recipient_public_key)
                .map_err(|_| anyhow::anyhow!("Invalid recipient public key length"))?
        );
        
        let shared_secret = self.private_key.diffie_hellman(&recipient_pk);
        
        // Derive encryption key
        let key = aes_gcm::Key::<Aes256Gcm>::from_slice(shared_secret.as_bytes());
        let cipher = Aes256Gcm::new(key);
        
        // Generate nonce
        let mut rng = rand::thread_rng();
        let nonce_bytes: [u8; 12] = rng.gen();
        let nonce = aes_gcm::Nonce::from_slice(&nonce_bytes);
        
        // Encrypt
        let ciphertext = cipher.encrypt(nonce, data)
            .map_err(|e| anyhow::anyhow!("Encryption failed: {}", e))?;
        
        // Prepend nonce to ciphertext
        let mut result = nonce_bytes.to_vec();
        result.extend_from_slice(&ciphertext);
        
        Ok(result)
    }
    
    pub fn decrypt(&self, encrypted_data: &[u8], sender_public_key: &[u8]) -> Result<Vec<u8>> {
        if encrypted_data.len() < 12 {
            return Err(anyhow::anyhow!("Invalid encrypted data length"));
        }
        
        // Extract nonce
        let nonce_bytes = &encrypted_data[..12];
        let ciphertext = &encrypted_data[12..];
        
        // Perform key exchange
        let sender_pk = PublicKey::from(
            <[u8; 32]>::try_from(sender_public_key)
                .map_err(|_| anyhow::anyhow!("Invalid sender public key length"))?
        );
        
        let shared_secret = self.private_key.diffie_hellman(&sender_pk);
        
        // Derive decryption key
        let key = aes_gcm::Key::<Aes256Gcm>::from_slice(shared_secret.as_bytes());
        let cipher = Aes256Gcm::new(key);
        
        // Decrypt
        let plaintext = cipher.decrypt(
            aes_gcm::Nonce::from_slice(nonce_bytes),
            ciphertext,
        )
        .map_err(|e| anyhow::anyhow!("Decryption failed: {}", e))?;
        
        Ok(plaintext)
    }
    
    pub fn generate_ephemeral_keypair() -> (EphemeralSecret, PublicKey) {
        let secret = EphemeralSecret::random_from_rng(rand::thread_rng());
        let public = PublicKey::from(&secret);
        (secret, public)
    }
}

// Placeholder for proto module
pub mod proto {
    pub use crate::proto::*;
}
