package service

import (
	"time"

	"github.com/google/uuid"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/model"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/repository"
)

type MessageService struct {
	messageRepo *repository.MessageRepository
	deviceRepo  *repository.DeviceRepository
}

func NewMessageService(messageRepo *repository.MessageRepository, deviceRepo *repository.DeviceRepository) *MessageService {
	return &MessageService{
		messageRepo: messageRepo,
		deviceRepo:  deviceRepo,
	}
}

func (s *MessageService) SendMessage(senderID, receiverID, msgType string, payload []byte) (*model.Message, error) {
	// Verify receiver exists
	receiver, err := s.deviceRepo.GetByID(receiverID)
	if err != nil {
		return nil, err
	}

	if receiver == nil {
		return nil, fmt.Errorf("receiver device not found")
	}

	// Create message
	message := &model.Message{
		ID:         uuid.New().String(),
		SenderID:   senderID,
		ReceiverID: receiverID,
		Type:       msgType,
		Payload:    payload,
		Timestamp:  time.Now(),
	}

	if err := s.messageRepo.Create(message); err != nil {
		return nil, err
	}

	return message, nil
}

func (s *MessageService) GetMessages(deviceID string) ([]*model.Message, error) {
	return s.messageRepo.GetByReceiverID(deviceID)
}

func (s *MessageService) DeleteMessage(messageID string) error {
	return s.messageRepo.Delete(messageID)
}

func (s *MessageService) AcknowledgeMessage(messageID string) error {
	return s.messageRepo.Acknowledge(messageID)
}
