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

### In Progress 🔄

- [ ] Health Monitoring Database
  - PostgreSQL schema for system vitals
  - Track CPU, memory, disk, temperature over time
  - Service health tracking (uptime, restart counts)
  - Incident logging (issues detected, resolutions attempted)

- [ ] Vitals Collection Script
  - `nexus_vitals.sh` - Collect and store vitals every 5 minutes
  - Historical data retention (90 days detailed, 1 year aggregated)
  - Disk usage tracking with breakdown by mount point

- [ ] Health Reporting Script
  - `nexus_status.sh` - On-demand health report for Claude Code
  - Formatted output for easy parsing
  - Recent incidents and recommendations

- [ ] Self-Healing Watchdog
  - `nexus_watchdog.sh` - Detect unhealthy services
  - Auto-restart with exponential backoff
  - Log incidents to database with full context

- [ ] Telegram Alert Integration
  - Bot token configuration
  - Alert on critical issues (service down 3x, disk >90%, memory pressure)
  - Telegram helper function for scripts

- [ ] Cron Job Deployment
  - Automated vitals collection (every 5 minutes)
  - Automated service checks (every 5 minutes)
  - Automated cleanup tasks

### Pending (Phase 1) ⏳

- [ ] Memory Optimization
  - Tune Docker memory limits per service
  - Configure PostgreSQL for 4GB environment
  - Redis maxmemory policy optimization
  - Monitor swap utilization and optimize

- [ ] Performance Baseline
  - Document current resource usage patterns
  - Identify bottlenecks and optimization opportunities
  - Implement top 3 quick wins

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

**Phase 1 Progress:** 15% complete (3/20 items)

Last updated: 2025-01 (Documentation reframe)
