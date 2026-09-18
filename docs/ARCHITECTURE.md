# Architecture

## 1. Topology diagram

```
                         Internet
                             │
                        DNS (DuckDNS)
                 taskapp-gift-capstone.duckdns.org
                             │
                             ▼
              ┌───────────────────────────────┐
              │   any worker's public IP        │
              │   ingress-nginx (DaemonSet,      │
              │   hostNetwork, one pod per        │
              │   worker) — TLS terminated here   │
              │   with the cert-manager/Let's       │
              │   Encrypt cert                       │
              └───────────────┬───────────────────┘
                               │  Ingress rule, single host, "/"
                               ▼
                     frontend Service (ClusterIP)
                               │
                 ┌─────────────┴─────────────┐
                 ▼                           ▼
        frontend Pod (worker A)      frontend Pod (worker B)
                 │ nginx proxies /api/* to backend
                 ▼
                     backend Service (ClusterIP)
                               │
                 ┌─────────────┴─────────────┐
                 ▼                           ▼
         backend Pod (worker B)      backend Pod (worker C)
                               │
                               ▼
                   postgres Service (headless)
                               │
                               ▼
                      postgres-0 (worker A)
                      PVC on local-path, pinned
                      to whichever node it first
                      landed on

   control-plane (tainted CriticalAddonsOnly, no app workloads)
   runs: k3s server, coredns, metrics-server, local-path-provisioner
```

Backend and frontend each run 2 replicas spread across the 3 workers via
`topologySpreadConstraints`, so which exact worker ends up with which pod shifts over time —
the diagram above is one snapshot, not a fixed assignment. The control-plane never runs any of
this; it's tainted specifically to keep it free for the cluster's own control loop.

## 2. Node & network

Four EC2 instances in `eu-north-1` (Stockholm), all `t3.micro`: one control-plane, three
workers. I originally built this with two workers and found out the hard way that it's not
enough — see the trade-offs section below. I did try bumping the control-plane specifically to
`t3.medium` at one point since it was the one node actually showing memory pressure, but this
particular AWS account has a free-tier guardrail that flat-out rejects launching any
non-free-tier-eligible instance type, credit balance or not. So all four nodes are `t3.micro`
for now — a real, known limitation, not a design choice.

Network is one VPC (`10.60.0.0/16`) with a single public subnet (`10.60.1.0/24`) — no NAT
gateway, no private subnet, because every node needs a public IP for Ansible/kubectl access
anyway and adding a NAT gateway just to look more "enterprise" would be pure cost with no
benefit at this scale.

Firewall (one security group, shared by all four nodes):
- `22` (SSH) — admin CIDR only, never the world
- `80` / `443` — open to the world, that's the actual front door
- `6443` (kube-apiserver) — admin CIDR only. This is the one AWS explicitly forbids leaving
  open to `0.0.0.0/0`, and it's also just common sense — nobody outside my laptop's IP needs to
  talk to the API server directly
- everything else (flannel VXLAN, kubelet, the ingress admission webhook) — open only inside
  the security group itself, so node-to-node traffic works but nothing from outside the VPC can
  reach it

## 3. Request flow

A request to `taskapp-gift-capstone.duckdns.org` resolves via DuckDNS to whichever worker's
public IP I last pointed it at. That worker's ingress-nginx pod (it runs on all three workers,
identically, as a DaemonSet with `hostNetwork: true`) terminates TLS using the cert
cert-manager pulled from Let's Encrypt, then matches the single `Ingress` rule for this host and
forwards to the `frontend` Service. The Service picks one of the two frontend Pods (wherever
they happen to be scheduled); frontend's own nginx config proxies anything under `/api` to the
`backend` Service, which again picks one of the two backend Pods; backend talks to Postgres over
a headless Service that resolves straight to `postgres-0`'s pod IP. Same-origin `/api` routing
was the simpler call here over a separate `api.` subdomain — one Ingress, one cert, one DNS
record to keep pointed at the right place, and there's no real need for the frontend and backend
to live on different hostnames for an app this size.

