# Nexus Project Overview

This document provides a comprehensive overview of the Nexus project, an AI-powered content automation platform. It is intended to be used as a reference for developers and AI assistants working on the project.

## Project Purpose and Architecture

Nexus is a self-contained automation workstation designed to generate, render, and publish short-form social media content using AI. It is built to run on a Raspberry Pi 4 and utilizes a microservices architecture orchestrated by Docker.

The core components of the Nexus platform are:

*   **n8n**: A workflow automation tool that acts as the central orchestrator for content generation and publishing.
*   **Python**: Used for the content rendering pipeline, leveraging the Pillow library for image manipulation.
*   **PostgreSQL**: The primary database for n8n and for tracking content generation and publishing events.
*   **AI Services**: The platform is designed to use a combination of AI services for text and image generation, including Claude, Groq, and Pexels.
*   **Docker**: All services are containerized using Docker and managed with Docker Compose.
*   **Monitoring**: The system includes Netdata for real-time monitoring and observability.

## Building and Running the Project

The project is currently in a pre-deployment phase, with the focus on setting up the hardware and base system. The following commands are intended for a system that has been provisioned according to the `QUICK_START.md` guide.

**Starting the Docker Stack:**

```bash
cd /srv/docker
sudo docker compose up -d
```

**Stopping the Docker Stack:**

```bash
cd /srv/docker
sudo docker compose down
```

**Viewing Service Logs:**

```bash
sudo docker compose logs -f <service-name>
```

## Development Conventions

The project has a set of development conventions that should be followed:

*   **Code Style**: Python code should be formatted with Black and linted with Ruff.
*   **Testing**: The project uses pytest for testing. All new features should be accompanied by tests.
*   **Continuous Integration**: A CI pipeline is configured to run on every push to the `main` branch, which runs the test suite.
*   **Branching**: Feature branches should be used for all new development, with pull requests to merge changes into `main`.
*   **Commits**: Commit messages should be clear and descriptive.

## Key Files and Directories

*   `README.md`: The main entry point for understanding the project.
*   `CLAUDE.md`: A detailed guide for AI assistants working on the project.
*   `IMPLEMENTATION_ROADMAP.md`: A phased plan for the project's development.
*   `QUICK_START.md`: A step-by-step guide for setting up the hardware and base system.
*   `infra/docker-compose.yml`: The Docker Compose file that defines the project's services.
*   `requirements.txt`: The Python dependencies for the project.
*   `src/`: This directory will contain the Python source code for the rendering pipeline and API clients (currently not implemented).
*   `tests/`: This directory contains the project's tests (currently placeholders).
*   `schemas/`: This directory contains JSON schemas for data validation (currently placeholders).
*   `workflows/`: This directory contains sample n8n workflows (currently placeholders).
