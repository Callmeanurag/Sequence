# Multi-stage build: builder → distroless runtime
# Why distroless: no shell, no package manager, minimal attack surface
# Image size: ~10MB vs ~800MB for a full Go image

# Stage 1: Builder
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Download dependencies first (cached layer — only invalidated when go.mod changes)
COPY go.mod ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o auth-service .

# Stage 2: Runtime (distroless — no shell, no package manager)
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

# Copy only the binary
COPY --from=builder /app/auth-service .

# nonroot user is UID 65532 in distroless
USER 65532:65532

EXPOSE 8080 9090

ENTRYPOINT ["/app/auth-service"]
