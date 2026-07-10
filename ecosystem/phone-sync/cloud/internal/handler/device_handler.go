package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/model"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/service"
)

type DeviceHandler struct {
	deviceService *service.DeviceService
	authService   *service.AuthService
}

func NewDeviceHandler(deviceService *service.DeviceService, authService *service.AuthService) *DeviceHandler {
	return &DeviceHandler{
		deviceService: deviceService,
		authService:   authService,
	}
}

func (h *DeviceHandler) Register(c *gin.Context) {
	var req struct {
		DeviceName string `json:"device_name" binding:"required"`
		DeviceType string `json:"device_type" binding:"required"`
		OSVersion  string `json:"os_version"`
		AppVersion string `json:"app_version"`
		PublicKey  string `json:"public_key" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get user ID from auth token
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	device := &model.Device{
		UserID:     userID.(string),
		DeviceName: req.DeviceName,
		DeviceType: req.DeviceType,
		OSVersion:  req.OSVersion,
		AppVersion: req.AppVersion,
		PublicKey:  req.PublicKey,
	}

	if err := h.deviceService.RegisterDevice(device); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, device)
}

func (h *DeviceHandler) GetDevice(c *gin.Context) {
	deviceID := c.Param("deviceId")

	device, err := h.deviceService.GetDevice(deviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if device == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "device not found"})
		return
	}

	c.JSON(http.StatusOK, device)
}

func (h *DeviceHandler) ListDevices(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	devices, err := h.deviceService.ListDevices(userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, devices)
}

func (h *DeviceHandler) DeleteDevice(c *gin.Context) {
	deviceID := c.Param("deviceId")

	if err := h.deviceService.DeleteDevice(deviceID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "device deleted"})
}

func (h *DeviceHandler) Heartbeat(c *gin.Context) {
	deviceID := c.Param("deviceId")

	if err := h.deviceService.Heartbeat(deviceID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Get paired devices
	pairedDevices, err := h.deviceService.GetPairedDevices(deviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"online":         true,
		"online_devices": pairedDevices,
	})
}

func (h *DeviceHandler) PairingRequest(c *gin.Context) {
	var req struct {
		SenderID   string `json:"sender_id" binding:"required"`
		ReceiverID string `json:"receiver_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	pairing, err := h.deviceService.CreatePairingRequest(req.SenderID, req.ReceiverID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, pairing)
}

func (h *DeviceHandler) PairingAccept(c *gin.Context) {
	var req struct {
		PairingCode string `json:"pairing_code" binding:"required"`
		PublicKey   string `json:"public_key"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.deviceService.AcceptPairing(req.PairingCode, req.PublicKey); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "pairing accepted"})
}

func (h *DeviceHandler) PairingReject(c *gin.Context) {
	var req struct {
		PairingCode string `json:"pairing_code" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.deviceService.RejectPairing(req.PairingCode); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "pairing rejected"})
}

func (h *DeviceHandler) Unpair(c *gin.Context) {
	deviceID := c.Param("deviceId")

	if err := h.deviceService.UnpairDevices(deviceID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "devices unpaired"})
}
