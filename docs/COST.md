# Cost

Numbers below are rough — based on `eu-north-1` on-demand pricing at the time of writing, not an
actual invoice, since this hasn't run for a full billing month yet. Treat them as "roughly this
much," not exact.

## Monthly itemized cost

| Item | Spec | Qty | $/mo (roughly) |
|---|---|---:|---:|
| control-plane VM | `t3.micro`, 1 vCPU/1GiB burstable | 1 | see note below |
| worker VMs | `t3.micro`, 1 vCPU/1GiB burstable | 3 | see note below |
| EBS (root volumes) | 8GB gp3 each, 4 nodes = 32GB total | 4 | ~$0.20 |
| S3 (Terraform state) | one tiny state file, a handful of requests | 1 | $0 (free tier) |
| DynamoDB (state lock) | one table, negligible read/write | 1 | $0 (always-free tier) |
| DNS | DuckDNS | 1 | $0 |
| TLS cert | Let's Encrypt via cert-manager | 1 | $0 |
| **Total** | | | **~$25/mo if left running 24/7** |

The EC2 line is the only one that actually costs anything, and it's not as simple as
`instances × hourly rate` — AWS's free tier gives 750 instance-hours a month for `t2.micro`/
`t3.micro`, but that's a shared pool across *all* your micro instances combined, not 750 hours
per instance. Four nodes running 24/7 is roughly 2,920 instance-hours a month; the first 750 of
those are free, the remaining ~2,170 are billed at the normal `t3.micro` rate (around
$0.0116/hr here), which lands at roughly $25/month. If the cluster's only up for part of the
month — which is the actual plan, see below — this drops a lot, potentially to $0 if it never
crosses that 750-hour pool at all.

## Compared to the single-server Compose+Portainer deploy
- That stack was one box, comfortably inside the free 750 hours on its own: **~$0/month**.
- This cluster, run continuously: **~$25/month**.
- **What the extra ~$25 buys:** the app survives losing a node instead of just going down,
  backend can scale under load instead of falling over, deploys don't drop requests, and
  nothing needs a human to notice and restart it. None of that existed on the single-box setup.
- **When it's not worth it:** anything low-traffic enough that an occasional restart is a
  non-event, or a project that doesn't need to prove it survives failure. This capstone
  specifically needed to prove that, so the extra spend is the point, not overhead.

## How I'd halve this

The honest answer isn't a smaller instance type or Spot pricing — it's not running it 24/7 in
the first place. `terraform destroy` between work sessions and after grading is done means
paying for actual hours used instead of a whole month of uptime, which is most of the cost
right there. If continuous uptime were actually required, dropping back to 3 nodes total (1
control-plane + 2 workers) would cut the EC2 line by 25%, but that specifically breaks the
node-drain resilience this project is meant to demonstrate (see the trade-offs section in
`ARCHITECTURE.md` — two workers isn't enough for the topology spread constraints to survive
losing one). Spot instances would cut the EC2 cost further still, but they're a bad fit for a
cluster whose whole purpose is testing what happens when a node disappears unexpectedly — a Spot
reclaim would look identical to the failure I'm already deliberately causing, which just
muddies the one thing this project is trying to prove.
