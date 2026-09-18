# EVIDENCE

Drop screenshots/logs here, so someone knows what each proves:

Quick note on node count: most of what's here was captured back when the cluster was 1
control-plane + 2 workers. Getting the node-drain demo to actually hold up meant adding a 3rd
worker because with only 2, the topology spread constraints on backend/frontend can't survive losing
one (see the trade-offs section in `ARCHITECTURE.md`). Nothing in the app or platform manifests
changed for that, only the worker count in Terraform - so everything else captured here still
holds exactly as-is on the current 4-node cluster.

- `nodes-ready.png` — multi-node `kubectl get nodes`
- `pods-spread.png` — replicas on different nodes (`-o wide`)
- `tls-valid.png` — valid cert (curl -vI / SSL Labs)
- `app-working.png` — the app loading in a browser at `taskapp-gift-capstone.duckdns.org`
- `pvc-persist.log` — data survives a Pod kill
- `zero-downtime.log` — unbroken 200s during a rollout
- `hpa-scale.png` — replicas climbing under load
- `argocd-synced.png` — Argo CD Synced + Healthy
- `gitops-sync-demo.png` — commit (frontend replicas 2→3) → push → Argo CD auto-syncs → 3rd pod appears, no manual kubectl apply
- node-drain failover — demoed live on video for the viva, not a file in this folder
- `core-checklist.log` — ConfigMap/Secret/Services exist, pinned image tags, probes+resources on every container
- `advanced-checklist.log` — NetworkPolicy blocks/allows as designed, PDBs present, securityContext applied live (HPA is the 4th Advanced item — already covered separately by `hpa-scale.png`)
