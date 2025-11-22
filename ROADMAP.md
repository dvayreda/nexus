# Nexus Development Roadmap

**Living document - Updated as I evolve**

This roadmap defines my development priorities. When you ask me to work on something, I check this document first. If it's not here, we discuss whether to add it or stay focused on current work.

---

## Current Focus: Phase 1 - Stability Foundation

**Status:** In Progress (Started: 2025-01)

**Goal:** Transform from a basic server into a self-aware, self-healing infrastructure platform optimized for Raspberry Pi 4 constraints.

### Completed ✅

- [x] Documentation reframe (first-person voice)
  - README.md speaks as Nexus
  - claude.md teaches Claude Code how to be Nexus
  - ROADMAP.md created for focus enforcement

- [x] Health Monitoring Database
  - PostgreSQL schema for system vitals
  - Track CPU, memory, disk, temperature over time
  - Service health tracking (uptime, restart counts)
  - Incident logging (issues detected, resolutions attempted)

- [x] Vitals Collection Script
  - `nexus_vitals.sh` - Collect and store vitals every 5 minutes
  - Historical data retention (90 days detailed, 1 year aggregated)
  - Disk usage tracking with breakdown by mount point

- [x] Health Reporting Script
  - `nexus_status_simple.sh` - On-demand health report for Claude Code
  - Formatted output for easy parsing
  - Recent incidents and recommendations

- [x] Self-Healing Watchdog
  - `nexus_watchdog.sh` - Detect unhealthy services
  - Auto-restart with exponential backoff
  - Log incidents to database with full context

- [x] Cron Job Deployment
  - Automated vitals collection (every 5 minutes)
  - Automated service checks (every 5 minutes)
  - 167 vitals data points collected since deployment

- [x] Telegram Alert Integration
  - Bot token and chat ID configured
  - Alert on critical issues (service down, disk >90%, memory pressure)
  - Daily morning health report (8:00 AM)
  - Tested successfully with service restart detection

- [x] Memory Optimization
  - Docker memory limits set per service (n8n: 600M, postgres: 512M, redis: 128M, watchtower: 64M)
  - PostgreSQL optimized for 4GB Pi (effective_cache_size: 1GB, shared_buffers: 128MB)
  - Redis maxmemory: 100MB with allkeys-lru policy
  - code-server removed (unused, freed 70MB)
  - Memory usage reduced from 946MB to 745MB
  - Swap monitoring via watchdog (alerts at >80%)

- [x] Performance Baseline
  - Documented resource usage patterns (CPU, memory, disk, temperature)
  - Identified bottlenecks: netdata (27% CPU), disabled fsync, inaccurate vitals
  - Implemented optimizations:
    - Removed netdata (27% CPU savings, 115MB RAM freed)
    - Re-enabled PostgreSQL fsync with tuning (data safety restored)
    - Fixed vitals script memory collection (accurate MB-to-GB conversion)

### In Progress 🔄

Currently no tasks in progress.

### Pending (Phase 1) ⏳

- [ ] Documentation Cleanup
  - Remove deprecated FactsMind documentation
  - Update faceless_prod → factsmind references
  - Verify all links work correctly

**Phase 1 Complete When:**
- I can answer "how am I doing?" with real database-backed data
- Services auto-restart and log investigation results
- Disk never fills (automated cleanup)
- Memory pressure detected before OOM
- User receives Telegram alerts for critical issues

---

## Phase 2: Multi-Project Support

**Status:** Not Started (Estimated Start: After Phase 1)

**Goal:** Enable hosting multiple content creation projects simultaneously with proper isolation and resource management.

### Planned Features

- [ ] Application Registry Enhancement
  - Automated dependency tracking
  - Version compatibility validation
  - Project health monitoring

- [ ] Project Template System
  - Onboarding guide for new applications
  - Template repository structure
  - Standard volume mount patterns

- [ ] Resource Isolation
  - Docker resource limits per project
  - Network isolation if needed
  - Storage quotas and monitoring

- [ ] Multi-Project Dashboard
  - View all hosted projects status
  - Resource usage per project
  - Quick access to project logs

**Phase 2 Complete When:**
- Adding a new project takes <1 hour
- Projects don't interfere with each other
- Resource usage is tracked per-project
- Clear documentation for project onboarding

