# HMS Local Development Environment

> **🚀 Quick Start:** See [STARTUP_GUIDE.md](./STARTUP_GUIDE.md) for complete step-by-step instructions.

This repository contains the Docker Compose configuration for running the entire HMS microservices stack locally.

## Prerequisites

- Docker Desktop installed and running
- All HMS service repositories cloned as siblings to this repo

## Directory Structure

```
hms-development/
├── hms-local-dev-env/          # This repository
│   ├── docker-compose.yml
│   └── .env
├── hms-auth-bff/                # BFF service (scaffolded from template)
├── hms-onboarding-workflow/     # Workflow service (scaffolded from template)
└── hms-dashboard-projector/     # CQRS Projector (scaffolded from template)
```

## Setup Instructions

### 1. Clone All Repositories

```bash
mkdir hms-development
cd hms-development

# Clone the control panel (this repo)
git clone https://github.com/ruchithaab-byte/hms-local-dev-env.git
cd hms-local-dev-env

# Clone your service repositories (as siblings)
cd ..
git clone https://github.com/ruchithaab-byte/hms-auth-bff.git
git clone https://github.com/ruchithaab-byte/hms-onboarding-workflow.git
git clone https://github.com/ruchithaab-byte/hms-dashboard-projector.git
```

### 2. Configure Environment Variables

```bash
cd hms-local-dev-env
cp .env.example .env
# Edit .env and fill in your ScaleKit credentials
```

### 3. Start Everything

```bash
docker-compose up -d
```

This will:
- Start all infrastructure (Postgres, Redis, Kafka, Zookeeper, Debezium)
- Build Docker images for all HMS services
- Start all HMS microservices
- Connect everything via the `hms-network` Docker network

### 4. Check Status

```bash
docker-compose ps
```

### 5. View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f hms-auth-bff
```

## Daily Developer Workflow

### Making Code Changes

1. Make your code changes in the service repository (e.g., `hms-auth-bff`)
2. Rebuild and restart just that service:
   ```bash
   cd hms-local-dev-env
   docker-compose up -d --build hms-auth-bff
   ```

### Stopping Everything

```bash
docker-compose down
```

### Stopping and Removing Volumes

```bash
docker-compose down -v
```

## Service Discovery

Services communicate using Docker DNS names:

- **Postgres**: `postgres:5432`
- **Redis**: `redis:6379`
- **Kafka**: `kafka:9092`
- **BFF Service**: `hms-auth-bff:8080`
- **Workflow Service**: `hms-onboarding-workflow:8080`
- **Projector Service**: `hms-dashboard-projector:8080`

## Port Mappings

- **Postgres**: `localhost:5432`
- **Redis**: `localhost:6379`
- **Kafka**: `localhost:9092`
- **Debezium Connect**: `localhost:8083`
- **BFF Service**: `localhost:8080`

## Troubleshooting

### Services won't start

Check logs:
```bash
docker-compose logs <service-name>
```

### Rebuild everything from scratch

```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Check network connectivity

```bash
docker network inspect hms-local-dev-env_hms-network
```

