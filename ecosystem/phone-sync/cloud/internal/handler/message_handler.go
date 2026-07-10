package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/service"
)

type MessageHandler struct {
	messageService *service.MessageService
	authService    *service.AuthService
}

func NewMessageHandler(messageService *service.MessageService, authService *service.AuthService) *MessageHandler {
	return &MessageHandler{
		messageService: messageService,
		authService:    authService,
	}
}

func (h *MessageHandler) Send(c *gin.Context) {
	var req struct {
		ReceiverID string `json:"receiver_id" binding:"required"`
		Type       string `json:"type" binding:"required"`
		Payload    []byte `json:"payload" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get sender ID from auth token
	senderID, exists := c.Get("device_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	message, err := h.messageService.SendMessage(senderID.(string), req.ReceiverID, req.Type, req.Payload)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, message)
}

func (h *MessageHandler) GetMessages(c *gin.Context) {
	deviceID := c.Param("deviceId")

	messages, err := h.messageService.GetMessages(deviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, messages)
}

func (h *MessageHandler) DeleteMessage(c *gin.Context) {
	messageID := c.Param("messageId")

	if err := h.messageService.DeleteMessage(messageID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "message deleted"})
}

func (h *MessageHandler) Acknowledge(c *gin.Context) {
	messageID := c.Param("messageId")

	if err := h.messageService.AcknowledgeMessage(messageID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "message acknowledged"})
}
