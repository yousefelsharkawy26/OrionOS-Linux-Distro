package repository

import (
	"database/sql"

	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/model"
)

type MessageRepository struct {
	db *Database
}

func NewMessageRepository(db *Database) *MessageRepository {
	return &MessageRepository{db: db}
}

func (r *MessageRepository) Create(message *model.Message) error {
	query := `
		INSERT INTO messages (id, sender_id, receiver_id, type, payload, timestamp, acknowledged, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	_, err := r.db.Exec(query,
		message.ID,
		message.SenderID,
		message.ReceiverID,
		message.Type,
		message.Payload,
		message.Timestamp,
		message.Acknowledged,
		message.CreatedAt,
	)

	return err
}

func (r *MessageRepository) GetByReceiverID(receiverID string) ([]*model.Message, error) {
	query := `
		SELECT id, sender_id, receiver_id, type, payload, timestamp, acknowledged, acked_at, created_at
		FROM messages
		WHERE receiver_id = $1 AND acknowledged = FALSE
		ORDER BY timestamp ASC
	`

	rows, err := r.db.Query(query, receiverID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []*model.Message

	for rows.Next() {
		message := &model.Message{}

		err := rows.Scan(
			&message.ID,
			&message.SenderID,
			&message.ReceiverID,
			&message.Type,
			&message.Payload,
			&message.Timestamp,
			&message.Acknowledged,
			&message.AckedAt,
			&message.CreatedAt,
		)

		if err != nil {
			return nil, err
		}

		messages = append(messages, message)
	}

	return messages, nil
}

func (r *MessageRepository) Delete(id string) error {
	query := `DELETE FROM messages WHERE id = $1`
	_, err := r.db.Exec(query, id)
	return err
}

func (r *MessageRepository) Acknowledge(id string) error {
	query := `
		UPDATE messages
		SET acknowledged = TRUE, acked_at = NOW()
		WHERE id = $1
	`
	_, err := r.db.Exec(query, id)
	return err
}
