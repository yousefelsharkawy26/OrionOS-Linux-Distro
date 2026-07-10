package repository

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/model"
)

type DeviceRepository struct {
	db *Database
}

func NewDeviceRepository(db *Database) *DeviceRepository {
	return &DeviceRepository{db: db}
}

func (r *DeviceRepository) Create(device *model.Device) error {
	device.ID = uuid.New().String()
	device.CreatedAt = time.Now()
	device.UpdatedAt = time.Now()
	device.LastSeen = time.Now()

	query := `
		INSERT INTO devices (id, user_id, device_name, device_type, os_version, app_version, public_key, last_seen, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	_, err := r.db.Exec(query,
		device.ID,
		device.UserID,
		device.DeviceName,
		device.DeviceType,
		device.OSVersion,
		device.AppVersion,
		device.PublicKey,
		device.LastSeen,
		device.CreatedAt,
		device.UpdatedAt,
	)

	return err
}

func (r *DeviceRepository) GetByID(id string) (*model.Device, error) {
	device := &model.Device{}

	query := `
		SELECT id, user_id, device_name, device_type, os_version, app_version, public_key, last_seen, created_at, updated_at
		FROM devices
		WHERE id = $1
	`

	err := r.db.QueryRow(query, id).Scan(
		&device.ID,
		&device.UserID,
		&device.DeviceName,
		&device.DeviceType,
		&device.OSVersion,
		&device.AppVersion,
		&device.PublicKey,
		&device.LastSeen,
		&device.CreatedAt,
		&device.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}

	if err != nil {
		return nil, err
	}

	// Check if device is online (last seen within 5 minutes)
	device.IsOnline = time.Since(device.LastSeen) < 5*time.Minute

	return device, nil
}

func (r *DeviceRepository) ListByUserID(userID string) ([]*model.Device, error) {
	query := `
		SELECT id, user_id, device_name, device_type, os_version, app_version, public_key, last_seen, created_at, updated_at
		FROM devices
		WHERE user_id = $1
		ORDER BY last_seen DESC
	`

	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []*model.Device

	for rows.Next() {
		device := &model.Device{}

		err := rows.Scan(
			&device.ID,
			&device.UserID,
			&device.DeviceName,
			&device.DeviceType,
			&device.OSVersion,
			&device.AppVersion,
			&device.PublicKey,
			&device.LastSeen,
			&device.CreatedAt,
			&device.UpdatedAt,
		)

		if err != nil {
			return nil, err
		}

		device.IsOnline = time.Since(device.LastSeen) < 5*time.Minute
		devices = append(devices, device)
	}

	return devices, nil
}

func (r *DeviceRepository) Update(device *model.Device) error {
	device.UpdatedAt = time.Now()

	query := `
		UPDATE devices
		SET device_name = $2, device_type = $3, os_version = $4, app_version = $5, public_key = $6, last_seen = $7, updated_at = $8
		WHERE id = $1
	`

	_, err := r.db.Exec(query,
		device.ID,
		device.DeviceName,
		device.DeviceType,
		device.OSVersion,
		device.AppVersion,
		device.PublicKey,
		device.LastSeen,
		device.UpdatedAt,
	)

	return err
}

func (r *DeviceRepository) UpdateLastSeen(id string) error {
	query := `
		UPDATE devices
		SET last_seen = NOW(), updated_at = NOW()
		WHERE id = $1
	`

	_, err := r.db.Exec(query, id)
	return err
}

func (r *DeviceRepository) Delete(id string) error {
	query := `DELETE FROM devices WHERE id = $1`
	_, err := r.db.Exec(query, id)
	return err
}

func (r *DeviceRepository) CreatePairing(pairing *model.DevicePairing) error {
	pairing.ID = uuid.New().String()
	pairing.CreatedAt = time.Now()

	query := `
		INSERT INTO device_pairings (id, sender_id, receiver_id, pairing_code, status, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	_, err := r.db.Exec(query,
		pairing.ID,
		pairing.SenderID,
		pairing.ReceiverID,
		pairing.PairingCode,
		pairing.Status,
		pairing.CreatedAt,
	)

	return err
}

func (r *DeviceRepository) GetPairingByCode(code string) (*model.DevicePairing, error) {
	pairing := &model.DevicePairing{}

	query := `
		SELECT id, sender_id, receiver_id, pairing_code, status, paired_at, created_at
		FROM device_pairings
		WHERE pairing_code = $1 AND status = 'pending'
	`

	err := r.db.QueryRow(query, code).Scan(
		&pairing.ID,
		&pairing.SenderID,
		&pairing.ReceiverID,
		&pairing.PairingCode,
		&pairing.Status,
		&pairing.PairedAt,
		&pairing.CreatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}

	if err != nil {
		return nil, err
	}

	return pairing, nil
}

func (r *DeviceRepository) UpdatePairingStatus(id string, status string) error {
	query := `
		UPDATE device_pairings
		SET status = $2, paired_at = CASE WHEN $2 = 'accepted' THEN NOW() ELSE paired_at END
		WHERE id = $1
	`

	_, err := r.db.Exec(query, id, status)
	return err
}

func (r *DeviceRepository) GetPairedDevices(deviceID string) ([]*model.Device, error) {
	query := `
		SELECT d.id, d.user_id, d.device_name, d.device_type, d.os_version, d.app_version, d.public_key, d.last_seen, d.created_at, d.updated_at
		FROM devices d
		INNER JOIN device_pairings dp ON (dp.sender_id = d.id OR dp.receiver_id = d.id)
		WHERE (dp.sender_id = $1 OR dp.receiver_id = $1) AND dp.status = 'accepted' AND d.id != $1
	`

	rows, err := r.db.Query(query, deviceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []*model.Device

	for rows.Next() {
		device := &model.Device{}

		err := rows.Scan(
			&device.ID,
			&device.UserID,
			&device.DeviceName,
			&device.DeviceType,
			&device.OSVersion,
			&device.AppVersion,
			&device.PublicKey,
			&device.LastSeen,
			&device.CreatedAt,
			&device.UpdatedAt,
		)

		if err != nil {
			return nil, err
		}

		device.IsOnline = time.Since(device.LastSeen) < 5*time.Minute
		devices = append(devices, device)
	}

	return devices, nil
}
