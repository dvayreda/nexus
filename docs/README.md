# Nexus Documentation

Organized documentation for the Nexus AI content automation platform.

## Structure

### 📦 [setup/](setup/)
Installation, configuration, and getting started guides.

- **[quickstart.md](setup/quickstart.md)** - Complete setup guide for Nexus on Raspberry Pi

### 🚀 [projects/](projects/)
Project-specific documentation for content pipelines.

- **[factsmind.md](projects/factsmind.md)** - FactsMind Instagram carousel system (production)

### ⚙️ [operations/](operations/)
Day-to-day operations, maintenance, and troubleshooting.

- **[maintenance.md](operations/maintenance.md)** - System maintenance procedures and troubleshooting
- **[instagram-posting-strategy.md](operations/instagram-posting-strategy.md)** - Instagram posting strategy for global educational content
- **[n8n-mcp-setup.md](operations/n8n-mcp-setup.md)** - n8n MCP integration setup

### 🏗️ [architecture/](architecture/)
System design, architecture decisions, and technical reference.

- **[system-reference.md](architecture/system-reference.md)** - Complete system architecture reference

### 🤖 [ai-context/](ai-context/)
Instructions and context for AI assistants working with this codebase.

- **[claude.md](ai-context/claude.md)** - Instructions for Claude Code
- **[gemini.md](ai-context/gemini.md)** - Instructions for Google Gemini

## Quick Navigation

**I want to...**

- 🆕 **Set up Nexus** → [setup/quickstart.md](setup/quickstart.md)
- 🎨 **Understand FactsMind** → [projects/factsmind.md](projects/factsmind.md)
- 🔧 **Fix an issue** → [operations/maintenance.md](operations/maintenance.md)
- 🏛️ **Learn the architecture** → [architecture/system-reference.md](architecture/system-reference.md)
- 🤖 **Work with AI assistants** → [ai-context/claude.md](ai-context/claude.md)

## Documentation Principles

1. **Single Source of Truth** - Each topic documented once, in one place
2. **Practical Focus** - Real-world operations over theoretical planning
3. **Up-to-date** - Documentation reflects current system state, not future plans
4. **Organized** - Logical folder structure for easy navigation
5. **Concise** - Clear and brief, with links to detailed sections

## Contributing

When updating documentation:

1. Keep it current - remove outdated information
2. Be specific - include exact commands, paths, and versions
3. Add context - explain *why*, not just *what*
4. Test it - verify commands and procedures actually work
5. Link it - cross-reference related documentation

## History

Previous documentation structure (before 2025-11-18) included scattered markdown files in the root directory and multiple `phase*_docs/` folders. Consolidated into this organized structure for better maintainability.
