# Runbook

Everything here is copy-pasted from commands I've actually run rebuilding this cluster from
scratch twice. If something doesn't match what you see, trust your terminal over this doc and
fix the doc after.

## Provision from zero

Remote state (S3 bucket + DynamoDB lock table) only needs doing once per AWS account — it's in
`infra/terraform/bootstrap/`. If it already exists, skip straight to the main stack.

```bash
# 1. infra — nodes, network, firewall
cd infra/terraform
terraform init
terraform apply

# 2. inventory — pulls IPs out of the Terraform outputs, no manual editing
cd ..
bash ansible/scripts/generate-inventory.sh

# 3. cluster — hardens the boxes, installs k3s, joins the workers
cd ansible
ansible-playbook -i inventory/hosts.yaml playbooks/site.yml

# 4. kubeconfig lands here automatically as part of the playbook, server address already
#    rewritten to the control-plane's public IP
export KUBECONFIG=infra/ansible/fetched/kubeconfig
kubectl get nodes
```

At this point you've got a bare cluster with nothing running on it except k3s's own core stuff
(coredns, metrics-server, local-path-provisioner). Everything else — ingress, cert-manager,
the app — is supposed to come from Argo CD, not from us running `kubectl apply` by hand. There
are three exceptions to that, and they're annoying enough that I'm writing them down properly:

```bash
# Argo CD itself has to be installed before it can manage anything, and its own manifest
# doesn't create its namespace for you — found this out the hard way.
kubectl create namespace argocd
kubectl apply -n argocd -f gitops/install/argocd-install.yaml

# this is the one app object you apply by hand — it's what tells Argo CD to go look at the
# rest of gitops/. Everything downstream of this is automatic.
kubectl apply -f gitops/root-app.yaml

# the app Secret is deliberately NOT in git (see manifests/secret.example.yaml for the shape),
# so Argo CD has no way to create it. Apply your real one manually, once, on every fresh
# cluster:
kubectl apply -f manifests/secret.yaml

# same story for the ingress-nginx admission Jobs — they self-delete
# (ttlSecondsAfterFinished: 0) the moment they finish, which made Argo CD think they'd
# drifted and try to recreate them forever. They're excluded from tracking on purpose, so
# they also need a manual apply:
kubectl apply -f manifests/platform/ingress-nginx/admission-jobs.yaml
```

Give it a couple of minutes and check:

```bash
kubectl get applications -n argocd     # root / platform / taskapp, all Synced + Healthy
kubectl get certificate -n taskapp     # taskapp-tls, READY=True once DNS + the HTTP-01
                                        # challenge go through
```

Last manual step, and it's outside Kubernetes entirely: point your DuckDNS record at one of
the worker public IPs (any of them — ingress-nginx runs on all three as a DaemonSet). Terraform
prints these as `worker_public_ips` when it finishes.

## Day-2 operations

**Scale a tier.** Don't `kubectl scale` it directly — that gets reverted the next time Argo CD
reconciles, since it thinks you drifted from git. Edit the replica count in
`manifests/backend/deployment.yaml` (or `frontend/`), commit, push. Argo CD picks it up within
its normal poll interval, or force it sooner with `kubectl annotate app taskapp -n argocd
argocd.argoproj.io/refresh=hard --overwrite`.

**Roll back a bad deploy.** Same idea in reverse: `git revert` the commit that broke things and
push. Argo CD syncs the reverted state back down. Resist the urge to fix it live with `kubectl
edit` — it'll just get stomped on the next sync anyway.

**Run a new migration safely.** Migrations run as a one-shot Job (`taskapp-migrate`), not in the
replicas' own startup, specifically so two replicas don't both try `alembic upgrade head` at
once. A completed Job won't re-run itself — if you need to run one again, delete the old Job
first (`kubectl delete job taskapp-migrate -n taskapp`) then re-apply.

**Rotate a secret.** Edit `manifests/secret.yaml` locally, `kubectl apply -f` it directly (it's
out-of-band, same as the first bootstrap). Existing pods won't pick up the change on their own
since it's mounted as env vars at container start — restart them: `kubectl rollout restart
deployment/backend -n taskapp` (and `frontend` if it touched anything there too).

## Failure recovery

**A worker node dies or gets drained.** This is the scenario the whole 3-worker topology exists
for.
```bash
kubectl get pod -n taskapp postgres-0 -o wide   # don't drain whichever node this says
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
```
Expect the evicted backend/frontend pod to land on one of the other two workers within about
20-30 seconds, with zero dropped requests in between — `docs/EVIDENCE/failover.png` /
`zero-downtime.log` show this actually happening. `kubectl uncordon <node>` brings it back into
rotation once whatever you were doing is done.

If the node hosting Postgres is the one that dies, that's a real gap, not a drill — Postgres is
a single instance with its PDB set to `minAvailable: 1`, which means the cluster will correctly
*refuse* to evict it. You'd be looking at manual intervention (or a restore from backup, once
that exists) rather than automatic failover. This is a known, accepted trade-off for this
project — see the HA discussion in `ARCHITECTURE.md`.

**A backend Pod is crashlooping.**
```bash
kubectl logs <pod> -n taskapp --previous     # what it said right before it died
kubectl describe pod <pod> -n taskapp        # events at the bottom, usually the real story
```
Most common causes so far: the Secret missing on a fresh cluster (see bootstrap above), or the
migration Job hasn't completed yet so the app can't reach a matching schema.

**A migration goes bad.** Because migrations are a separate Job and not baked into the
replicas' entrypoint, a broken migration just fails that one Job — the already-running replicas
keep serving on whatever schema was there before, they don't crash. Fix forward with a new
migration, or roll the image tag back to the last known-good SHA in `deployment.yaml` and
re-run the Job against that version.

**Postgres Pod gets rescheduled (not the node, just the Pod).**
```bash
kubectl delete pod postgres-0 -n taskapp
kubectl get pod postgres-0 -n taskapp -o wide -w   # comes back on the SAME node — its PVC is
                                                    # pinned there by local-path
kubectl exec -n taskapp postgres-0 -- psql -U taskapp -d taskapp -c '\dt'   # data's still there
```
