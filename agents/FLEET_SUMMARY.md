# Complexit Engine Agent Fleet — Executive Summary

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLIENT ISOLATION SYSTEM                     │
│                          (SaaS Structure)                      │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌────────┐│
│  │  Client │  │  Client │  │  Client │  │  Client │  │ Client ││
│  │   A     │  │   B     │  │   C     │  │   D     │  │  E...  ││
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └────────┘│
│                     Stored in: clients/                         │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    ACTIVITY WATCHER ((origin)                  │
│                    monitors workflows, learns behavior         │
│                          stored in: activity-watchy/           │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                  ┌───────────┴───────────┐
                  │                       │
┌─────────────────┴────────────┐ ┌───────────┐
│      BENCH SCORER           │ │CSPO       │
│    (35B SSA Thursday Night) │ │ Publishing│
└──────────────────────────────┘ └───────────┘
                  ▲
              ┌───┴───┐
              │  NANO │
              │DISPATC│
              └───────┘
        ┌────────────┬─────────────┐
        │            │             │
┌───────┴── ─┐  ┌───┴────┐    ┌───┴────────┐
│   CODER    │  │ ARCHIT  │    │  VISION    │
│            │  │   ECT   │    │   WATCHER  │
└────────────┘  └─────────┘    └────────────┘
```

---

## Total Agent Fleet: 38 Experts

### **1. Core Infrastructure (9 agents)**
Handles: Implementation, routing, deployment, game, testing

| Agent | Cognitive Mode | Purpose |
|-------|---------------|---------|
| `coder` | Creative + Procedural | Implementation, tests, code |
| `uncertainty-manager` | Analytical | Confidence scoring, routing |
| `architect` | Design | System architecture design |
| `deployer` | Procedural | CI/CD execution gate |
| `writer` | Creative | Documentation authoring |
| `reader` | Analytical | Research + summarization |
| `reviewer` | Analytical | Code audit + security |
| `debugber` | Analytical | Error diagnosis + root cause |
| `test` | Analytical | Test case generation (no execution) |

### **2. Domain Experts (12 computation agents)**
Handles: Domain-specific questions and problems

| Agent | Domain | Key Knowledge |
|-------|--------|---------------|
| `python` | Python | PyPI, type hints, linting, virtualenv |
| `bioinformatics` | Proteins, Genomics | PDB sequences, BLAST, UniProt |
| `quantum-physics` | Physics | QM, entanglement, superposition |
| `classical-physics` | Physics | Newton, relativistic, engineering |
| `medical-science` | Healthcare | Diseases, treatments, pharmacology |
| `biology-genetics` | Life Sciences | DNA, evolution, molecular biology |
| `finance-economics` | Finance | Markets, risk, macroeconomics |
| `cryptocurrency | Blockchain | DeFi, smart contracts, tokenomics |
| `data-science` | Statistics | Tests, analysis, causal inference |
| `cybersecurity` | InfoSec | Vulnerabilities, threat modeling |
| `engineering` | Civil | Structures, materials, codes |
| `database` | SQL/NoSQL | Optimization, indexing, migrations |
| `machine-learning` | AI | Models, training, drift, MLOps |
| `frontend` | Web | HTML, CSS, JS, React, accessibility |
| `backend` | APIs | REST/GraphQL, databases, caching |
| `cloud-infra` | DevOps | Terraform, Kubernetes, AWS/GCP |
| `ai-safety` | Ethics | AI alignment, bias detection |
| `law-legal` | Legal | Precedents, statutes, jurisdiction |
| `product-pm` | PM | User stories, acceptance criteria |

### **3. Business/Marketing Agents (6 agents)**
Handles: Business growth, marketing, client acquisition

| Agent | Domain | Purpose |
|-------|--------|---------|
| `seo-ppc` | Digital Marketing | SEO metrics, PPC campaigns, ROAS |
| `wordpress-marketing` | WordPress | Theming, plugins, PHP, security, WPO |
| `social-media-marketing` | Social Media | Content plans, TikTok/Instagram analytics |
| `dicomm-web-apps | DICOM | Medical imaging standards, HIPAA compliance |
| `flutter-frameworks` | Mobile | Flutter/Dart, state management, apps |
| `framer-tools` | No-Code | Web builders, templates, automation |

---

## Client Learning & Isolation System

Each client gets their own isolated Qwen instance:

```
structure `
`
  ├── agents/          # Shared agent fleet (this entire /home/jon/dotfiles/agents/)
  ├── clients/         # Client isolation
  │   ├── client_a/                          # Client A
  │   │   ├── QWEN.md                        # Client-specific config
  │   │   ├── INFERRED.md                    # What this client taught
  │   │   └── agents/                        # Custom agents per client
  │   │       └── sales-agent/SOUL.md
  │   ├── client_b/                          # Client B (another instance)
  │   │   └── ...
  │   └── client_c/                          # Client C
  │       └── ...
  ├── activity-watcher/                       # Workflow monitoring
  │   ├── sessions/                           # Daily activity logs
  │   ├── workflows/                          # Pattern detection
  │   └── agents/                             # Suggestion agents
  │       ├── seo-sugg/SOUL.md
  │       ├── seo-poc-sugg/SOUL.md
  │       └── app-build-sugg/SOUL.md
  │
  └── learning/                               # Shared learning
      ├── gsplay/                             # GSPO training outputs
      ├── models/                             # Fine-tuned weights
      └── eval/                               # Long-form evaluations
```

---

## System Capabilities

### **Activity Monitoring & Suggestions**
The activity-watcher monitors client behavior patterns:
- Reads session logs from clients
- Triggers suggestion agents based on workflows
- Spawnies custom agents when needed
- Learns back to client-specific behavior

### **Client-Specific Qwen Instances**
- Each client has own config + inference
- No cross-client data leaks
- Learning is client-specific (unless explicitly shared)

### **Business Workflows**
The system suggests help across:
- **Search**: SEO (domain_authority), PPC (ROAS), Google + Facebook campaigns
- **Web**: WordPress theming, performance, security, plugins
- **Social**: TikTok, Instagram, content calendars, engagement rates
- **Mobile**: Flutter apps, state management, tests
- **DICOM**: Web-based medical imaging, standards, security
- **No-Code**: Framer templates, Webflow, automation (Zapier, Make)
- **Marketing**: Social strategies, content plans, influencer outreach
- **Finance**: Markets, risk analysis, economic theory
- **Apps**: Cryptocurrency, DeFi, NFTs, smart contracts
- **Legal**: Corporate, securities, AI regulation, jurisdiction research
- **Science**: Biology, genetics, chemistry, physics
- **Data Science**: Statistics, analysis, causal inference
- **AI/ML**: Models, training, MLOps, latency optimization
- **Infrastructure**: Terraform, Kubernetes, AWS/GCP, CI/CD
- **Security**: Vulnerabilities, threat modeling, penetration testing
- **AI Safety**: Alignment, ethics, bias detection

---

## Implementation Phase

### **Phase 1: Infrastructure (Current)**
- ✅ Agent fleet seeded
- ✅ Core 9 + 29 domain experts created
- ✅ Total: 38 agents ready

### **Phase 2: Client System**
- Need: Structure `clients/` directory
- Need: Per-client config (QWEN.md, INFERRED.md)
- Need: Isolated inference stacks

### **Phase 3: Activity Watcher**
- Need: Create activity-watcher directory
- Need: Workflow monitors
- Need: Suggestion agents (seo-sugg, ppc-sugg, etc.)

### **Phase 4: Learning Stack**
- Need: Shared learning directory (learning/)
- Need: GSPO/GSPO outputs
- Need: Evaluation pipeline

---

## Next Steps

The fleet needs:
1. **Client isolation**: Create clients/ directory structure per above
2. **Activity watcher**: Create activity-watchy/ with monitoring
3. **Workflow triggers**: Code that watches client sessions + triggers suggestions
4. **Shared learning**: Save trajectories and aggregate patterns across clients (but only when authorized to share)

Ready to proceed? The 38 agents are loaded and waiting.
