package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	version   = "dev"
	buildTime = "unknown"

	httpRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "app_demo_http_requests_total",
		Help: "Nombre total de requêtes HTTP par endpoint et status",
	}, []string{"endpoint", "status"})

	httpDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "app_demo_http_duration_seconds",
		Help:    "Durée des requêtes HTTP",
		Buckets: prometheus.DefBuckets,
	}, []string{"endpoint"})

	appInfo = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Name: "app_demo_info",
		Help: "Informations sur l'application",
	}, []string{"version", "build_time"})
)

type HealthResponse struct {
	Status    string    `json:"status"`
	Version   string    `json:"version"`
	BuildTime string    `json:"build_time"`
	Timestamp time.Time `json:"timestamp"`
}

type InfoResponse struct {
	App         string `json:"app"`
	Description string `json:"description"`
	Version     string `json:"version"`
	Stack       string `json:"stack"`
}

func instrument(endpoint string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &statusRecorder{ResponseWriter: w, status: 200}
		next(rw, r)
		duration := time.Since(start).Seconds()
		status := http.StatusText(rw.status)
		httpRequestsTotal.WithLabelValues(endpoint, status).Inc()
		httpDuration.WithLabelValues(endpoint).Observe(duration)
	}
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(HealthResponse{
		Status:    "ok",
		Version:   version,
		BuildTime: buildTime,
		Timestamp: time.Now().UTC(),
	})
}

func infoHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(InfoResponse{
		App:         "app-demo",
		Description: "Microservice de démonstration - Stack GitOps",
		Version:     version,
		Stack:       "k3s + GitLab CI + ArgoCD + Trivy",
	})
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	appInfo.WithLabelValues(version, buildTime).Set(1)

	mux := http.NewServeMux()
	mux.HandleFunc("/health", instrument("/health", healthHandler))
	mux.HandleFunc("/", instrument("/", infoHandler))
	mux.Handle("/metrics", promhttp.Handler())

	log.Printf("app-demo v%s démarré sur le port %s", version, port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("Erreur serveur: %v", err)
	}
}
