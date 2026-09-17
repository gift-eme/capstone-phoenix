# gitops/ — Argo CD owns the cluster

This is your **GitOps, leveled up to Kubernetes**. The cluster's desired state
lives in *this git repo*; Argo CD continuously syncs it. Your final, graded state must be
reconciled by Argo — not by you running `kubectl apply` by hand.

**Produce:**
- Install Argo CD (manifest) — document how in RUNBOOK.md.
- An Argo CD `Application` (this folder) pointing at `manifests/`,
  with `syncPolicy.automated` (prune + selfHeal). App-of-apps if you split platform vs app.

**Acceptance / demo (required for the GitOps points):**
1. `argocd app get taskapp` → `Synced` + `Healthy`.
2. Commit a change (e.g. bump frontend replicas 2→3), push.
3. Show Argo auto-syncing and the new Pod appearing — **no manual apply.**

**bonus:** a CI job that builds a new image, pushes to GHCR, and bumps the pinned tag in
this repo → Argo deploys it.

> Secrets + GitOps: don't commit a plaintext Secret to satisfy "git owns everything." Use
> Sealed Secrets / External Secrets (stretch) so the encrypted form is safe in git, or create
> the Secret out-of-band and let Argo ignore it. State your choice in ARCHITECTURE.md.
