package main

import (
	"encoding/json"
	"net/http"
	"os"
	"time"
)

type ServiceStatus struct {
	Name   string `json:"name"`
	URL    string `json:"url"`
	Status string `json:"status"`
	Label  string `json:"label"`
}

func checkService(url string) string {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil || resp.StatusCode >= 500 {
		return "down"
	}
	return "up"
}

func statusHandler(w http.ResponseWriter, r *http.Request) {
	services := []ServiceStatus{
		{Name: "app-demo", URL: "https://app.maxto-platform.cloud", Label: "App Demo"},
		{Name: "argocd", URL: "https://argocd.maxto-platform.cloud", Label: "ArgoCD"},
		{Name: "grafana", URL: "https://grafana.maxto-platform.cloud/api/health", Label: "Grafana"},
		{Name: "vault", URL: "https://vault.maxto-platform.cloud/v1/sys/health", Label: "Vault"},
		{Name: "defectdojo", URL: "https://defectdojo.maxto-platform.cloud", Label: "DefectDojo"},
	}

	ch := make(chan ServiceStatus, len(services))
	for _, s := range services {
		go func(svc ServiceStatus) {
			svc.Status = checkService(svc.URL)
			ch <- svc
		}(s)
	}

	results := make([]ServiceStatus, 0, len(services))
	for range services {
		results = append(results, <-ch)
	}

	// Sort by original order
	ordered := make([]ServiceStatus, len(services))
	for _, r := range results {
		for i, s := range services {
			if s.Name == r.Name {
				ordered[i] = r
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(ordered)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/api/status", statusHandler)
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
	})
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write([]byte(indexHTML))
	})

	http.ListenAndServe(":"+port, nil)
}