## 4. The single-server assumptions this fixes

| Assumption that was fine on one box | Why it breaks on a cluster | What actually fixes it |
|---|---|---|
| Run migrations in the app's own entrypoint | Two+ replicas both start at once and race on `alembic upgrade head` | A separate one-shot `taskapp-migrate` Job that runs to completion *before* the replicas start — never inside them |
| A named Docker volume for Postgres | Pods get rescheduled to whatever node has room; a plain volume doesn't follow them | A `StatefulSet` + `PVC` on the `local-path` storage class — Kubernetes tracks which node the volume is actually on and keeps the pod pinned there |
| `ports:` published straight on the host | Now there are 2-3 replicas of everything on different nodes; you can't hand someone three IPs and a port number | `Service` + `Ingress` — one DNS name, one entry point, Kubernetes handles routing to whichever Pod is actually healthy |
| One process, no failover if it dies | A VM reboot or crash used to just mean downtime until someone noticed | 2 replicas each for backend/frontend, spread across different nodes, backed by a `PodDisruptionBudget` so a node drain can only take one at a time |
| Manually requesting/renewing a cert | Doesn't scale past one box, and self-signed certs aren't acceptable for anything real | `cert-manager` + a Let's Encrypt `ClusterIssuer`, fully automatic issuance and renewal |
| `docker-compose up -d` to deploy | Nothing stops the live cluster from silently drifting away from what's actually in git | Argo CD watches the repo and reconciles — a commit is the only way changes are supposed to land, and it self-heals anything changed out-of-band |

## 5. Choices & trade-offs

**Raw YAML, not Helm or kustomize.** Everything here is a small, fixed, hand-tuned set of
manifests — I know exactly what's in every file. Helm would add a templating layer for no real
benefit at this size, and I'd specifically checked: it doesn't reduce what actually gets
deployed. A default Helm install of something like Argo CD pulls in more than I actually need
(I stripped out dex, the notifications controller, and the ApplicationSet controller from the
static manifests, and trimmed resource requests down from upstream's defaults — a chart install
wouldn't have given me that for free).

**ingress-nginx, not k3s's bundled Traefik.** k3s ships Traefik + ServiceLB by default; both are
disabled in the k3s server config here. Went with ingress-nginx instead mostly because
cert-manager's own docs and most of the troubleshooting content out there assume it, and I
wanted explicit control over running it as a DaemonSet with `hostNetwork` rather than relying on
k3s's opinionated defaults, which are more aimed at a single-node setup than a real multi-node
one.

**kube-router layered on top of Flannel, just for NetworkPolicy.** k3s's default CNI (Flannel)
doesn't enforce `NetworkPolicy` at all — it'll happily let you create one and just silently do
nothing. kube-router runs alongside it in policy-only mode (`--enable-cni=false
--run-firewall=true`), so Flannel still handles the actual networking and kube-router only
programs the iptables rules for policy enforcement. It's excluded from the control-plane, since
that node doesn't run anything that needs policy enforcement in the first place.

**Secrets applied out-of-band, not Sealed Secrets or External Secrets.** The real Secret never
touches git — it's applied by hand on every fresh cluster (see `RUNBOOK.md`). Sealed Secrets
would let it live safely in git and is the obvious next step, but it's more moving parts than
this project's timeline had room for; it's flagged as a Phase 2 item rather than skipped
silently.

**Two workers wasn't enough, three is the actual minimum.** I built this with two workers
first. It turns out `topologySpreadConstraints` with `maxSkew: 1` and
`whenUnsatisfiable: DoNotSchedule` — which is what keeps backend/frontend replicas off the same
node — has a real gap with only two workers: draining one leaves exactly one place for the
evicted pod's replacement, and doubling up there violates the skew constraint outright. The pod
just sits `Pending` for as long as the drain lasts. Three workers means draining one still
leaves two valid places to land, so the constraint can always be satisfied. This wasn't obvious
until I actually tried a live drain and watched it happen.