---

## Phase 3: Migration Ready

**Status:** Not Started (Estimated Start: When Pi becomes bottleneck)

**Goal:** Prepare for migration to more powerful hardware while maintaining all current access patterns.

### Planned Features

- [ ] Portable Configuration
  - All configs use environment variables
  - No hardcoded paths or IPs
  - Docker Compose remains primary deployment method

- [ ] Migration Documentation
  - Step-by-step migration guide
  - Backup/restore procedures validated
  - Downtime minimization strategies

- [ ] Hardware Requirements Analysis
  - Define minimum specs for new server
  - Cost analysis (see strategic docs)
  - Performance projections

- [ ] Cloud-Ready Architecture
  - Option for hybrid Pi + Cloud (Nexus 2.0 Option B)
  - API-based communication between components
  - Secrets management for cloud credentials

**Phase 3 Complete When:**
- Full backup/restore tested successfully
- Migration procedure documented step-by-step
- New hardware requirements defined
- Claude Code access pattern unchanged

---

## Future Enhancements (Backlog)

Ideas for consideration after core phases complete:

### Infrastructure
- [ ] Automated testing framework for infrastructure changes
- [ ] CI/CD pipeline for deployment automation
- [ ] Advanced monitoring with anomaly detection
- [ ] API for programmatic infrastructure management

### Projects
- [ ] Project marketplace/template library
- [ ] Shared asset management across projects
- [ ] Cross-project analytics dashboard
- [ ] A/B testing framework

### Platform
- [ ] Web UI for infrastructure management
- [ ] Mobile monitoring app
- [ ] Advanced secrets management (vault integration)
- [ ] Multi-user access control

---

## The No Distractions Rule

**When you ask me to work on something not listed above:**

I will respond with:
> "That's not on my current roadmap. I'm focused on Phase 1: Stability Foundation.
>
> Should we:
> 1. Add this to Phase 1 (if critical)
> 2. Add to Phase 2/3 backlog (if valuable)
> 3. Finish current work first (stay focused)
>
> What's the priority?"

**Exception:** If it's a FactsMind task:
> "That's a FactsMind application task, not Nexus infrastructure.
> Please open Claude Code in `/home/dvayr/Projects_linux/factsmind/` for that work."

**My job is to keep you focused and prevent scope creep.**

---

## Decision Log

**Why this order?**

1. **Stability first:** Without health monitoring and self-healing, I'm unreliable
2. **Optimize current hardware:** Max out Pi potential before throwing money at upgrades
3. **Multi-project later:** Current single project (FactsMind) is stable - don't optimize prematurely
4. **Migration last:** No point planning migration until Pi is actually a bottleneck

**Key Principles:**
- ✅ Fix visibility before adding features (monitoring first)
- ✅ Automate before scaling (self-healing before multi-project)
- ✅ Measure before migrating (performance baseline before new hardware)
- ✅ Ship incrementally (complete phases, don't partially implement many things)

---

## How to Update This Roadmap

**Adding Items:**
1. Discuss with me (Nexus) first - is it infrastructure or application work?
2. Decide which phase it belongs to
3. Update this file
4. Commit with: `docs: Update roadmap with [new item]`

**Marking Complete:**
1. Verify the work is actually done (tested, documented, deployed)
2. Move item to "Completed" section
3. Update progress indicators
4. Commit with: `docs: Mark [item] complete in roadmap`

**Changing Priorities:**
1. Discuss rationale (why is this more important now?)
2. Update phase ordering or item priorities
3. Document decision in Decision Log
4. Commit with: `docs: Reprioritize roadmap - [reason]`

---

## Progress Tracking

**Phase 1 Progress:** 85% complete (11/13 items)

- ✅ Core monitoring infrastructure operational
- ✅ Self-healing watchdog active
- ✅ Database-backed health tracking
- ✅ Telegram alerts configured and tested
- ✅ Daily morning health reports via Telegram
- ✅ Memory optimization complete (20% reduction, proper limits enforced)
- ✅ Performance baseline complete (netdata removed, fsync restored, vitals fixed)
- ⏳ Documentation cleanup remaining (final Phase 1 task)

Last updated: 2025-11-22 (Performance baseline complete: 27% CPU reduction, accurate vitals monitoring)
