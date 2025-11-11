---
version: 1.0
last_updated: 2025-11-10T19:06:17Z
maintainer: selto
---

# 00_Nexus_Project_Overview

## Objective
Provide a concise conceptual overview of the Nexus system. Explain purpose, architecture, workflows, and design principles so any operator understands what the system is and why it exists.

## Applies to
Raspberry Pi 4 (nexus) with NASPi V2.0 case, internal SATA system SSD, external USB3 backup drive, Docker Compose stack (n8n, PostgreSQL, code-server, Netdata, Watchtower), Tailscale remote access.

---
## What is Nexus?
Nexus is a self-contained automation workstation built to generate, render and publish short-form content (carousels, shorts) using AI and scripted automation. It is intended to be resilient, observable and recoverable. Nexus runs on a Raspberry Pi 4 as a low-power production node and is designed to be migrated to more powerful hardware when needed.

## Core idea
Three closed loops:
- **Creation loop**: Prompts (Claude/Groq/Gemini) -> generate facts/text -> select images -> render final assets.
- **Automation loop**: n8n orchestrates the generation, reviews, approvals and publishes to channels (IG/X/TikTok/YouTube).
- **Recovery loop**: rsync + rclone + dd images ensure backups and full system rebuilds are possible.

## Architecture (high level)
| Layer | Component | Role |
|---|---:|---|
| Hardware | Raspberry Pi 4 + NASPi V2.0 | Host node, internal system SSD |
| Storage | Internal SATA SSD, External USB3 backup | System + local backups |
| Network | LAN + Tailscale | Local access + secure remote access |
| Runtime | Docker Compose | Containerized services and isolation |
| Services | n8n, Postgres, code-server, Netdata, Watchtower | Orchestration, persistence, IDE, monitoring, updates |
| Backup | rsync, rclone, dd | Local snapshots + offsite sync |
| Security | SSH keys, read-only containers, secrets | Access control and containment |

## Workflow lifecycle (simple)
1. **Generate**: n8n scheduled trigger calls AI to create text/facts.  
2. **Fetch**: Pexels API (or local assets) provides candidate images.  
3. **Compose**: Python/FFmpeg scripts render 5-slide carousels and short videos.  
4. **Review**: Telegram manual review step. Human approves candidate.  
5. **Publish**: n8n uploads to platform APIs or queues for manual publish.  
6. **Track**: Post metadata stored in Postgres and aggregated for performance tuning.

## Design principles
- **Autonomy**: minimize manual work. Start automatic, remain human-in-the-loop until stable.
- **Observability**: metrics and logs for every stage. Netdata + Postgres events table.
- **Recoverability**: full-image restore and per-artifact verification via checksums.
- **Modularity**: replaceable services and clear APIs between components.
- **Security**: least-privilege tokens, SSH-only access, read-only containers where feasible.

## Next steps
After Phase 1 docs you will get a full system setup guide, application deployment examples and operational runbooks. This file is the anchor: link to it from README.md so new contributors read it first.
