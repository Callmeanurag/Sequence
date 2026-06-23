package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	port := getEnv("PORT", "8080")

	mux := http.NewServeMux()

	// Health endpoints — checked by Kubernetes liveness/readiness probes
	mux.HandleFunc("/healthz", handleHealthz)
	mux.HandleFunc("/readyz", handleReadyz)

	// Auth API endpoints
	mux.HandleFunc("POST /api/v1/auth/register", handleRegister)
	mux.HandleFunc("POST /api/v1/auth/login", handleLogin)
	mux.HandleFunc("POST /api/v1/auth/refresh", handleRefresh)
	mux.HandleFunc("GET /api/v1/auth/me", handleMe)
	mux.HandleFunc("DELETE /api/v1/auth/logout", handleLogout)

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown: wait for in-flight requests before exiting
	go func() {
		slog.Info("auth-service starting", "port", port)
		if err := srv.ListenAndServe(); err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)
	<-quit

	slog.Info("shutting down gracefully")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("shutdown error", "error", err)
	}
}

func handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok"}`))
}

func handleReadyz(w http.ResponseWriter, r *http.Request) {
	// TODO: check Redis and PostgreSQL connectivity
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ready"}`))
}

func handleRegister(w http.ResponseWriter, r *http.Request) {
	// TODO: implement user registration
	// 1. Parse request body
	// 2. Validate email + password
	// 3. Check if email already exists in PostgreSQL
	// 4. Hash password with bcrypt (cost=12)
	// 5. Insert user into PostgreSQL
	// 6. Generate JWT + refresh token
	// 7. Store refresh token in Redis (TTL 7 days)
	// 8. Return 201 with tokens
	http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	// TODO: implement user login
	http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
}

func handleRefresh(w http.ResponseWriter, r *http.Request) {
	// TODO: implement token refresh
	http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
}

func handleMe(w http.ResponseWriter, r *http.Request) {
	// TODO: validate JWT from Authorization header, return user info
	http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
}

func handleLogout(w http.ResponseWriter, r *http.Request) {
	// TODO: invalidate refresh token in Redis
	http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
