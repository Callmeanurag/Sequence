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

	httpPort := getEnv("HTTP_PORT", "8080")
	wsPort := getEnv("WS_PORT", "8081")

	// HTTP API server (REST endpoints for game management)
	httpMux := http.NewServeMux()
	httpMux.HandleFunc("/healthz", handleHealthz)
	httpMux.HandleFunc("/readyz", handleReadyz)
	httpMux.HandleFunc("POST /api/v1/games", handleCreateGame)
	httpMux.HandleFunc("POST /api/v1/games/{gameId}/join", handleJoinGame)
	httpMux.HandleFunc("GET /api/v1/games/{gameId}", handleGetGame)

	// WebSocket server (real-time game moves)
	wsMux := http.NewServeMux()
	wsMux.HandleFunc("/ws/{gameId}", handleWebSocket)

	httpSrv := &http.Server{
		Addr:        ":" + httpPort,
		Handler:     httpMux,
		ReadTimeout: 15 * time.Second,
	}

	wsSrv := &http.Server{
		Addr:         ":" + wsPort,
		Handler:      wsMux,
		ReadTimeout:  0,             // No timeout for WebSocket connections
		WriteTimeout: 0,
		IdleTimeout:  4 * time.Hour, // Max game duration
	}

	go func() {
		slog.Info("game-service HTTP starting", "port", httpPort)
		if err := httpSrv.ListenAndServe(); err != http.ErrServerClosed {
			slog.Error("HTTP server error", "error", err)
		}
	}()

	go func() {
		slog.Info("game-service WebSocket starting", "port", wsPort)
		if err := wsSrv.ListenAndServe(); err != http.ErrServerClosed {
			slog.Error("WebSocket server error", "error", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)
	<-quit

	// Graceful shutdown: allow active games to complete or checkpoint
	slog.Info("shutting down game-service", "gracePeriod", "60s")
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	httpSrv.Shutdown(ctx)
	wsSrv.Shutdown(ctx)
}

func handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok"}`))
}

func handleReadyz(w http.ResponseWriter, r *http.Request) {
	// TODO: verify Redis connectivity
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ready"}`))
}

func handleCreateGame(w http.ResponseWriter, r *http.Request) {
	// TODO: create game session, store in Redis, return gameId
	http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
}

func handleJoinGame(w http.ResponseWriter, r *http.Request) {
	// TODO: add player to game session in Redis
	http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
}

func handleGetGame(w http.ResponseWriter, r *http.Request) {
	// TODO: read game state from Redis, return to client
	http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	// TODO: upgrade to WebSocket, handle game moves
	// Sequence:
	// 1. Validate JWT from query param
	// 2. Upgrade HTTP to WebSocket
	// 3. Send current game state to client
	// 4. Enter message loop: read move → validate → update Redis → broadcast
	// 5. Publish NATS event for async consumers
	http.Error(w, "websocket upgrade required", http.StatusUpgradeRequired)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
