# n8n MCP Server Setup for Claude Code

## What This Enables

Once configured, Claude Code will be able to:
- **Read** all your n8n workflows and their configurations
- **Create** new n8n workflows via conversation
- **Modify** existing workflows with AI assistance
- **Trigger** workflows programmatically
- **Debug** workflow issues with full context
- Access documentation for **543 n8n nodes**

## Installation Steps

### Option 1: Using npx (Recommended - Simplest)

1. **Open Windows PowerShell** (not WSL2)

2. **Navigate to your Claude Code config directory:**
   ```powershell
   cd $env:APPDATA\Claude
   ```

3. **Create or edit `claude_desktop_config.json`:**

   If the file doesn't exist, create it with:
   ```json
   {
     "mcpServers": {
       "n8n": {
         "command": "npx",
         "args": ["n8n-mcp"],
         "env": {
           "N8N_API_URL": "http://100.122.207.23:5678",
           "N8N_API_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI1ZDFlODcwMi0wODc3LTQ0NTktYjVkYi01MGFlN2M0YTFhMzAiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzYzNDYxNzUwfQ.N24CTPOkL3bKn4_bTMO8BCYtCfQD9Qe4Rqq0pPumwrU",
           "MCP_MODE": "stdio",
           "LOG_LEVEL": "error",
           "DISABLE_CONSOLE_OUTPUT": "true"
         }
       }
     }
   }
   ```

   If the file exists and has other MCP servers, add the `n8n` section to the existing `mcpServers` object.

4. **Restart Claude Code** completely (close all windows and reopen)

5. **Verify** by asking Claude: "What n8n workflows do I have?"

### Option 2: Using WSL2 npx (Cross-Platform)

If you want to run the MCP server from WSL2:

1. **Edit Claude config on Windows:**
   ```json
   {
     "mcpServers": {
       "n8n": {
         "command": "wsl",
         "args": ["npx", "n8n-mcp"],
         "env": {
           "N8N_API_URL": "http://100.122.207.23:5678",
           "N8N_API_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI1ZDFlODcwMi0wODc3LTQ0NTktYjVkYi01MGFlN2M0YTFhMzAiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzYzNDYxNzUwfQ.N24CTPOkL3bKn4_bTMO8BCYtCfQD9Qe4Rqq0pPumwrU",
           "MCP_MODE": "stdio",
           "LOG_LEVEL": "error"
         }
       }
     }
   }
   ```

2. Restart Claude Code

## Testing the Integration

After setup, try these prompts with Claude Code:

1. **"List all my n8n workflows"**
   - Should show your FactsMind workflow

2. **"Show me the structure of my FactsMind workflow"**
   - Should display nodes and connections

3. **"What does the Generate Fact node do?"**
   - Should explain the node's purpose

4. **"Help me add error handling to my workflow"**
   - Should suggest modifications

5. **"Create a new test workflow that..."**
   - Should generate workflow JSON

## Configuration File Locations

- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux:** `~/.config/Claude/claude_desktop_config.json`

## Troubleshooting

### "MCP server not found"
- Verify Node.js is installed: `node --version`
- Try installing globally first: `npm install -g n8n-mcp`
- Then use `"command": "n8n-mcp"` instead of npx

### "Connection refused"
- Verify Tailscale is running on Windows
- Test API access: `curl http://100.122.207.23:5678/api/v1/workflows -H "X-N8N-API-KEY: YOUR_KEY"`

### "Invalid API key"
- Regenerate the API key in n8n (http://100.122.207.23:5678)
- Update the config file with the new key
- Restart Claude Code

## Security Notes

⚠️ **IMPORTANT:**
- The API key grants **full access** to your n8n instance
- Never commit `claude_desktop_config.json` to git
- Use read-only API keys if available (not yet supported by n8n)
- Consider creating a separate n8n user for Claude with limited permissions

## What Happens Next

Once configured, every Claude Code session will have:
- Access to your n8n workflow data
- Documentation for all 543 n8n nodes
- Ability to suggest workflow improvements
- Context-aware debugging assistance

The MCP server starts automatically when Claude Code launches and shuts down when you close it.
