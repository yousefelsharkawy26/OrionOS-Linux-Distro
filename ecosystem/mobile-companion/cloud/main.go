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
)

type Config struct {
	Host           string
	Port           int
	DBHost         string
	DBPort         int
	DBName         string
	JWTSecret      string
	EnablePairing  bool
	MaxConnections int
}

func loadConfig() Config {
	return Config{
		Host:           getEnv("HOST", "0.0.0.0"),
		Port:           getEnvInt("PORT", 8420),
		DBHost:         getEnv("DB_HOST", "localhost"),
		DBPort:         getEnvInt("DB_PORT", 5432),
		DBName:         getEnv("DB_NAME", "mobile_companion"),
		JWTSecret:      getEnv("JWT_SECRET", "orionos-companion-secret"),
		EnablePairing:  true,
		MaxConnections: 100,
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		var n int
		fmt.Sscanf(v, "%d", &n)
		if n > 0 {
			return n
		}
	}
	return fallback
}

func main() {
	config := loadConfig()

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"status":"ok","service":"mobile-companion"}`)
	})
	mux.HandleFunc("/api/v1/pair", handlePair)
	mux.HandleFunc("/api/v1/clipboard", handleClipboard)
	mux.HandleFunc("/api/v1/files", handleFiles)
	mux.HandleFunc("/api/v1/notifications", handleNotifications)
	mux.HandleFunc("/api/v1/media", handleMedia)
	mux.HandleFunc("/api/v1/sms", handleSMS)
	mux.HandleFunc("/api/v1/remote", handleRemote)

	server := &http.Server{
		Addr:         fmt.Sprintf("%s:%d", config.Host, config.Port),
		Handler:      mux,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		log.Printf("Mobile Companion server starting on %s:%d", config.Host, config.Port)
		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	<-ctx.Done()
	log.Println("Shutting down...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	server.Shutdown(shutdownCtx)
	log.Println("Server stopped")
}

func handlePair(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"pairing_endpoint","method":"POST"}`)
}

func handleClipboard(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"clipboard_sync","method":"POST"}`)
}

func handleFiles(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"file_transfer","method":"POST"}`)
}

func handleNotifications(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"notifications","method":"POST"}`)
}

func handleMedia(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"media_control","method":"POST"}`)
}

func handleSMS(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"sms_bridge","method":"POST"}`)
}

func handleRemote(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"remote_input","method":"POST"}`)
}
