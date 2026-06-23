package main

import (
	`log/slog`
	`net/http`
	`os`
	`os/signal`
	`syscall`
	`time`
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	port := getEnv(`PORT`, `8080`)
	mux := http.NewServeMux()
	mux.HandleFunc(`/healthz`, func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"status":"ok"}`))
	})
	mux.HandleFunc(`/readyz`, func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"status":"ready"}`))
	})

	srv := &http.Server{
		Addr:         `:` + port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
	}

	go func() {
		slog.Info(`leaderboard-service starting`, `port`, port)
		if err := srv.ListenAndServe(); err != http.ErrServerClosed {
			slog.Error(`server error`, `error`, err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)
	<-quit
	slog.Info(`shutting down`)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
