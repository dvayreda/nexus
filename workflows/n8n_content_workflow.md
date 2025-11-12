# Nexus n8n Workflow for Content Generation

## Overview
This workflow generates carousel content using AI APIs, selects images via Pexels, and renders carousels using a Python script.

## Workflow Steps
1. **Schedule Trigger**: Cron node for daily execution (e.g., 9 AM)
2. **Content Generation**:
   - HTTP Request to Claude/Groq API for text generation (5 facts/slides)
   - HTTP Request to Pexels API for image search based on content
3. **Data Processing**: Function node to format content into carousel manifest JSON
4. **Manifest Storage**: Save manifest to /srv/outputs/manifests/
5. **Python Rendering**: Execute Command node to run carousel_renderer.py with manifest
6. **Storage**: Rendered images saved to /srv/outputs/carousels/
7. **Logging**: Store metadata in PostgreSQL

## Required n8n Nodes
- Schedule Trigger
- HTTP Request (x2 for APIs)
- Function (for data processing)
- Execute Command (to run Python script)
- Postgres (for logging)

## Environment Variables
Set in n8n credentials: ANTHROPIC_API_KEY, GROQ_API_KEY, PEXELS_API_KEY

## Python Rendering Integration
- Mount /srv/projects/nexus/src/rendering/ in n8n container
- Execute: python /data/workflows/src/rendering/carousel_renderer.py --manifest /srv/outputs/manifests/latest.json
- Modify carousel_renderer.py to accept --manifest argument for input

Note: Ensure Python dependencies (Pillow) are available in the execution environment.