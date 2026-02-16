# AWS Microservice Architecture — Demo Project

This project demonstrates a complete end-to-end microservice architecture on AWS, covering application development, containerization, CI/CD pipelines, infrastructure-as-code, Kubernetes deployment, and monitoring. It is based on the handwritten architecture diagrams (`1.jpg`, `2.jpg`) and the accompanying notes (`aws_microservice_architecture.md`).

> **Purpose**: This is a demonstration/reference project. The application code is intentionally simple, but the infrastructure, deployment pipeline, and monitoring setup are comprehensive and follow production best practices.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Directory Structure](#directory-structure)
3. [Application Layer](#application-layer)
4. [Platform Layer](#platform-layer)
5. [CI/CD Pipeline](#cicd-pipeline)
6. [Infrastructure (Terraform)](#infrastructure-terraform)
7. [Kubernetes Deployment](#kubernetes-deployment)
8. [Monitoring (Prometheus + Grafana)](#monitoring-prometheus--grafana)
9. [Environments](#environments)
10. [Team Roles](#team-roles)
11. [Deployment Guide](#deployment-guide)
12. [Architecture Decisions](#architecture-decisions)

---

## Architecture Overview

```
Client Request
      │
      ▼
┌─────────────┐
│ API Gateway │  (AWS API Gateway / Load Balancer)
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────────┐
│           EKS Cluster (Multi-AZ)         │
│  ┌───────┐ ┌───────┐ ┌───────┐ ┌──────┐ │
│  │ svc-a │ │ svc-b │ │ svc-c │ │svc-d │ │
│  │ User  │ │ Order │ │Product│ │Notif │ │
│  └───┬───┘ └───┬───┘ └───┬───┘ └──┬───┘ │
└──────┼─────────┼─────────┼────────┼──────┘
       │         │         │        │
       ▼         ▼         ▼        ▼
  ┌────────┐ ┌───────┐ ┌──────────────────┐
  │  RDS   │ │ Redis │ │ MSK (Kafka)      │
  │ MySQL  │ │ Cache │ │ Event Streaming  │
  └────────┘ └───────┘ └──────────────────┘
```

**End-to-End Flow:**

1. **SDE** develops a Spring Boot application with unit and integration tests
2. **Containerize** the application into Docker images
3. **Platform Engineer** sets up AWS infrastructure via Terraform (IaC) and CI/CD pipelines
4. **CI/CD** (GitHub Actions / Jenkins) builds, tests, and pushes Docker images to ECR
5. **SRE** deploys the application to EKS on the cloud
6. **Monitoring** via Prometheus + Grafana + CloudWatch ensures observability

**Multi-AZ Deployment:**

| Availability Zone | Role |
|---|---|
| us-east-1a | Primary traffic |
| us-east-1b | Failover |
| us-east-1c | Warm standby |

---

## Directory Structure

```
solution/
├── README.md                          # This file
├── 1.jpg, 2.jpg                       # Original handwritten diagrams
├── aws_microservice_architecture.md   # Diagram transcription notes
│
├── application/                       # Application code (SDE responsibility)
│   ├── .github/workflows/ci-cd.yml    # GitHub Actions pipeline
│   ├── Jenkinsfile                    # Jenkins pipeline (alternative)
│   ├── svc-a/                         # User Service (full implementation)
│   │   ├── pom.xml
│   │   ├── Dockerfile
│   │   └── src/
│   │       ├── main/java/com/demo/svca/
│   │       │   ├── SvcAApplication.java
│   │       │   ├── controller/UserController.java
│   │       │   ├── service/UserService.java
│   │       │   ├── repository/UserRepository.java
│   │       │   ├── model/User.java
│   │       │   └── config/{RedisConfig,KafkaConfig}.java
│   │       ├── main/resources/application.yml
│   │       └── test/
│   │           ├── java/.../service/UserServiceTest.java
│   │           ├── java/.../controller/UserControllerIntegrationTest.java
│   │           └── resources/application.yml
│   ├── svc-b/                         # Order Service (skeleton)
│   ├── svc-c/                         # Product Service (skeleton)
│   └── svc-d/                         # Notification Service (skeleton)
│
└── platform/                          # Infrastructure (Platform Eng / SRE)
    ├── terraform/
    │   ├── modules/                   # Reusable Terraform modules
    │   │   ├── vpc/                   # VPC, subnets, NAT, IGW
    │   │   ├── eks/                   # EKS cluster + node groups
    │   │   ├── ecr/                   # Container image repositories
    │   │   ├── rds/                   # MySQL database (Multi-AZ)
    │   │   ├── msk/                   # Managed Kafka
    │   │   ├── elasticache/           # Redis cache
    │   │   ├── api-gateway/           # API Gateway + VPC link
    │   │   ├── iam/                   # IAM roles (EKS, IRSA, CI/CD)
    │   │   ├── cloudwatch/            # Logs, alarms, dashboard
    │   │   └── cloudtrail/            # Audit trail + S3 storage
    │   └── environments/              # Per-environment configurations
    │       ├── dev/
    │       ├── test/
    │       ├── pre-prod/
    │       └── production/
    ├── kubernetes/                     # K8s manifests
    │   ├── base/                      # Shared resources
    │   │   ├── namespace.yml
    │   │   ├── configmap.yml
    │   │   ├── secrets.yml
    │   │   ├── ingress.yml
    │   │   └── network-policy.yml
    │   ├── svc-a/                     # Per-service: deployment, service, HPA
    │   ├── svc-b/
    │   ├── svc-c/
    │   └── svc-d/
    └── monitoring/
        ├── prometheus/
        │   ├── prometheus-values.yml  # Helm values for kube-prometheus-stack
        │   ├── alerting-rules.yml     # PrometheusRule CRD
        │   └── service-monitor.yml    # ServiceMonitor CRD
        └── grafana/
            ├── grafana-values.yml     # Helm values for Grafana
            └── dashboards/
                └── microservices-overview.json
```

---

## Application Layer

### svc-a (User Service) — Full Implementation

The primary demo service with all dependencies wired up:

| Component | Description |
|---|---|
| **REST API** | `GET/POST/DELETE /api/users/{id}` |
| **Database** | MySQL via Spring Data JPA |
| **Cache** | Redis with `@Cacheable`/`@CacheEvict` annotations |
| **Messaging** | Kafka producer for `user-events` topic |
| **Metrics** | Spring Actuator + Micrometer Prometheus endpoint |
| **Tests** | Unit tests (Mockito) + Integration tests (MockMvc) |

**Key endpoints:**
- `GET /api/users/{id}` — Fetch user (cached in Redis)
- `GET /api/users` — List all users
- `POST /api/users` — Create user (publishes Kafka event, evicts cache)
- `DELETE /api/users/{id}` — Delete user (publishes Kafka event, evicts cache)
- `GET /actuator/prometheus` — Prometheus metrics scrape endpoint
- `GET /actuator/health` — Health check (used by K8s probes)

### svc-b, svc-c, svc-d — Skeleton Services

Minimal Spring Boot applications with a single GET endpoint each:

| Service | Port | Endpoint | Description |
|---|---|---|---|
| svc-b | 8081 | `GET /api/orders` | Order Service |
| svc-c | 8082 | `GET /api/products` | Product Service |
| svc-d | 8083 | `GET /api/notifications` | Notification Service |

All services expose Prometheus metrics via `/actuator/prometheus` and health checks via `/actuator/health`.

### Building Locally

```bash
cd application/svc-a
mvn clean package          # Build JAR
mvn verify                 # Run tests
docker build -t svc-a .    # Build Docker image
```

---

## CI/CD Pipeline

Two CI/CD options are provided:

### GitHub Actions (`.github/workflows/ci-cd.yml`)

Three-job pipeline triggered on push to `main`:

1. **Test** — Runs `mvn verify` for all 4 services in parallel (matrix strategy)
2. **Build & Push** — Builds Docker images and pushes to ECR (only on `main` branch)
3. **Deploy** — Updates EKS deployments with new images via `kubectl set image`

Requires GitHub Secrets:
- `AWS_ROLE_ARN` — IAM role for OIDC authentication
- `AWS_REGION` — AWS region (default: `us-east-1`)
- `ECR_REGISTRY` — ECR registry URL
- `EKS_CLUSTER_NAME` — EKS cluster name

### Jenkins (`Jenkinsfile`)

Four-stage pipeline with parallel builds:

1. **Build** — Parallel Maven builds for all services
2. **Test** — Parallel test execution with JUnit report collection
3. **Docker Build & Push** — Parallel image builds and ECR push
4. **Deploy** — Sequential EKS deployment via `kubectl`

---

## Infrastructure (Terraform)

### Modules

10 reusable Terraform modules under `platform/terraform/modules/`:

| Module | AWS Service | Key Resources |
|---|---|---|
| **vpc** | VPC | VPC, 3 AZ subnets (public + private), NAT Gateway, Internet Gateway, route tables |
| **eks** | EKS | EKS cluster, managed node group, OIDC provider (IRSA) |
| **ecr** | ECR | Repositories for svc-a through svc-d with lifecycle policies |
| **rds** | RDS | MySQL 8.0 instance, DB subnet group, security group |
| **msk** | MSK | Managed Kafka cluster, 3 brokers across AZs |
| **elasticache** | ElastiCache | Redis replication group, subnet group |
| **api-gateway** | API Gateway | REST API, VPC link to EKS |
| **iam** | IAM | Roles for EKS nodes, service accounts (IRSA), CI/CD |
| **cloudwatch** | CloudWatch | Log groups, CPU/memory alarms, dashboard |
| **cloudtrail** | CloudTrail | Trail, S3 bucket (versioned, encrypted), CloudWatch integration |

### Deploying Infrastructure

```bash
cd platform/terraform/environments/dev

terraform init        # Initialize backend + download providers
terraform plan        # Preview changes
terraform apply       # Apply infrastructure
```

State is stored in S3 with DynamoDB locking for concurrent access safety.

---

## Kubernetes Deployment

### Base Resources

| Resource | Purpose |
|---|---|
| `namespace.yml` | Creates `microservices` namespace |
| `configmap.yml` | Shared environment variables (DB_HOST, REDIS_HOST, KAFKA_BOOTSTRAP_SERVERS) |
| `secrets.yml` | Database credentials (template — replace base64 values) |
| `ingress.yml` | NGINX ingress routing `/api/users` to svc-a, `/api/orders` to svc-b, etc. |
| `network-policy.yml` | Restricts ingress to only the ingress controller |

### Per-Service Resources

Each service has:
- **Deployment** — 2 replicas, resource requests/limits, liveness/readiness probes
- **Service** — ClusterIP on port 80 targeting the container port
- **HPA** — Autoscaler: min 2, max 5 replicas, target 70% CPU

### Deploying to EKS

```bash
# Apply base resources
kubectl apply -f platform/kubernetes/base/

# Apply per-service resources
kubectl apply -f platform/kubernetes/svc-a/
kubectl apply -f platform/kubernetes/svc-b/
kubectl apply -f platform/kubernetes/svc-c/
kubectl apply -f platform/kubernetes/svc-d/
```

---

## Monitoring (Prometheus + Grafana)

### Prometheus

Deployed via the `kube-prometheus-stack` Helm chart:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -f platform/monitoring/prometheus/prometheus-values.yml \
  -n monitoring --create-namespace
```

**Components:**
- **Scrape configs** — Discovers Spring Boot actuator endpoints in the `microservices` namespace
- **ServiceMonitor** — CRD-based service discovery for `/actuator/prometheus`
- **Alerting rules** — 6 alerts: HighCpuUsage, HighMemoryUsage, PodCrashLooping, HighErrorRate, HighLatency, ServiceDown
- **Retention** — 15 days, 50Gi storage

### Grafana

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana \
  -f platform/monitoring/grafana/grafana-values.yml \
  -n monitoring
```

**Dashboard panels (microservices-overview.json):**

| Row | Panels |
|---|---|
| HTTP Metrics | Request Rate (req/s), Error Rate (5xx %), Latency (p50/p95/p99) |
| JVM Metrics | Heap Memory Usage, JVM Threads (live/peak) |
| Pod Resources | Pod CPU Usage (cores), Pod Memory Usage |
| Kafka & Redis | Kafka Consumer Lag, Redis Cache Hit/Miss Ratio |

### CloudWatch

Terraform-managed AWS-native monitoring:
- Log groups for application and EKS cluster logs
- Metric alarms for EKS CPU/memory and RDS CPU
- Dashboard with EKS CPU, memory, pod count, and network widgets

### CloudTrail

Audit logging for all AWS API calls:
- Multi-region trail
- S3 bucket with versioning, KMS encryption, lifecycle policies (IA after 30d, Glacier after 60d, expire after 90d)
- CloudWatch Logs integration

---

## Environments

Four environments with progressively larger resource sizing:

| Resource | dev | test | pre-prod | production |
|---|---|---|---|---|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 | 10.3.0.0/16 |
| Availability Zones | 2 | 2 | 3 | 3 |
| EKS Nodes | t3.medium x2 | t3.medium x2 | t3.large x3 | t3.xlarge x3-6 (autoscale) |
| RDS | db.t3.micro, 20GB | db.t3.micro, 20GB | db.t3.medium, 50GB, Multi-AZ | db.r5.large, 100GB, Multi-AZ |
| MSK | kafka.t3.small x2 | kafka.t3.small x2 | kafka.m5.large x3 | kafka.m5.large x3 |
| Redis | cache.t3.micro x1 | cache.t3.micro x1 | cache.t3.small x2 | cache.r5.large x3 |

---

## Team Roles

| Role | Responsibility | Relevant Code |
|---|---|---|
| **SDE** (4+ yrs) | Develop Spring Boot application, write tests | `application/` |
| **Platform Engineer** | IaC (Terraform), CI/CD pipelines, build images | `platform/terraform/`, `.github/workflows/`, `Jenkinsfile` |
| **SRE** | Deploy to cloud, monitoring, incident response | `platform/kubernetes/`, `platform/monitoring/` |

---

## Deployment Guide

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- kubectl configured for EKS
- Helm 3
- Java 17 + Maven 3.9
- Docker

### Step-by-Step

```bash
# 1. Provision infrastructure
cd platform/terraform/environments/dev
terraform init && terraform apply

# 2. Configure kubectl
aws eks update-kubeconfig --name demo-dev-eks --region us-east-1

# 3. Deploy monitoring stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  -f ../../monitoring/prometheus/prometheus-values.yml -n monitoring --create-namespace
kubectl apply -f ../../monitoring/prometheus/alerting-rules.yml
kubectl apply -f ../../monitoring/prometheus/service-monitor.yml
helm install grafana grafana/grafana \
  -f ../../monitoring/grafana/grafana-values.yml -n monitoring

# 4. Deploy Kubernetes base resources
kubectl apply -f ../../kubernetes/base/

# 5. Build and push application images
cd ../../../../application/svc-a
mvn clean package -DskipTests
docker build -t <ECR_REGISTRY>/svc-a:latest .
docker push <ECR_REGISTRY>/svc-a:latest
# Repeat for svc-b, svc-c, svc-d

# 6. Deploy services
kubectl apply -f ../../platform/kubernetes/svc-a/
kubectl apply -f ../../platform/kubernetes/svc-b/
kubectl apply -f ../../platform/kubernetes/svc-c/
kubectl apply -f ../../platform/kubernetes/svc-d/

# 7. Verify
kubectl get pods -n microservices
kubectl get svc -n microservices
```

---

## Architecture Decisions

| Decision | Rationale |
|---|---|
| **Spring Boot 3.2 + Java 17** | LTS version with modern features, widely adopted |
| **EKS over ECS** | Better portability, richer ecosystem, matches diagram |
| **Terraform modules** | Reusable across environments, DRY principle |
| **Multi-AZ** | High availability and fault tolerance |
| **Redis caching** | Reduces database load for frequent reads |
| **Kafka (MSK)** | Async event-driven communication between services |
| **Prometheus + Grafana** | Industry standard for Kubernetes monitoring |
| **CloudWatch + CloudTrail** | AWS-native observability and audit compliance |
| **GitHub Actions + Jenkins** | Two CI/CD options for flexibility |
| **Constructor injection** | Testable, immutable dependencies (Spring best practice) |
| **HPA per service** | Independent scaling based on per-service load |
| **Network policies** | Zero-trust networking within the cluster |
