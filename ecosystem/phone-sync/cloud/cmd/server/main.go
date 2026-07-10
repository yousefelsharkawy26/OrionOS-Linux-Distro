package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/api"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/config"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/handler"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/middleware"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/repository"
	"github.com/yousefelsharkawy26/OrionOS-Linux-Distro/ecosystem/phone-sync/cloud/internal/service"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Initialize database
	db, err := repository.NewDatabase(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Initialize repositories
	deviceRepo := repository.NewDeviceRepository(db)
	messageRepo := repository.NewMessageRepository(db)

	// Initialize services
	deviceService := service.NewDeviceService(deviceRepo)
	messageService := service.NewMessageService(messageRepo, deviceRepo)
	authService := service.NewAuthService(cfg.JWTSecret)

	// Initialize handlers
	deviceHandler := handler.NewDeviceHandler(deviceService, authService)
	messageHandler := handler.NewMessageHandler(messageService, authService)
	authHandler := handler.NewAuthHandler(authService)

	// Setup router
	router := setupRouter(cfg, deviceHandler, messageHandler, authHandler)

	// Create server
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Printf("Starting server on port %d", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited gracefully")
}

func setupRouter(cfg *config.Config, deviceHandler *handler.DeviceHandler, messageHandler *handler.MessageHandler, authHandler *handler.AuthHandler) *gin.Engine {
	router := gin.Default()

	// Middleware
	router.Use(middleware.CORS())
	router.Use(middleware.RequestID())
	router.Use(middleware.Logger())

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "healthy",
			"time":   time.Now().UTC(),
		})
	})

	// API v1
	v1 := router.Group("/api/v1")
	{
		// Auth routes
		auth := v1.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
			auth.POST("/refresh", authHandler.RefreshToken)
		}

		// Device routes
		devices := v1.Group("/device")
		{
			devices.POST("/register", deviceHandler.Register)
			devices.GET("/:deviceId", deviceHandler.GetDevice)
			devices.GET("/list", deviceHandler.ListDevices)
			devices.DELETE("/:deviceId", deviceHandler.DeleteDevice)
			devices.POST("/:deviceId/heartbeat", deviceHandler.Heartbeat)
		}

		// Message routes
		messages := v1.Group("/messages")
		{
			messages.POST("/send", messageHandler.Send)
			messages.GET("/:deviceId", messageHandler.GetMessages)
			messages.DELETE("/:messageId", messageHandler.DeleteMessage)
			messages.POST("/:messageId/ack", messageHandler.Acknowledge)
		}

		// Pairing routes
		pairing := v1.Group("/pairing")
		{
			pairing.POST("/request", deviceHandler.PairingRequest)
			pairing.POST("/accept", deviceHandler.PairingAccept)
			pairing.POST("/reject", deviceHandler.PairingReject)
			pairing.DELETE("/:deviceId", deviceHandler.Unpair)
		}
	}

	return router
}
