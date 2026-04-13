# =============================================================================
# Multi-stage build — image finale ~10Mo (scratch)
# =============================================================================

# --- Stage 1 : Build ---
FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY . .

ARG VERSION=dev
ARG BUILD_TIME=unknown

RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s -X main.version=${VERSION} -X main.buildTime=${BUILD_TIME}" \
    -o app-demo .

# --- Stage 2 : Image finale (distroless pour la sécurité) ---
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /app/app-demo /app-demo

EXPOSE 8080

USER nonroot:nonroot

ENTRYPOINT ["/app-demo"]
