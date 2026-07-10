package repository

import (
	"database/sql"
	"fmt"
	"time"

	_ "github.com/lib/pq"
)

type Database struct {
	*sql.DB
}

func NewDatabase(databaseURL string) (*Database, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Test connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	// Set connection pool settings
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(25)
	db.SetConnMaxLifetime(5 * time.Minute)

	// Run migrations
	if err := runMigrations(db); err != nil {
		return nil, fmt.Errorf("failed to run migrations: %w", err)
	}

	return &Database{db}, nil
}

func (d *Database) Close() error {
	return d.DB.Close()
}

func runMigrations(db *sql.DB) error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS devices (
			id VARCHAR(36) PRIMARY KEY,
			user_id VARCHAR(36) NOT NULL,
			device_name VARCHAR(255) NOT NULL,
			device_type VARCHAR(50) NOT NULL,
			os_version VARCHAR(100),
			app_version VARCHAR(100),
			public_key TEXT NOT NULL,
			last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
			updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		)`,
		`CREATE TABLE IF NOT EXISTS device_pairings (
			id VARCHAR(36) PRIMARY KEY,
			sender_id VARCHAR(36) NOT NULL REFERENCES devices(id),
			receiver_id VARCHAR(36) NOT NULL REFERENCES devices(id),
			pairing_code VARCHAR(10) NOT NULL,
			status VARCHAR(20) NOT NULL DEFAULT 'pending',
			paired_at TIMESTAMP WITH TIME ZONE,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		)`,
		`CREATE TABLE IF NOT EXISTS device_sessions (
			id VARCHAR(36) PRIMARY KEY,
			device_id VARCHAR(36) NOT NULL REFERENCES devices(id),
			token TEXT NOT NULL,
			refresh_token TEXT NOT NULL,
			expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		)`,
		`CREATE TABLE IF NOT EXISTS messages (
			id VARCHAR(36) PRIMARY KEY,
			sender_id VARCHAR(36) NOT NULL REFERENCES devices(id),
			receiver_id VARCHAR(36) NOT NULL REFERENCES devices(id),
			type VARCHAR(50) NOT NULL,
			payload BYTEA NOT NULL,
			timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
			acknowledged BOOLEAN DEFAULT FALSE,
			acked_at TIMESTAMP WITH TIME ZONE,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		)`,
		`CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id, acknowledged)`,
		`CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id)`,
		`CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id)`,
		`CREATE INDEX IF NOT EXISTS idx_pairings_receiver ON device_pairings(receiver_id, status)`,
	}

	for _, query := range queries {
		if _, err := db.Exec(query); err != nil {
			return fmt.Errorf("failed to execute migration: %w", err)
		}
	}

	return nil
}
