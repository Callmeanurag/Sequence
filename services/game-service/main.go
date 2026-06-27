package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
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
	httpMux.HandleFunc("/", handleHome)
	httpMux.HandleFunc("/healthz", handleHealthz)
	httpMux.HandleFunc("/readyz", handleReadyz)
	// create: POST /api/v1/games
	httpMux.HandleFunc("/api/v1/games", handleCreateGame)
	// subpaths: GET /api/v1/games/{gameId} and POST /api/v1/games/{gameId}/join
	httpMux.HandleFunc("/api/v1/games/", handleGameSub)

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

func handleHome(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Sequence Game Lobby</title>
  <style>
    :root { color-scheme: dark; }
    body { font-family: Arial, sans-serif; margin: 0; background: #0f172a; color: #f8fafc; display: grid; place-items: center; min-height: 100vh; }
    .card { width: min(92vw, 720px); background: rgba(15, 23, 42, 0.9); border: 1px solid #334155; border-radius: 18px; padding: 28px; box-shadow: 0 20px 50px rgba(0, 0, 0, 0.35); }
    h1 { margin-top: 0; font-size: 2rem; }
    .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin: 20px 0; }
    .cell { background: #1e293b; border: 1px solid #475569; border-radius: 10px; min-height: 90px; display: flex; align-items: center; justify-content: center; font-size: 1.8rem; font-weight: 700; }
    .actions { display: flex; gap: 12px; flex-wrap: wrap; }
    button { background: #38bdf8; color: white; border: none; border-radius: 999px; padding: 10px 16px; font-size: 1rem; cursor: pointer; }
    button.secondary { background: #475569; }
    .status { margin-top: 14px; color: #cbd5e1; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Sequence Game Lobby</h1>
    <p>Welcome to your local Sequence game experience. This page is served by the game service and confirms the UI is live.</p>
    <div class="grid">
      <div class="cell">S</div>
      <div class="cell">E</div>
      <div class="cell">Q</div>
      <div class="cell">U</div>
      <div class="cell">E</div>
      <div class="cell">N</div>
      <div class="cell">C</div>
      <div class="cell">E</div>
      <div class="cell">✓</div>
    </div>
    <div class="actions">
      <button onclick="checkHealth()">Check Health</button>
      <button class="secondary" onclick="window.location.reload()">Refresh</button>
    </div>
    <div id="status" class="status">Waiting for health check…</div>
  </div>
  <script>
    async function checkHealth() {
      const status = document.getElementById('status');
      try {
        const res = await fetch('/healthz');
        const data = await res.json();
        status.textContent = 'Health check: ' + JSON.stringify(data);
      } catch (err) {
        status.textContent = 'Health check failed: ' + err.message;
      }
    }
    checkHealth();
  </script>
</body>
</html>`))
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

// handleGameSub routes requests under /api/v1/games/{...}
func handleGameSub(w http.ResponseWriter, r *http.Request) {
	// trim prefix
	p := strings.TrimPrefix(r.URL.Path, "/api/v1/games/")
	if p == "" {
		http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
		return
	}
	// join action ends with /join
	if strings.HasSuffix(p, "/join") {
		handleJoinGame(w, r)
		return
	}
	// otherwise assume GET /api/v1/games/{gameId}
	if r.Method == http.MethodGet {
		handleGetGame(w, r)
		return
	}
	http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
