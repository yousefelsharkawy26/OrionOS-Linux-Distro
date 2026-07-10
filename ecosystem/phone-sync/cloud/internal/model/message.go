package model

import (
	"time"
)

type Message struct {
	ID         string    `json:"id" db:"id"`
	SenderID   string    `json:"sender_id" db:"sender_id"`
	ReceiverID string    `json:"receiver_id" db:"receiver_id"`
	Type       string    `json:"type" db:"type"`
	Payload    []byte    `json:"payload" db:"payload"`
	Timestamp  time.Time `json:"timestamp" db:"timestamp"`
	Acknowledged bool    `json:"acknowledged" db:"acknowledged"`
	AckedAt    *time.Time `json:"acked_at" db:"acked_at"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}

type ClipboardMessage struct {
	Text        string `json:"text"`
	BinaryData  []byte `json:"binary_data,omitempty"`
	Files       []FileMetadata `json:"files,omitempty"`
}

type FileMetadata struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Size     uint64 `json:"size"`
	MimeType string `json:"mime_type"`
	Checksum string `json:"checksum"`
}

type NotificationMessage struct {
	ID          string            `json:"id"`
	AppName     string            `json:"app_name"`
	PackageName string            `json:"package_name"`
	Title       string            `json:"title"`
	Text        string            `json:"text"`
	Timestamp   int64             `json:"timestamp"`
	Actions     map[string]string `json:"actions"`
}

type SMSMessage struct {
	ID          string `json:"id"`
	ThreadID    string `json:"thread_id"`
	Address     string `json:"address"`
	ContactName string `json:"contact_name,omitempty"`
	Text        string `json:"text"`
	Timestamp   int64  `json:"timestamp"`
	Incoming    bool   `json:"incoming"`
}

type PairingRequest struct {
	SenderID    string `json:"sender_id"`
	ReceiverID  string `json:"receiver_id"`
	PairingCode string `json:"pairing_code"`
}

type PairingResponse struct {
	ReceiverID string `json:"receiver_id"`
	Status     string `json:"status"` // accepted, rejected
	PublicKey  string `json:"public_key,omitempty"`
}
