# ADR-0012: k3s Model A — Per-Client KVM Node Isolation

## Status
Accepted

## Context
The dotfiles system is evolving from a single-user tool into a multi-client platform serving both internal IP and external paying clients. SOC 2 compliance requires demonstrable isolation between clients. Each client = one repository with its own openclaw instance, debates, memories, and agent configuration.

Two models were evaluated:
- **Model B**: Single `docker-sbx` KVM VM, k3s cluster inside, namespaces per client.
- **Model A**: k3s cluster on bare metal, each client gets its own `docker-sbx` KVM worker node.

## Decision
Use **Model A**: k3s control plane on bare metal, one `docker-sbx` KVM VM per client as a k3s worker node. One shared GPU worker node for the Inference Sandbox (llama.cpp).

## Architecture

```
bare metal (host OS only — no workloads)
├── control-plane: docker-sbx VM — dotfiles (k3s server, GPU passthrough, llama.cpp daemonset)
├── node: docker-sbx VM — example1.com (k3s agent, no GPU, git clone)
├── node: docker-sbx VM — example2.com (k3s agent, no GPU, git clone)
└── node: docker-sbx VM — example3.com (k3s agent, no GPU, git clone)
```

All nodes use `docker-sbx` (KVM isolation). GPU passthrough only to control-plane node. Consistent runtime across cluster — one audit pattern for SOC 2.

**Networking**: Tailscale mesh (not Flannel). k3s runs with `--flannel-backend=none`. Each node joins the tailnet via `tailscaled`. Tailscale ACLs enforce: client-node → inference port 8080 allowed; client-node → client-node DENIED. ACL file in git = network policy audit artifact. New client provisioning: install Tailscale + join tailnet + join k3s cluster. Tailscale admin console = network audit log for SOC 2.

Each client node:
- KVM hardware isolation boundary (not just Linux namespaces)
- Own PVC-backed storage for debates, memories, openclaw config
- Egress: Discord + GitHub + Inference Sandbox only
- k3s RBAC namespace scoped to client slug
- kube-audit log per node for SOC 2 evidence

Inference Sandbox (shared):
- Single GPU node, logically shared across clients
- Stateless per-request (no cross-client context)
- Timing side-channels exist — documented in client contracts as "shared compute tier"
- Physical isolation requires separate GPU per client (out of scope for current hardware)

## Alternatives Considered
- **Model B (single VM)**: SOC 2 auditors prefer VM-level isolation between paying clients. Namespace isolation alone is insufficient for external client contracts.
- **Separate GPU per client**: Requires multi-GPU hardware. Current machine has one 8GB GPU. Documented as upgrade path.

## Consequences
- Each new client = provision one `docker-sbx` VM + join to k3s cluster
- k3s control plane on bare metal + one GPU node + N client nodes
- `make client-add SLUG=<name>` target needed for provisioning
- Inference Sandbox shared compute must be disclosed in client contracts
- Upgrade path: dedicated GPU node per client tier for higher-paying clients
