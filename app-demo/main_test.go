package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()

	healthHandler(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status attendu 200, obtenu %d", w.Code)
	}

	var resp HealthResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("impossible de décoder la réponse: %v", err)
	}

	if resp.Status != "ok" {
		t.Errorf("status attendu 'ok', obtenu '%s'", resp.Status)
	}
}

func TestInfoHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()

	infoHandler(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status attendu 200, obtenu %d", w.Code)
	}

	var resp InfoResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("impossible de décoder la réponse: %v", err)
	}

	if resp.App != "app-demo" {
		t.Errorf("app attendu 'app-demo', obtenu '%s'", resp.App)
	}
}
