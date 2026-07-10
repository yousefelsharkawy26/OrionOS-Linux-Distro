package service

import (
	"crypto/rand"
	"fmt"
	"math/big"

	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/model"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/repository"
)

type DeviceService struct {
	deviceRepo *repository.DeviceRepository
}

func NewDeviceService(deviceRepo *repository.DeviceRepository) *DeviceService {
	return &DeviceService{deviceRepo: deviceRepo}
}

func (s *DeviceService) RegisterDevice(device *model.Device) error {
	return s.deviceRepo.Create(device)
}

func (s *DeviceService) GetDevice(id string) (*model.Device, error) {
	return s.deviceRepo.GetByID(id)
}

func (s *DeviceService) ListDevices(userID string) ([]*model.Device, error) {
	return s.deviceRepo.ListByUserID(userID)
}

func (s *DeviceService) DeleteDevice(id string) error {
	return s.deviceRepo.Delete(id)
}

func (s *DeviceService) Heartbeat(deviceID string) error {
	return s.deviceRepo.UpdateLastSeen(deviceID)
}

func (s *DeviceService) GetPairedDevices(deviceID string) ([]*model.Device, error) {
	return s.deviceRepo.GetPairedDevices(deviceID)
}

func (s *DeviceService) CreatePairingRequest(senderID, receiverID string) (*model.DevicePairing, error) {
	// Generate pairing code
	code, err := generatePairingCode()
	if err != nil {
		return nil, err
	}

	pairing := &model.DevicePairing{
		SenderID:    senderID,
		ReceiverID:  receiverID,
		PairingCode: code,
		Status:      "pending",
	}

	if err := s.deviceRepo.CreatePairing(pairing); err != nil {
		return nil, err
	}

	return pairing, nil
}

func (s *DeviceService) AcceptPairing(code, publicKey string) error {
	pairing, err := s.deviceRepo.GetPairingByCode(code)
	if err != nil {
		return err
	}

	if pairing == nil {
		return fmt.Errorf("invalid or expired pairing code")
	}

	// Update pairing status
	if err := s.deviceRepo.UpdatePairingStatus(pairing.ID, "accepted"); err != nil {
		return err
	}

	return nil
}

func (s *DeviceService) RejectPairing(code string) error {
	pairing, err := s.deviceRepo.GetPairingByCode(code)
	if err != nil {
		return err
	}

	if pairing == nil {
		return fmt.Errorf("invalid or expired pairing code")
	}

	return s.deviceRepo.UpdatePairingStatus(pairing.ID, "rejected")
}

func (s *DeviceService) UnpairDevices(deviceID string) error {
	// TODO: Implement unpairing logic
	return nil
}

func generatePairingCode() (string, error) {
	code := ""
	for i := 0; i < 6; i++ {
		n, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			return "", err
		}
		code += fmt.Sprintf("%d", n.Int64())
	}
	return code, nil
}
