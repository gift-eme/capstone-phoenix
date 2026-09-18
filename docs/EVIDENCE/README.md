# EVIDENCE

Drop screenshots/logs here, so someone knows what each proves:

- `nodes-ready.png` — multi-node `kubectl get nodes`
- `pods-spread.png` — replicas on different nodes (`-o wide`)
- `tls-valid.png` — valid cert (curl -vI / SSL Labs)
- `pvc-persist.log` — data survives a Pod kill
- `zero-downtime.log` — unbroken 200s during a rollout
- `hpa-scale.png` — replicas climbing under load
- `argocd-synced.png` — Argo CD Synced + Healthy
- `gitops-sync-demo.png` — commit (frontend replicas 2→3) → push → Argo CD auto-syncs → 3rd pod appears, no manual kubectl apply
- `failover.png` — app up after a node drain
- `core-checklist.log` — ConfigMap/Secret/Services exist, pinned image tags, probes+resources on every container
- `advanced-checklist.log` — NetworkPolicy blocks/allows as designed, PDBs present, securityContext applied live (HPA is the 4th Advanced item — already covered separately by `hpa-scale.png`)
