# AWS Microservice Architecture — Notes

These notes are based on handwritten diagrams covering the software delivery lifecycle, team roles, and AWS infrastructure for a microservices architecture.

> **Convention:** Content marked with *[Added]* was not in the original diagrams and has been added for completeness.

---

## 1. Software Delivery Lifecycle

### Three-Step Overview

```mermaid
flowchart LR
    S1["Step 1\nDevelop"] --> S2["Step 2\nContainerize"] --> S3["Step 3\nDeploy"]
```

### Step 1 — Develop (SDE)

Build a Spring application with test cases.

```mermaid
flowchart LR
    Dev["Developer\n(SDE)"] --> App["Spring Application"]
    App --> UT["Unit Tests"]
    App --> IT["Integration Tests"]
    App --- Redis
    App --- Kafka
    App --- DB["Database"]
```

- **Role:** SDE (Software Development Engineer)
- **Experience level:** 4 years
- **Application:** Spring Boot
- **Dependencies:** Redis, Kafka, DB
- **Testing:** Unit tests + Integration tests (TCs)

### Step 2 — Containerize

```mermaid
flowchart LR
    App["Spring Application"] --> Docker["Docker Image"]
```

- Package the application into a Docker container

### Step 3 — Deploy

#### Platform Engineer Responsibilities

```mermaid
flowchart TD
    PE["Platform Engineer"] --> IAC["Create Cloud Accounts\n(IaC - Terraform)"]
    PE --> CICD["Set up CI/CD Pipeline"]
    PE --> IMG["Build & Push Images"]

    IAC --> AWS["AWS"]
    IAC --> GCP["GCP"]
    IAC --> Azure["Azure"]

    AWS --> Prod["Production"]
    AWS --> PreProd["Pre-Prod"]
    AWS --> Test["Test"]
    AWS --> DevEnv["Dev"]

    CICD --> Jenkins["Jenkins"]
    CICD --> GHA["GitHub Actions"]
```

**CI/CD Flow (Platform Engineer):**

```mermaid
flowchart LR
    Commit["Dev Commits Code"] --> Build["Build is Generated"] --> Push["Image Pushed to\nContainer Repository"]
```

#### SRE Responsibilities

```mermaid
flowchart LR
    SRE["SRE\n(Site Reliability Engineer)"] --> Deploy["Deploy Application\non Cloud"]
```

- **SRE** = Site Reliability Engineer
- Deploys the application to the cloud environment
- *[Added]* Responsible for monitoring, incident response, and ensuring system reliability

### Roles Summary

| Role | Responsibility |
|------|---------------|
| SDE | Develop Spring application, write unit & integration tests |
| Platform Engineer | IaC (Terraform), CI/CD pipelines, build & push images |
| SRE | Deploy application on cloud, site reliability |

---

## 2. AWS Architecture

### Source Control & CI/CD Tools

```mermaid
flowchart LR
    subgraph "Source Control"
        GH["GitHub.com"]
        BB["Bitbucket"]
    end

    subgraph "CI/CD"
        Jenkins
        GHA["GitHub Actions"]
    end

    GH --> Jenkins
    GH --> GHA
    BB --> Jenkins
```

### Metering / Monitoring Tools

| Tool | Purpose |
|------|---------|
| Prometheus | Metrics collection |
| Datadog | Monitoring & analytics |
| Grafana | Dashboards & visualisation |

### AWS Dev Environment

```mermaid
flowchart TB
    subgraph AWS["AWS Dev Environment"]
        subgraph Compute
            EC2["EC2 Instances\n(CPU x3)\n8GB / 16GB storage"]
        end

        subgraph Database
            RDS["RDS\n(MySQL)"]
        end

        subgraph Messaging
            MSK["MSK\n(Managed Kafka)"]
        end

        subgraph Cache
            Redis
        end

        subgraph Container
            EKS["EKS\n(Kubernetes)"]
            ECR["ECR\n(Image Repository)"]
        end

        subgraph Networking
            APIGW["API Gateway"]
            VPC
            IAM
        end

        subgraph Monitoring
            CW["CloudWatch"]
            CT["CloudTrail"]
        end
    end
```

