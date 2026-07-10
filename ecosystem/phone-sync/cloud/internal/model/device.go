package model

import (
	"time"
)

type Device struct {
	ID          string    `json:"id" db:"id"`
	UserID      string    `json:"user_id" db:"user_id"`
	DeviceName  string    `json:"device_name" db:"device_name"`
	DeviceType  string    `json:"device_type" db:"device_type"`
	OSVersion   string    `json:"os_version" db:"os_version"`
	AppVersion  string    `json:"app_version" db:"app_version"`
	PublicKey   string    `json:"public_key" db:"public_key"`
	LastSeen    time.Time `json:"last_seen" db:"last_seen"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
	IsOnline    bool      `json:"is_online" db:"-"`
}

type DevicePairing struct {
	ID           string    `json:"id" db:"id"`
	SenderID     string    `json:"sender_id" db:"sender_id"`
	ReceiverID   string    `json:"receiver_id" db:"receiver_id"`
	PairingCode  string    `json:"pairing_code" db:"pairing_code"`
	Status       string    `json:"status" db:"status"` // pending, accepted, rejected
	PairedAt     *time.Time `json:"paired_at" db:"paired_at"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

type DeviceSession struct {
	ID           string    `json:"id" db:"id"`
	DeviceID     string    `json:"device_id" db:"device_id"`
	Token        string    `json:"token" db:"token"`
	RefreshToken string    `json:"refresh_token" db:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at" db:"expires_at"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}