const indexHTML = `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Maxime Toris — Platform Engineer</title>
  <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
  <style>
    :root {
      --bg: #0d1117;
      --bg2: #161b22;
      --bg3: #21262d;
      --border: #30363d;
      --text: #e6edf3;
      --muted: #8b949e;
      --accent: #3b82f6;
      --green: #22c55e;
      --red: #ef4444;
      --yellow: #f59e0b;
      --orange: #f97316;
      --purple: #a855f7;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: var(--bg); color: var(--text); font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; line-height: 1.6; }

    /* HERO */
    .hero { padding: 80px 24px 60px; text-align: center; border-bottom: 1px solid var(--border); background: linear-gradient(180deg, #0d1117 0%, #161b22 100%); }
    .hero-badge { display: inline-block; background: var(--bg3); border: 1px solid var(--border); color: var(--muted); font-size: 12px; padding: 4px 12px; border-radius: 20px; margin-bottom: 20px; letter-spacing: 1px; text-transform: uppercase; }
    .hero h1 { font-size: clamp(28px, 5vw, 52px); font-weight: 700; letter-spacing: -1px; margin-bottom: 12px; }
    .hero h1 span { color: var(--accent); }
    .hero p { color: var(--muted); font-size: 18px; max-width: 600px; margin: 0 auto 32px; }
    .hero-links { display: flex; gap: 12px; justify-content: center; flex-wrap: wrap; }
    .btn { display: inline-flex; align-items: center; gap: 8px; padding: 10px 20px; border-radius: 8px; font-size: 14px; font-weight: 500; text-decoration: none; transition: all 0.2s; }
    .btn-primary { background: var(--accent); color: #fff; }
    .btn-primary:hover { background: #2563eb; }
    .btn-ghost { background: var(--bg3); color: var(--text); border: 1px solid var(--border); }
    .btn-ghost:hover { border-color: var(--accent); color: var(--accent); }

    /* LAYOUT */
    .container { max-width: 1100px; margin: 0 auto; padding: 0 24px; }
    section { padding: 60px 0; border-bottom: 1px solid var(--border); }
    section:last-child { border-bottom: none; }
    .section-title { font-size: 13px; font-weight: 600; text-transform: uppercase; letter-spacing: 2px; color: var(--accent); margin-bottom: 8px; }
    .section-heading { font-size: clamp(22px, 3vw, 32px); font-weight: 700; margin-bottom: 40px; }

    /* STATUS */
    .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
    .status-card { background: var(--bg2); border: 1px solid var(--border); border-radius: 12px; padding: 20px; display: flex; align-items: center; gap: 14px; transition: border-color 0.2s; }
    .status-card:hover { border-color: var(--accent); }
    .status-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
    .status-dot.up { background: var(--green); box-shadow: 0 0 8px var(--green); }
    .status-dot.down { background: var(--red); box-shadow: 0 0 8px var(--red); }
    .status-dot.loading { background: var(--yellow); animation: pulse 1s infinite; }
    @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
    .status-info { min-width: 0; }
    .status-name { font-weight: 600; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .status-label { font-size: 12px; color: var(--muted); }
    .status-updated { text-align: right; font-size: 12px; color: var(--muted); margin-top: 16px; }

    /* PIPELINE */
    .pipeline { display: flex; flex-direction: column; gap: 0; }
    .pipeline-step { display: flex; gap: 20px; align-items: flex-start; position: relative; }
    .pipeline-step:not(:last-child)::after { content: ''; position: absolute; left: 19px; top: 40px; bottom: -20px; width: 2px; background: var(--border); }
    .pipeline-icon { width: 40px; height: 40px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 18px; flex-shrink: 0; border: 2px solid var(--border); background: var(--bg2); z-index: 1; }
    .pipeline-content { padding: 0 0 32px; flex: 1; }
    .pipeline-title { font-weight: 600; font-size: 15px; margin-bottom: 4px; }
    .pipeline-desc { color: var(--muted); font-size: 14px; }
    .pipeline-tag { display: inline-block; background: var(--bg3); border: 1px solid var(--border); color: var(--muted); font-size: 11px; padding: 2px 8px; border-radius: 4px; margin-top: 6px; font-family: monospace; }

    /* STACK TABLE */
    .stack-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 12px; }
    .stack-card { background: var(--bg2); border: 1px solid var(--border); border-radius: 12px; padding: 20px; }
    .stack-card-header { display: flex; align-items: center; gap: 10px; margin-bottom: 8px; }
    .stack-dot { width: 8px; height: 8px; border-radius: 50%; }
    .stack-card-name { font-weight: 600; font-size: 15px; }
    .stack-card-desc { color: var(--muted); font-size: 13px; }
    .stack-card-url { display: inline-block; margin-top: 8px; font-size: 12px; color: var(--accent); text-decoration: none; font-family: monospace; }
    .stack-card-url:hover { text-decoration: underline; }

    /* ARCHITECTURE */
    .mermaid-wrap { background: var(--bg2); border: 1px solid var(--border); border-radius: 12px; padding: 32px; overflow-x: auto; }
    .mermaid { max-width: 100%; }

    /* DEMO ACCESS */
    .demo-table { width: 100%; border-collapse: collapse; }
    .demo-table th { text-align: left; padding: 10px 16px; font-size: 12px; text-transform: uppercase; letter-spacing: 1px; color: var(--muted); border-bottom: 1px solid var(--border); }
    .demo-table td { padding: 14px 16px; border-bottom: 1px solid var(--border); font-size: 14px; vertical-align: middle; }
    .demo-table tr:last-child td { border-bottom: none; }
    .demo-table tr:hover td { background: var(--bg3); }
    .demo-badge { display: inline-block; padding: 2px 10px; border-radius: 20px; font-size: 11px; font-weight: 600; }
    .demo-badge.readonly { background: rgba(34,197,94,0.12); color: var(--green); border: 1px solid rgba(34,197,94,0.3); }
    .demo-badge.token { background: rgba(168,85,247,0.12); color: var(--purple); border: 1px solid rgba(168,85,247,0.3); }
    .demo-code { font-family: monospace; background: var(--bg3); padding: 3px 8px; border-radius: 4px; font-size: 13px; cursor: pointer; border: 1px solid var(--border); transition: border-color 0.2s; display: inline-flex; align-items: center; gap: 6px; }
    .demo-code:hover { border-color: var(--accent); }
    .demo-link { color: var(--accent); text-decoration: none; font-family: monospace; font-size: 13px; }
    .demo-link:hover { text-decoration: underline; }
    .demo-token { font-family: monospace; font-size: 11px; color: var(--muted); word-break: break-all; }
    .copy-hint { font-size: 11px; color: var(--muted); margin-top: 16px; }
    .scroll-hint { display: none; font-size: 12px; color: var(--muted); margin-top: 8px; text-align: center; }

    /* SECURITY */
    .security-list { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 12px; }
    .security-item { background: var(--bg2); border: 1px solid var(--border); border-radius: 12px; padding: 20px; display: flex; gap: 12px; }
    .security-item-icon { font-size: 22px; flex-shrink: 0; }
    .security-item-title { font-weight: 600; font-size: 14px; margin-bottom: 4px; }
    .security-item-desc { color: var(--muted); font-size: 13px; }

    /* FOOTER */
    footer { padding: 40px 24px; text-align: center; color: var(--muted); font-size: 14px; }
    footer a { color: var(--accent); text-decoration: none; }
    footer a:hover { text-decoration: underline; }
    .footer-links { display: flex; gap: 20px; justify-content: center; margin-top: 12px; flex-wrap: wrap; }

    /* MOBILE */
    @media (max-width: 768px) {
      .stack-grid { grid-template-columns: 1fr; }
      .security-list { grid-template-columns: 1fr; }
      .status-grid { grid-template-columns: repeat(2, 1fr); }
      .scroll-hint { display: block; }
    }
    @media (max-width: 640px) {
      .hero { padding: 48px 16px 40px; }
      section { padding: 40px 0; }
      .container { padding: 0 16px; }
      .hero p { font-size: 15px; }
      .section-heading { margin-bottom: 24px; }

      /* Demo table → cards */
      .demo-table thead { display: none; }
      .demo-table, .demo-table tbody, .demo-table tr { display: block; }
      .demo-table tbody tr { background: var(--bg2); border: 1px solid var(--border); border-radius: 12px; padding: 14px 16px; margin-bottom: 12px; }
      .demo-table td { display: flex; align-items: flex-start; gap: 8px; border: none; padding: 5px 0; font-size: 13px; }
      .demo-table td::before { content: attr(data-label); color: var(--muted); font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; min-width: 68px; padding-top: 3px; flex-shrink: 0; }
      .demo-table tr:hover td { background: transparent; }
      .demo-table td[colspan="2"] { flex-wrap: wrap; }

      /* Pipeline */
      .pipeline-step { gap: 12px; }
      .pipeline-step:not(:last-child)::after { left: 15px; }
      .pipeline-icon { width: 32px; height: 32px; font-size: 15px; }

      /* Status */
      .status-grid { grid-template-columns: repeat(2, 1fr); }
      .status-card { padding: 14px; gap: 10px; }
    }
  </style>
</head>
<body>

<!-- HERO -->
<div class="hero">
  <div class="hero-badge">Platform Engineer · SRE</div>
  <h1>Maxime Toris — <span>GitOps Lab</span></h1>
  <p>Pipeline de livraison complet du commit au déploiement, avec sécurité et observabilité intégrées — sur une infrastructure à 9€/mois.</p>
  <div class="hero-links">
    <a href="https://app.maxto-platform.cloud" class="btn btn-primary" target="_blank">🚀 App live</a>
    <a href="https://grafana.maxto-platform.cloud/dashboards?starred" class="btn btn-ghost" target="_blank">📊 Grafana</a>
    <a href="https://argocd.maxto-platform.cloud" class="btn btn-ghost" target="_blank">🔄 ArgoCD</a>
    <a href="https://gitlab.com/Mtoris" class="btn btn-ghost" target="_blank">📁 GitLab</a>
  </div>
</div>

<!-- STATUS -->
<section>
  <div class="container">
    <div class="section-title">Observabilité</div>
    <div class="section-heading">Status en temps réel</div>
    <div class="status-grid" id="status-grid">
      <div class="status-card"><div class="status-dot loading"></div><div class="status-info"><div class="status-name">App Demo</div><div class="status-label">Vérification...</div></div></div>
      <div class="status-card"><div class="status-dot loading"></div><div class="status-info"><div class="status-name">ArgoCD</div><div class="status-label">Vérification...</div></div></div>
      <div class="status-card"><div class="status-dot loading"></div><div class="status-info"><div class="status-name">Grafana</div><div class="status-label">Vérification...</div></div></div>
      <div class="status-card"><div class="status-dot loading"></div><div class="status-info"><div class="status-name">Vault</div><div class="status-label">Vérification...</div></div></div>
      <div class="status-card"><div class="status-dot loading"></div><div class="status-info"><div class="status-name">DefectDojo</div><div class="status-label">Vérification...</div></div></div>
    </div>
    <div class="status-updated" id="status-updated"></div>
  </div>
</section>

<!-- DEMO ACCESS -->
<section>
  <div class="container">
    <div class="section-title">Accès démo</div>
    <div class="section-heading">Explorer le lab</div>
    <div class="mermaid-wrap" style="padding:0;overflow:hidden">
      <table class="demo-table">
        <thead>
          <tr>
            <th>Service</th>
            <th>URL</th>
            <th>Login</th>
            <th>Mot de passe</th>
            <th>Rôle</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td data-label="Service"><strong>ArgoCD</strong></td>
            <td data-label="URL"><a href="https://argocd.maxto-platform.cloud" target="_blank" class="demo-link">argocd.maxto-platform.cloud ↗</a></td>
            <td data-label="Login"><span class="demo-code" onclick="copyText('guest', this)">guest <span style="opacity:0.4">⎘</span></span></td>
            <td data-label="Mot de passe"><span class="demo-code" onclick="copyText('guest123', this)">guest123 <span style="opacity:0.4">⎘</span></span></td>
            <td data-label="Rôle"><span class="demo-badge readonly">read-only</span></td>
          </tr>
          <tr>
            <td data-label="Service"><strong>Grafana</strong></td>
            <td data-label="URL"><a href="https://grafana.maxto-platform.cloud/dashboards?starred" target="_blank" class="demo-link">grafana.maxto-platform.cloud ↗</a></td>
            <td data-label="Login"><span class="demo-code" onclick="copyText('guest', this)">guest <span style="opacity:0.4">⎘</span></span></td>
            <td data-label="Mot de passe"><span class="demo-code" onclick="copyText('guest123', this)">guest123 <span style="opacity:0.4">⎘</span></span></td>
            <td data-label="Rôle"><span class="demo-badge readonly">viewer</span></td>
          </tr>
          <tr>
            <td data-label="Service"><strong>Vault</strong></td>
            <td data-label="URL"><a href="https://vault.maxto-platform.cloud" target="_blank" class="demo-link">vault.maxto-platform.cloud ↗</a></td>
            <td data-label="Token" colspan="2">
              <span class="demo-code" onclick="copyText('hvs.CAESIByooeI-v1OxvZKcm3XLo_ZHrupVYs5vm0KG7CVztrUTGh4KHGh2cy45YkZwMGVMUkUxUlVGajdLZ1RWR0tmeU0', this)" style="max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;display:inline-flex">
                <span class="demo-token">hvs.CAESIByooeI-v1Ox…</span> <span style="opacity:0.4;flex-shrink:0">⎘ copier</span>
              </span>
              <div style="font-size:11px;color:var(--muted);margin-top:4px">Method: Token · accès limité à <code style="background:var(--bg3);padding:1px 4px;border-radius:3px">secret/demo/*</code></div>
            </td>
            <td data-label="Rôle"><span class="demo-badge token">token demo</span></td>
          </tr>
          <tr>
            <td data-label="Service"><strong>DefectDojo</strong></td>
            <td data-label="URL"><a href="https://defectdojo.maxto-platform.cloud" target="_blank" class="demo-link">defectdojo.maxto-platform.cloud ↗</a></td>
            <td data-label="Login"><span class="demo-code" onclick="copyText('guest', this)">guest <span style="opacity:0.4">⎘</span></span></td>
            <td data-label="Mot de passe"><span class="demo-code" onclick="copyText('Guest@Lab2026!', this)">Guest@Lab2026! <span style="opacity:0.4">⎘</span></span></td>
            <td data-label="Rôle"><span class="demo-badge readonly">reader</span></td>
          </tr>
        </tbody>
      </table>
    </div>
    <div class="copy-hint">Cliquez sur un credential pour le copier dans le presse-papier.</div>
  </div>
</section>

<!-- ARCHITECTURE -->
<section>
  <div class="container">
    <div class="section-title">Infrastructure</div>
    <div class="section-heading">Architecture</div>
    <div class="mermaid-wrap" style="overflow-x:auto">
      <div class="mermaid" style="min-width:560px">
graph LR
    DEV[👨‍💻 Developer] -->|git push| GL[GitLab CI]

    subgraph CI ["Pipeline CI"]
        GL --> T[Tests\ngolang:1.22]
        T --> B[Build image\nregistry.gitlab.com]
        B --> SC[Scan CVE\nTrivy]
        SC --> DD[DefectDojo\nCVE report]
        SC --> UM[Bump tag\ninfra-k8s]
    end

    subgraph VPS ["VPS Ionos — k3s"]
        ARGO[🔄 ArgoCD] -->|sync auto| APP[🚀 app-demo]
        ARGO -->|sync auto| PORT[🌐 Portfolio]
        APP -->|/metrics| PROM[Prometheus]
        PROM --> GRAF[📊 Grafana]
        VAULT[🔐 Vault] -->|ExternalSecrets| APP
        VAULT -->|ExternalSecrets| ARGO
    end

    UM -->|git commit| ARGO
    DD -->|import scan| DOJO[🛡 DefectDojo]

    style CI fill:#1c1400,stroke:#d97706
    style VPS fill:#0c1929,stroke:#3b82f6
      </div>
    </div>
    <div class="scroll-hint">← Faire défiler pour voir le schéma complet →</div>
  </div>
</section>

<!-- PIPELINE -->
<section>
  <div class="container">
    <div class="section-title">CI/CD</div>
    <div class="section-heading">Parcours d'un commit</div>
    <div class="pipeline">
      <div class="pipeline-step">
        <div class="pipeline-icon">👨‍💻</div>
        <div class="pipeline-content">
          <div class="pipeline-title">git push</div>
          <div class="pipeline-desc">Le développeur pousse son code. GitLab CI déclenche automatiquement le pipeline.</div>
        </div>
      </div>
      <div class="pipeline-step">
        <div class="pipeline-icon">✅</div>
        <div class="pipeline-content">
          <div class="pipeline-title">Tests unitaires</div>
          <div class="pipeline-desc">Exécution de la suite de tests dans un container Go isolé.</div>
          <span class="pipeline-tag">golang:1.22-alpine · go test ./...</span>
        </div>
      </div>
      <div class="pipeline-step">
        <div class="pipeline-icon">🐳</div>
        <div class="pipeline-content">
          <div class="pipeline-title">Build &amp; Push image</div>
          <div class="pipeline-desc">Construction de l'image Docker et push sur la registry privée GitLab.</div>
          <span class="pipeline-tag">registry.gitlab.com/mtoris/app-demo:&lt;sha&gt;</span>
        </div>
      </div>
      <div class="pipeline-step">
        <div class="pipeline-icon">🔍</div>
        <div class="pipeline-content">
          <div class="pipeline-title">Scan CVE (Trivy)</div>
          <div class="pipeline-desc">Analyse de l'image pour détecter les vulnérabilités. Les CVE CRITICAL bloquent le pipeline.</div>
          <span class="pipeline-tag">aquasec/trivy:0.61.0 · rapport JSON</span>
        </div>
      </div>
      <div class="pipeline-step">
        <div class="pipeline-icon">🛡</div>
        <div class="pipeline-content">
          <div class="pipeline-title">Import DefectDojo</div>
          <div class="pipeline-desc">Le rapport Trivy est automatiquement importé dans DefectDojo pour traçabilité et historique des vulnérabilités.</div>
          <span class="pipeline-tag">112 findings · dont CVE-2025-68121 CRITICAL</span>
        </div>
      </div>
      <div class="pipeline-step">
        <div class="pipeline-icon">📝</div>
        <div class="pipeline-content">
          <div class="pipeline-title">Bump image tag</div>
          <div class="pipeline-desc">Le pipeline met à jour le tag de l'image dans le repo infra-k8s (GitOps).</div>
          <span class="pipeline-tag">git commit · infra-k8s/app-demo/deployment.yaml</span>
        </div>
      </div>
      <div class="pipeline-step">
        <div class="pipeline-icon">🔄</div>
        <div class="pipeline-content">
          <div class="pipeline-title">ArgoCD détecte le changement</div>
          <div class="pipeline-desc">ArgoCD synchronise automatiquement le cluster avec le nouvel état décrit dans le repo.</div>
          <span class="pipeline-tag">sync automatique · &lt;3 min</span>
        </div>
      </div>
      <div class="pipeline-step">
        <div class="pipeline-icon">🚀</div>
        <div class="pipeline-content">
          <div class="pipeline-title">App déployée en production</div>
          <div class="pipeline-desc">Le nouveau pod est live. Prometheus scrape les métriques, Grafana affiche les dashboards.</div>
          <span class="pipeline-tag">https://app.maxto-platform.cloud</span>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- STACK -->
<section>
  <div class="container">
    <div class="section-title">Stack technique</div>
    <div class="section-heading">Outils &amp; Services</div>
    <div class="stack-grid">
      <div class="stack-card">
        <div class="stack-card-header"><div class="stack-dot" style="background:#3b82f6"></div><div class="stack-card-name">k3s — Kubernetes</div></div>
        <div class="stack-card-desc">Orchestrateur léger sur VPS Ionos 4vCPU / 8Go RAM. Production-grade, 9€/mois.</div>
      </div>
      <div class="stack-card">
        <div class="stack-card-header"><div class="stack-dot" style="background:#f97316"></div><div class="stack-card-name">ArgoCD</div></div>
        <div class="stack-card-desc">GitOps — Git est la source de vérité unique. Aucun kubectl apply manuel.</div>
        <a href="https://argocd.maxto-platform.cloud" target="_blank" class="stack-card-url">argocd.maxto-platform.cloud ↗</a>
      </div>
      <div class="stack-card">
        <div class="stack-card-header"><div class="stack-dot" style="background:#d97706"></div><div class="stack-card-name">GitLab CI</div></div>
        <div class="stack-card-desc">Pipeline complet test → build → scan → deploy sur runner shell hébergé sur le VPS.</div>
        <a href="https://gitlab.com/Mtoris" target="_blank" class="stack-card-url">gitlab.com/Mtoris ↗</a>
      </div>
      <div class="stack-card">
        <div class="stack-card-header"><div class="stack-dot" style="background:#8b5cf6"></div><div class="stack-card-name">Prometheus + Grafana</div></div>
        <div class="stack-card-desc">Métriques infra et applicatives. ServiceMonitor, dashboards custom, alerting.</div>
        <a href="https://grafana.maxto-platform.cloud/dashboards?starred" target="_blank" class="stack-card-url">grafana.maxto-platform.cloud ↗</a>
      </div>
      <div class="stack-card">
        <div class="stack-card-header"><div class="stack-dot" style="background:#ef4444"></div><div class="stack-card-name">DefectDojo</div></div>
        <div class="stack-card-desc">Gestion centralisée des vulnérabilités CVE importées depuis Trivy à chaque pipeline.</div>
        <a href="https://defectdojo.maxto-platform.cloud" target="_blank" class="stack-card-url">defectdojo.maxto-platform.cloud ↗</a>
      </div>
      <div class="stack-card">
        <div class="stack-card-header"><div class="stack-dot" style="background:#22c55e"></div><div class="stack-card-name">HashiCorp Vault + ESO</div></div>
        <div class="stack-card-desc">Gestion des secrets — ExternalSecrets synchronisés depuis Vault vers Kubernetes. Zéro secret en clair dans le code.</div>
        <a href="https://vault.maxto-platform.cloud" target="_blank" class="stack-card-url">vault.maxto-platform.cloud ↗</a>
      </div>
      <div class="stack-card">
        <div class="stack-card-header"><div class="stack-dot" style="background:#64748b"></div><div class="stack-card-name">cert-manager + Let's Encrypt</div></div>
        <div class="stack-card-desc">TLS automatique sur tous les services via nginx-ingress. Renouvellement automatique.</div>
      </div>
      <div class="stack-card">
        <div class="stack-card-header"><div class="stack-dot" style="background:#06b6d4"></div><div class="stack-card-name">Trivy (Aqua Security)</div></div>
        <div class="stack-card-desc">Scan CVE de chaque image Docker avant déploiement. Les CRITICAL bloquent le pipeline.</div>
      </div>
    </div>
  </div>
</section>

<!-- SECURITY -->
<section>
  <div class="container">
    <div class="section-title">Sécurité</div>
    <div class="section-heading">Security by design</div>
    <div class="security-list">
      <div class="security-item">
        <div class="security-item-icon">🔐</div>
        <div><div class="security-item-title">Secrets gérés par Vault</div><div class="security-item-desc">Aucun secret en clair dans le code ou les manifests. Synchronisation via External Secrets Operator.</div></div>
      </div>
      <div class="security-item">
        <div class="security-item-icon">🔍</div>
        <div><div class="security-item-title">Scan CVE systématique</div><div class="security-item-desc">Chaque image scannée par Trivy avant déploiement. Les CRITICAL bloquent automatiquement le pipeline.</div></div>
      </div>
      <div class="security-item">
        <div class="security-item-icon">📋</div>
        <div><div class="security-item-title">Traçabilité totale</div><div class="security-item-desc">Chaque CVE est importée dans DefectDojo avec historique complet. Audit trail par commit.</div></div>
      </div>
      <div class="security-item">
        <div class="security-item-icon">🚫</div>
        <div><div class="security-item-title">Zero accès direct cluster</div><div class="security-item-desc">Tout passe par ArgoCD. Aucun kubectl apply manuel en production.</div></div>
      </div>
      <div class="security-item">
        <div class="security-item-icon">🔒</div>
        <div><div class="security-item-title">TLS partout</div><div class="security-item-desc">Tous les services exposés en HTTPS via cert-manager + Let's Encrypt. Renouvellement automatique.</div></div>
      </div>
      <div class="security-item">
        <div class="security-item-icon">↩️</div>
        <div><div class="security-item-title">Rollback instantané</div><div class="security-item-desc">Un incident = un git revert. ArgoCD reconcilie en moins de 3 minutes.</div></div>
      </div>
    </div>
  </div>
</section>

<!-- FOOTER -->
<footer>
  <div><strong>Maxime Toris</strong> — Platform Engineer / SRE</div>
  <div class="footer-links">
    <a href="mailto:toris.maxime@gmail.com">toris.maxime@gmail.com</a>
    <a href="https://gitlab.com/Mtoris" target="_blank">GitLab</a>
    <a href="https://www.linkedin.com/in/maxime-toris-05a947a2/" target="_blank">LinkedIn</a>
  </div>
</footer>

<script>
  mermaid.initialize({ startOnLoad: true, theme: 'dark', flowchart: { useMaxWidth: false }, themeVariables: { primaryColor: '#1e3a5f', primaryTextColor: '#e6edf3', primaryBorderColor: '#3b82f6', lineColor: '#8b949e', secondaryColor: '#1c1400', tertiaryColor: '#161b22' }});

  const serviceLinks = {
    'App Demo': 'https://app.maxto-platform.cloud',
    'ArgoCD': 'https://argocd.maxto-platform.cloud',
    'Grafana': 'https://grafana.maxto-platform.cloud/dashboards?starred',
    'Vault': 'https://vault.maxto-platform.cloud',
    'DefectDojo': 'https://defectdojo.maxto-platform.cloud',
  };

  async function refreshStatus() {
    try {
      const res = await fetch('/api/status');
      const data = await res.json();
      const grid = document.getElementById('status-grid');
      grid.innerHTML = data.map(s => {
        const link = serviceLinks[s.label] || '#';
        return ` + "`" + `
          <a href="${link}" target="_blank" style="text-decoration:none;color:inherit">
            <div class="status-card">
              <div class="status-dot ${s.status}"></div>
              <div class="status-info">
                <div class="status-name">${s.label}</div>
                <div class="status-label">${s.status === 'up' ? 'Opérationnel' : 'Indisponible'}</div>
              </div>
            </div>
          </a>` + "`" + `;
      }).join('');
      document.getElementById('status-updated').textContent = 'Mis à jour : ' + new Date().toLocaleTimeString('fr-FR');
    } catch(e) {
      console.error('Status fetch failed', e);
    }
  }

  refreshStatus();
  setInterval(refreshStatus, 30000);

  function copyText(text, el) {
    navigator.clipboard.writeText(text).then(() => {
      const original = el.innerHTML;
      el.innerHTML = '✓ Copié !';
      el.style.borderColor = 'var(--green)';
      el.style.color = 'var(--green)';
      setTimeout(() => {
        el.innerHTML = original;
        el.style.borderColor = '';
        el.style.color = '';
      }, 1500);
    });
  }
</script>
</body>
</html>`