### AWS Services Summary

| Service | Category | Purpose |
|---------|----------|---------|
| EC2 | Compute | Application instances (8GB/16GB) |
| RDS (MySQL) | Database | Relational database |
| MSK | Messaging | Managed Streaming for Apache Kafka |
| Redis | Cache | In-memory caching |
| EKS | Container | Managed Kubernetes |
| ECR | Container | Docker image repository |
| API Gateway | Networking | API management & routing |
| VPC | Networking | Virtual Private Cloud |
| IAM | Security | Identity & Access Management |
| CloudWatch | Monitoring | Logs & metrics |
| CloudTrail | Monitoring | API activity audit trail |

---

## 3. Multi-AZ Deployment (Option 2)

### Load Balancer to Availability Zones

```mermaid
flowchart TD
    REQ["Request\n/user/{id}"] --> LB["Load Balancer\n(API Gateway)"]

    LB --> AZ1["us-east-1a\n(Default)"]
    LB -.->|"X"| AZ2["us-east-1b\n(Missing / Failover)"]
    LB --> AZ3["us-east-1c\n(Warm Standby)"]
```

| Availability Zone | Status |
|-------------------|--------|
| us-east-1a | Default — primary traffic |
| us-east-1b | Missing / down — failover scenario |
| us-east-1c | Warm standby |

- *[Added]* Multi-AZ deployment provides high availability and fault tolerance. If one AZ becomes unavailable, traffic is routed to the remaining healthy AZs.

---

## 4. API Gateway + EKS Cluster — Microservices Routing

```mermaid
flowchart LR
    REQ["Request"] --> APIGW["API Gateway"]
    APIGW --> EKS["EKS Cluster"]
    EKS --> A["svc-a"]
    EKS --> B["svc-b"]
    EKS --> C["svc-c"]
    EKS --> D["svc-d"]
```

- API Gateway acts as the single entry point
- Routes requests to the appropriate microservice within the EKS cluster
- *[Added]* Each service (svc-a, svc-b, svc-c, svc-d) runs as a separate deployment/pod in Kubernetes, enabling independent scaling and deployment

---

## 5. End-to-End Flow *[Added]*

This section connects all the pieces from the diagrams into a single end-to-end flow.

```mermaid
flowchart TD
    DEV["SDE\nDevelops Spring App"] -->|"commit"| GIT["GitHub / Bitbucket"]
    GIT -->|"trigger"| CI["CI/CD\n(Jenkins / GitHub Actions)"]
    CI -->|"build"| IMG["Docker Image"]
    IMG -->|"push"| ECR["ECR\n(Image Repository)"]
    ECR -->|"deploy"| EKS["EKS Cluster"]

    subgraph EKS_CLUSTER["EKS Cluster (Multi-AZ)"]
        SVC_A["svc-a"]
        SVC_B["svc-b"]
        SVC_C["svc-c"]
        SVC_D["svc-d"]
    end

    EKS --> EKS_CLUSTER

    CLIENT["Client Request"] --> APIGW["API Gateway\n(Load Balancer)"]
    APIGW --> EKS_CLUSTER

    EKS_CLUSTER --> RDS["RDS (MySQL)"]
    EKS_CLUSTER --> MSK["MSK (Kafka)"]
    EKS_CLUSTER --> REDIS["Redis"]

    CW["CloudWatch"] -.->|"monitor"| EKS_CLUSTER
    CT["CloudTrail"] -.->|"audit"| APIGW
```

---

## 6. Template Note

The original diagram references an **SL Template** at the bottom of the first page. This likely refers to a service-level or solution template used as a starting point for architecture design.
