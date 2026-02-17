# CloudWatch Monitoring and Observability: Complete Guide for Interviews

## Overview

This guide covers the monitoring and observability architecture in the `aws_solution` microservices platform, focusing on how CloudWatch integrates with the broader monitoring stack to achieve production-grade observability.

The solution implements a **dual monitoring stack**: Prometheus/Grafana for Kubernetes and application metrics, and AWS CloudWatch for managed service metrics, logs, and audit trails. The best practice is to unify both stacks through **Grafana as a single pane of glass**, eliminating the need for engineers to context-switch between tools.

**Why This Matters for Interviews**:
- Demonstrates understanding of the **Three Pillars of Observability** (metrics, logs, traces)
- Shows knowledge of AWS-native vs open-source monitoring trade-offs
- Reveals experience designing production monitoring for microservices
- Tests ability to reason about alert fatigue, cardinality, and operational maturity

**Key Themes**:
- CloudWatch handles AWS-managed service monitoring (RDS, API Gateway, EKS ContainerInsights)
- Prometheus handles application and Kubernetes workload metrics
- Grafana unifies both datasources into correlated dashboards
- Monitoring without actionable alerting is incomplete

---

## Part I: Current Monitoring Architecture

### Dual Stack Design

```
                    ┌─────────────────────────────┐
                    │     Grafana (Single Pane     │
                    │       of Glass)              │
                    └──────┬──────────────┬────────┘
                           │              │
              ┌────────────┘              └────────────┐
              ▼                                        ▼
    ┌──────────────────┐                    ┌──────────────────┐
    │    Prometheus     │                    │   CloudWatch     │
    │  (K8s + App)     │                    │  (AWS Services)  │
    └──────────────────┘                    └──────────────────┘
    - HTTP request metrics                  - EKS ContainerInsights
    - JVM metrics (heap, GC, threads)       - RDS metrics (CPU, IOPS)
    - Custom business metrics               - API Gateway (latency, errors)
    - Pod resource usage                    - CloudTrail audit logs
    - Kafka consumer lag                    - EKS control plane logs
    - Redis cache hit/miss                  - Application log groups
```

### Why Two Stacks?

| Concern | Prometheus | CloudWatch |
|---------|-----------|------------|
| **Scope** | App + K8s workloads | AWS managed services |
| **Scrape model** | Pull-based (15s interval) | Push-based (AWS publishes) |
| **Query language** | PromQL (powerful, flexible) | CloudWatch Metrics Insights |
| **Cost** | Self-hosted (compute cost only) | Pay per metric/log/alarm |
| **Retention** | 15 days (configurable) | Up to 15 months (standard) |
| **AWS service visibility** | None (RDS, API GW invisible) | Full native integration |

Neither stack alone is sufficient. Prometheus cannot see RDS internals or API Gateway throttling. CloudWatch cannot efficiently scrape custom application metrics from Spring Boot Actuator at 15-second intervals.

---

## Part II: CloudWatch Components in This Solution

### 1. Log Groups

Three log groups are provisioned via Terraform:

**Application Logs** (`/{project}/{environment}/application`)
- Captures stdout/stderr from all microservice pods
- Retention: 30 days (configurable)
- Use case: Application error investigation, request tracing

**EKS Cluster Logs** (`/aws/eks/{cluster}/cluster`)
- Captures Kubernetes control plane logs
- Log types: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`
- Retention: 30 days
- Use case: Investigating API server errors, audit trail for kubectl operations, scheduler decisions

```terraform
# platform/terraform/modules/eks/main.tf
enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
```

**API Gateway Logs** (`/aws/apigateway/{project}-{environment}`)
- Captures request/response metadata, latency, errors
- Retention: 14 days
- Use case: Debugging API Gateway routing, throttling analysis

```terraform
# platform/terraform/modules/api-gateway/main.tf
access_log_settings {
  destination_arn = aws_cloudwatch_log_group.api_gw.arn
}

settings {
  throttling_burst_limit = 500
  throttling_rate_limit  = 1000
  metrics_enabled        = true
  logging_level          = "INFO"
}
```

### 2. CloudWatch Alarms

Three alarms are defined, all using the **3 evaluation periods x 300 seconds** pattern to prevent false positives:

| Alarm | Namespace | Metric | Threshold | Condition |
|-------|-----------|--------|-----------|-----------|
| EKS CPU High | ContainerInsights | `node_cpu_utilization` | 80% | Average over 5min, 3 consecutive |
| EKS Memory High | ContainerInsights | `node_memory_utilization` | 80% | Average over 5min, 3 consecutive |
| RDS CPU High | AWS/RDS | `CPUUtilization` | 80% | Average over 5min, 3 consecutive |

```terraform
# platform/terraform/modules/cloudwatch/main.tf
resource "aws_cloudwatch_metric_alarm" "eks_cpu" {
  alarm_name          = "${var.project}-${var.environment}-eks-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold  # default: 80

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
}
```

### 3. CloudWatch Dashboard

A dashboard with 4 widgets provides a high-level view of EKS cluster health:

| Widget | Metric | Position |
|--------|--------|----------|
| EKS CPU Utilization | `ContainerInsights/node_cpu_utilization` | Top-left |
| EKS Memory Utilization | `ContainerInsights/node_memory_utilization` | Top-right |
| EKS Pod Count | `ContainerInsights/pod_number_of_running` | Bottom-left |
| EKS Network | `ContainerInsights/node_network_total_bytes` | Bottom-right |

All widgets use 300-second periods with average statistics, dimensioned by `ClusterName`.

### 4. CloudTrail (Audit Logging)

CloudTrail provides API-level audit logging for all AWS actions:

```terraform
# platform/terraform/modules/cloudtrail/main.tf
resource "aws_cloudtrail" "main" {
  name                          = "${var.project}-${var.environment}-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
}
```

**S3 Lifecycle Policy**:
- 0-30 days: STANDARD (hot)
- 30-60 days: STANDARD_IA (infrequent access)
- 60+ days: GLACIER (archive)
- Expiration: 90 days

**Security**: Bucket versioning enabled, KMS encryption, all public access blocked.

---

## Part III: Prometheus + Grafana Stack

### Prometheus Configuration

**Scrape targets** (defined in `platform/monitoring/prometheus/prometheus-values.yml`):
1. **Spring Boot Actuator**: All pods in `microservices` namespace at `/actuator/prometheus`
2. **Static targets**: `svc-a:8080`, `svc-b:8081`, `svc-c:8082`, `svc-d:8083`
3. **Kubernetes SD**: Label-based pod discovery with `prometheus.io/scrape: "true"`

**ServiceMonitor** (`platform/monitoring/prometheus/service-monitor.yml`):
- Selects services with label `monitoring: "true"` and app in `[svc-a, svc-b, svc-c, svc-d]`
- Scrapes `/actuator/prometheus` every 15 seconds
- Drops high-cardinality `jvm_gc_pause_seconds.*` metrics via metric relabeling

### Alerting Rules

Six alerts defined in `platform/monitoring/prometheus/alerting-rules.yml`:

**Infrastructure Alerts**:

| Alert | PromQL Condition | Duration | Severity |
|-------|-----------------|----------|----------|
| HighCpuUsage | Container CPU > 80% of limits | 5min | warning |
| HighMemoryUsage | Container memory > 85% of limits | 5min | warning |
| PodCrashLooping | > 3 restarts in 1 hour | immediate | critical |
| ServiceDown | `up == 0` for any service | 1min | critical |

**Application Alerts**:

| Alert | PromQL Condition | Duration | Severity |
|-------|-----------------|----------|----------|
| HighErrorRate | > 5% 5xx responses | 5min | critical |
| HighLatency | p99 latency > 2 seconds | 5min | warning |

All alerts include runbook URLs and team assignments in annotations.

### Grafana Dashboard

The `microservices-overview.json` dashboard has 4 rows:

1. **HTTP Metrics**: Request rate, error rate (5xx %), latency (p50/p95/p99)
2. **JVM Metrics**: Heap memory usage, thread counts
3. **Pod Resources**: CPU cores, memory bytes per pod
4. **Kafka & Redis**: Consumer lag by topic, cache hit/miss ratio

### Application Instrumentation

All four services include Spring Boot Actuator + Micrometer Prometheus:

```xml
<!-- application/svc-a/pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  endpoint:
    health:
      show-details: always
  metrics:
    tags:
      application: ${spring.application.name}
```

Kubernetes probes use these endpoints:

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 5
  failureThreshold: 3
```

---

## Part IV: Grafana as Single Pane of Glass (Gap + Best Practice Fix)

### The Problem

Currently, Grafana only has Prometheus as a datasource:

```yaml
# platform/monitoring/grafana/grafana-values.yml (current)
datasources:
  datasources.yaml:
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
```

This means CloudWatch metrics (RDS, API Gateway, EKS ContainerInsights) are **only visible via the AWS Console**. Engineers must context-switch between tools, breaking the unified observability experience.

### The Fix: Add CloudWatch Datasource

Grafana has a **built-in CloudWatch datasource** (no plugin needed). Add it alongside Prometheus:

```yaml
# platform/monitoring/grafana/grafana-values.yml (recommended)
datasources:
  datasources.yaml:
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
        isDefault: true
      - name: CloudWatch
        type: cloudwatch
        jsonData:
          authType: default  # Uses EKS pod IAM role via IRSA
          defaultRegion: ap-southeast-1
```

**IAM Requirement**: The Grafana pod needs an IAM role (via IRSA — IAM Roles for Service Accounts) with the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:DescribeAlarmsForMetric",
        "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetInsightRuleReport",
        "logs:DescribeLogGroups",
        "logs:GetLogGroupFields",
        "logs:StartQuery",
        "logs:StopQuery",
        "logs:GetQueryResults",
        "logs:GetLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

### What This Enables

With both datasources, a single Grafana dashboard can correlate:

| Panel | Datasource | Query Example |
|-------|-----------|---------------|
| API Gateway latency spike | CloudWatch | `AWS/ApiGateway` → `Latency` (p99) |
| Backend error rate | Prometheus | `rate(http_server_requests_seconds_count{status=~"5.."}[5m])` |
| RDS CPU during the spike | CloudWatch | `AWS/RDS` → `CPUUtilization` |
| Kafka consumer lag | Prometheus | `kafka_consumer_fetch_manager_records_lag` |
| Pod autoscaling events | CloudWatch | `ContainerInsights` → `pod_number_of_running` |

This correlation is critical for root cause analysis — for example, an API Gateway latency spike may be caused by RDS CPU saturation, which is only visible if both metrics are on the same dashboard with aligned time axes.

### Best Practice: Which Metrics Go Where

| Metric Source | Display Via | Reason |
|---|---|---|
| App metrics (HTTP, JVM, custom) | Grafana ← Prometheus | Fine-grained, 15s scrape, PromQL is powerful |
| EKS node CPU/memory, pod count | Grafana ← CloudWatch (ContainerInsights) | AWS-managed, no Prometheus config needed |
| RDS (CPU, connections, IOPS) | Grafana ← CloudWatch (AWS/RDS) | Only available via CloudWatch |
| API Gateway (latency, 4xx/5xx) | Grafana ← CloudWatch (AWS/ApiGateway) | Only available via CloudWatch |
| CloudTrail audit events | CloudWatch Logs Insights or Grafana ← CloudWatch Logs | Query-based, not real-time dashboard |

---

## Part V: Critical Gaps and Recommended Fixes

### Gap 1: SNS Topic Not Created (HIGH Priority)

**Problem**: CloudWatch alarms reference `var.alarm_sns_topic_arn` for notifications, but no SNS topic is created anywhere in the Terraform code. Alarms fire silently.

**Fix**: Create an SNS module:

```terraform
# platform/terraform/modules/sns/main.tf
resource "aws_sns_topic" "alerts" {
  name = "${var.project}-${var.environment}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# For Slack integration via Lambda
resource "aws_sns_topic_subscription" "lambda_slack" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}
```

Then pass the SNS topic ARN to the CloudWatch module:

```terraform
# platform/terraform/environments/dev/main.tf
module "cloudwatch" {
  source              = "../../modules/cloudwatch"
  alarm_sns_topic_arn = module.sns.topic_arn
  # ...
}
```

### Gap 2: No Distributed Tracing — X-Ray (CRITICAL Priority)

**Problem**: The solution has metrics and logs but **no traces**. Without distributed tracing, you cannot follow a single request across svc-a → svc-b → svc-c → RDS.

**Fix — Application side**:

Add X-Ray SDK to each service:

```xml
<!-- pom.xml -->
<dependency>
    <groupId>com.amazonaws</groupId>
    <artifactId>aws-xray-recorder-sdk-spring</artifactId>
    <version>2.14.0</version>
</dependency>
<dependency>
    <groupId>com.amazonaws</groupId>
    <artifactId>aws-xray-recorder-sdk-aws-sdk-v2</artifactId>
    <version>2.14.0</version>
</dependency>
```

Add X-Ray servlet filter:

```java
@Configuration
public class XRayConfig {

    @Bean
    public Filter tracingFilter() {
        return new AWSXRayServletFilter("svc-a");
    }
}
```

**Fix — Infrastructure side**:

Deploy X-Ray daemon as a DaemonSet on EKS:

```yaml
# platform/kubernetes/xray-daemon/daemonset.yml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: xray-daemon
  namespace: microservices
spec:
  selector:
    matchLabels:
      app: xray-daemon
  template:
    metadata:
      labels:
        app: xray-daemon
    spec:
      containers:
        - name: xray-daemon
          image: public.ecr.aws/xray/aws-xray-daemon:latest
          ports:
            - containerPort: 2000
              protocol: UDP
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
```

**Alternative (Modern approach)**: Use **AWS Distro for OpenTelemetry (ADOT)** instead of X-Ray SDK directly. ADOT supports both X-Ray and Prometheus, reducing instrumentation overhead. This is the AWS-recommended approach for new workloads as of 2025.

### Gap 3: ServiceMonitor Labels Missing (HIGH Priority)

**Problem**: The Prometheus ServiceMonitor selects services with label `monitoring: "true"`, but Kubernetes Service manifests don't have this label. ServiceMonitor-based discovery silently fails; only static scrape configs work.

**Fix**: Add the label to each service:

```yaml
# platform/kubernetes/svc-a/service.yml
apiVersion: v1
kind: Service
metadata:
  name: svc-a
  namespace: microservices
  labels:
    app: svc-a
    monitoring: "true"    # Add this line
spec:
  # ...
```

### Gap 4: No Alertmanager Routing (HIGH Priority)

**Problem**: Alertmanager is enabled in the Prometheus Helm chart, but no routing configuration exists. Prometheus alerts are generated but never delivered to engineers.

**Fix**: Create an AlertmanagerConfig:

```yaml
# platform/monitoring/prometheus/alertmanager-config.yml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: microservices-alerts
  namespace: monitoring
spec:
  route:
    groupBy: ['alertname', 'namespace']
    groupWait: 30s
    groupInterval: 5m
    repeatInterval: 4h
    receiver: 'slack-critical'
    routes:
      - match:
          severity: critical
        receiver: 'slack-critical'
      - match:
          severity: warning
        receiver: 'slack-warning'
  receivers:
    - name: 'slack-critical'
      slackConfigs:
        - channel: '#alerts-critical'
          sendResolved: true
          title: '[{{ .Status | toUpper }}] {{ .CommonLabels.alertname }}'
          text: '{{ range .Alerts }}*{{ .Annotations.summary }}*\n{{ .Annotations.description }}\n{{ end }}'
    - name: 'slack-warning'
      slackConfigs:
        - channel: '#alerts-warning'
          sendResolved: true
```

### Gap 5: No Structured Logging (MEDIUM Priority)

**Problem**: Application logs are unstructured text. CloudWatch Logs Insights queries are difficult without structured fields. Log correlation across services is impossible without trace/correlation IDs.

**Fix**: Spring Boot 3.4+ has built-in structured logging support:

```yaml
# application.yml
logging:
  structured:
    format:
      console: ecs    # Elastic Common Schema (JSON)
  level:
    root: INFO
    com.demo: DEBUG
```

Output becomes:

```json
{
  "@timestamp": "2026-02-17T10:30:00.000Z",
  "log.level": "INFO",
  "message": "User created successfully",
  "service.name": "svc-a",
  "trace.id": "abc123",
  "span.id": "def456"
}
```

This enables powerful CloudWatch Logs Insights queries:

```sql
fields @timestamp, service.name, message
| filter log.level = "ERROR"
| filter service.name = "svc-a"
| sort @timestamp desc
| limit 50
```

### Gap 6: No Custom Business Metrics (MEDIUM Priority)

**Problem**: Only infrastructure metrics are collected. No visibility into business outcomes (orders processed, payment failures, user registrations).

**Fix**: Use Micrometer (already included) to add custom metrics:

```java
@Service
public class OrderService {

    private final Counter orderCounter;
    private final Timer orderProcessingTimer;
    private final MeterRegistry meterRegistry;

    public OrderService(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        this.orderCounter = Counter.builder("business.orders.created")
            .description("Total orders created")
            .tag("service", "svc-a")
            .register(meterRegistry);
        this.orderProcessingTimer = Timer.builder("business.orders.processing_time")
            .description("Order processing duration")
            .tag("service", "svc-a")
            .register(meterRegistry);
    }

    public Order createOrder(OrderRequest request) {
        return orderProcessingTimer.record(() -> {
            Order order = processOrder(request);
            orderCounter.increment();
            return order;
        });
    }
}
```

These metrics are automatically scraped by Prometheus via the `/actuator/prometheus` endpoint.

### Gap 7: No Prometheus HA / Remote Storage (MEDIUM Priority)

**Problem**: Single Prometheus instance with 15-day retention. If the pod dies, all metrics are lost. No long-term historical analysis possible.

**Recommended approaches** (in order of complexity):

1. **Prometheus + Thanos Sidecar**: Uploads data blocks to S3 for long-term retention
2. **Amazon Managed Service for Prometheus (AMP)**: AWS-managed, PromQL-compatible, eliminates operational overhead
3. **Cortex**: Multi-tenant, horizontally scalable Prometheus backend

For this solution, **AMP** is the lowest-effort option since the infrastructure is already on AWS.

---

## Part VI: Complete Gap Summary

| # | Gap | Priority | Impact | Effort |
|---|-----|----------|--------|--------|
| 1 | SNS topic not created | HIGH | Alarms fire silently | Low |
| 2 | No distributed tracing (X-Ray/ADOT) | CRITICAL | Can't trace cross-service requests | High |
| 3 | ServiceMonitor labels missing | HIGH | Prometheus service discovery fails | Low |
| 4 | No Alertmanager routing config | HIGH | Prometheus alerts not delivered | Low |
| 5 | No structured logging (JSON) | MEDIUM | Hard to query logs | Medium |
| 6 | No custom business metrics | MEDIUM | No business observability | Medium |
| 7 | No Prometheus HA/remote storage | MEDIUM | Data loss risk, 15-day limit | High |
| 8 | Grafana missing CloudWatch datasource | HIGH | AWS metrics only in Console | Low |
| 9 | No CloudWatch Logs Insights queries | LOW | Manual log searching | Low |
| 10 | No Grafana deployment annotations | LOW | Can't correlate deploys with metrics | Low |

---

## Common Pitfalls and Errors

### 1. Alert Fatigue from Threshold Misconfiguration

```
# Bad - Single evaluation period, low threshold
evaluation_periods = 1
period             = 60
threshold          = 50   # CPU spikes are normal during deployments
```

```
# Good - Multiple evaluation periods, realistic threshold
evaluation_periods = 3
period             = 300
threshold          = 80   # Sustained high usage, not transient spikes
```

### 2. Missing ok_actions on Alarms

```terraform
# Bad - Only alarm_actions, no recovery notification
alarm_actions = [aws_sns_topic.alerts.arn]

# Good - Both alarm and recovery
alarm_actions = [aws_sns_topic.alerts.arn]
ok_actions    = [aws_sns_topic.alerts.arn]
```

Without `ok_actions`, engineers get paged but never know when the issue resolves.

### 3. CloudWatch Log Retention Not Set

```terraform
# Bad - Default retention is NEVER expire (costs accumulate forever)
resource "aws_cloudwatch_log_group" "app" {
  name = "/app/logs"
}

# Good - Explicit retention
resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/logs"
  retention_in_days = 30
}
```

### 4. ContainerInsights Not Enabled

The CloudWatch dashboard queries `ContainerInsights` namespace, but Container Insights must be explicitly enabled on the EKS cluster:

```terraform
# Required in EKS module
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "amazon-cloudwatch-observability"
}
```

Without this addon, the CloudWatch dashboard widgets show no data.

---

## When to Use CloudWatch vs Prometheus

### Use CloudWatch When:
- Monitoring AWS-managed services (RDS, ElastiCache, API Gateway, Lambda)
- Needing long-term metric retention (up to 15 months standard)
- Requiring AWS-native integrations (EventBridge, Auto Scaling, SNS)
- Auditing API calls (CloudTrail → CloudWatch Logs)
- Cost is not the primary concern and operational simplicity is valued

### Use Prometheus When:
- Monitoring application-level metrics (HTTP, JVM, custom business)
- Needing high-resolution scraping (sub-minute intervals)
- Requiring complex queries with PromQL
- Operating Kubernetes workloads with built-in service discovery
- Cost-sensitive environments (self-hosted, pay only for compute)

### Use Both When:
- Running microservices on EKS with AWS managed data stores (this solution)
- Needing correlated views across infrastructure and application layers
- Requiring different retention policies for different metric types

---

## Best Practices

1. **Unify dashboards in Grafana** with both Prometheus and CloudWatch datasources — avoid AWS Console for day-to-day monitoring
2. **Set explicit log retention** on all CloudWatch Log Groups to control costs
3. **Use 3+ evaluation periods** on CloudWatch alarms to prevent flapping alerts
4. **Enable Container Insights** as an EKS addon for node and pod-level CloudWatch metrics
5. **Implement structured logging** (JSON) to enable CloudWatch Logs Insights queries
6. **Add correlation IDs** to logs for cross-service request tracing
7. **Create SNS topics** for all alarm notifications — alarms without notifications are useless
8. **Use IRSA** (IAM Roles for Service Accounts) for Grafana's CloudWatch access — never use long-lived credentials
9. **Drop high-cardinality metrics** via relabeling to prevent Prometheus performance degradation
10. **Instrument business metrics** alongside infrastructure metrics — monitoring should answer business questions, not just technical ones

---

## Interview Key Points

### What to Emphasize

1. **Three Pillars**: Explain that complete observability requires metrics (Prometheus + CloudWatch), logs (CloudWatch Logs with structured JSON), and traces (X-Ray/ADOT) — missing any pillar creates blind spots
2. **Single Pane of Glass**: Grafana can unify Prometheus and CloudWatch datasources, eliminating context-switching between tools during incidents
3. **ContainerInsights**: The bridge between Kubernetes and CloudWatch — it publishes EKS node/pod metrics to CloudWatch's `ContainerInsights` namespace
4. **Alert Design**: Demonstrate understanding of alert fatigue — use multiple evaluation periods, meaningful thresholds, and both alarm/ok actions
5. **Cost Awareness**: CloudWatch charges per metric, alarm, and log ingestion — explain trade-offs between CloudWatch and self-hosted Prometheus
6. **IRSA for Security**: Grafana accessing CloudWatch should use IAM Roles for Service Accounts, not access keys
7. **Structured Logging**: JSON logs enable CloudWatch Logs Insights queries — unstructured text requires regex parsing and is brittle

### Common Interview Questions

**Q1: Why use both Prometheus and CloudWatch instead of just one?**
Prometheus excels at application-level metrics with PromQL and 15-second granularity, but it cannot see AWS-managed service internals (RDS IOPS, API Gateway throttling). CloudWatch natively monitors AWS services but lacks the query flexibility and scrape frequency of Prometheus. In an EKS microservices architecture with AWS managed data stores, you need both — unified through Grafana.

**Q2: How do CloudWatch Alarms work, and what's the evaluation model?**
A CloudWatch alarm evaluates a metric against a threshold over a specified number of evaluation periods. For example, "average CPU > 80% for 3 consecutive 5-minute periods" means the alarm only triggers after 15 minutes of sustained high CPU. This prevents false positives from transient spikes. Alarms have three states: OK, ALARM, and INSUFFICIENT_DATA. Notifications are sent via SNS when state transitions occur.

**Q3: How would you investigate a production latency issue using this monitoring stack?**
Start with the Grafana dashboard to identify which service shows elevated p99 latency. Check the correlated CloudWatch panels for RDS CPU and API Gateway latency to rule out infrastructure bottlenecks. If the issue is inter-service, use distributed traces (X-Ray) to identify the slow span. Finally, use CloudWatch Logs Insights with the trace correlation ID to find the specific log entries around the slow request.

**Q4: What is Container Insights and why is it needed?**
Container Insights is an EKS addon that publishes Kubernetes node and pod metrics to CloudWatch's `ContainerInsights` namespace. Without it, CloudWatch has no visibility into EKS workloads — it only sees the EC2 instances, not the pods running on them. Metrics include `node_cpu_utilization`, `node_memory_utilization`, `pod_number_of_running`, and `node_network_total_bytes`.

**Q5: How does Grafana authenticate to CloudWatch in EKS?**
The best practice is IRSA (IAM Roles for Service Accounts). You create an IAM role with CloudWatch read permissions, associate it with the Grafana Kubernetes ServiceAccount via an OIDC trust policy, and configure the Grafana CloudWatch datasource with `authType: default`. The AWS SDK in Grafana automatically picks up the IAM role from the pod's projected service account token — no access keys needed.

**Q6: What's the difference between CloudWatch Metrics and CloudWatch Logs Insights?**
CloudWatch Metrics stores time-series numerical data (CPU, latency, request count) that you query with metric math or Metrics Insights. CloudWatch Logs Insights is a query engine for log data — you write SQL-like queries to search, filter, and aggregate log entries. They serve different purposes: metrics for dashboards and alarms, Logs Insights for ad-hoc investigation.

**Q7: How do you prevent CloudWatch costs from spiraling?**
Set explicit retention periods on all log groups (never use the default of "never expire"). Use metric filters instead of storing every log line. Choose standard resolution (60s) over high resolution (1s) for CloudWatch custom metrics unless sub-minute granularity is required. Offload long-term log storage to S3 via subscription filters. Monitor your CloudWatch costs with AWS Cost Explorer.

**Q8: What is CloudTrail and how does it differ from CloudWatch?**
CloudTrail records **who did what** — every AWS API call (e.g., someone deleted an RDS instance, modified a security group). CloudWatch records **how things are performing** — metrics, logs, and alarms. CloudTrail is an audit trail; CloudWatch is an observability platform. They complement each other: CloudTrail events can be sent to CloudWatch Logs for querying and alarming on suspicious API activity.

**Q9: Why use structured logging (JSON) instead of plain text?**
Structured logs allow CloudWatch Logs Insights to parse fields without regex. You can query `| filter service.name = "svc-a" and log.level = "ERROR"` directly. With plain text, you'd need fragile pattern matching. Structured logs also enable automatic metric extraction via CloudWatch Embedded Metric Format (EMF) and make log correlation across services possible via shared trace IDs.

**Q10: How would you design alerting to avoid alert fatigue?**
Use tiered severity (critical = pages on-call, warning = Slack channel). Set evaluation periods to avoid transient spikes (3x 5min, not 1x 1min). Include both alarm and ok actions so engineers know when issues resolve. Group related alerts in Alertmanager to avoid notification storms. Add runbook URLs to every alert so responders know what to do. Review and tune thresholds monthly based on actual incident data.

---

## Summary

| Aspect | Current State | Best Practice Target |
|--------|--------------|---------------------|
| **Metrics (K8s/App)** | Prometheus + Grafana | No change needed |
| **Metrics (AWS)** | CloudWatch (Console only) | Add CloudWatch datasource to Grafana |
| **Logs** | CloudWatch Log Groups (unstructured) | Structured JSON + Logs Insights queries |
| **Traces** | Not implemented | X-Ray or ADOT |
| **Alerting (K8s)** | Rules defined, no routing | Add Alertmanager routing config |
| **Alerting (AWS)** | Alarms defined, no SNS | Create SNS topic + subscriptions |
| **Dashboards** | Split (Grafana + AWS Console) | Unified in Grafana |
| **Audit** | CloudTrail → S3 + CloudWatch Logs | No change needed |
| **Business Metrics** | None | Micrometer custom counters/timers |

**Key Takeaway**: The monitoring foundation is solid — Prometheus, Grafana, CloudWatch, and CloudTrail are all in place. The critical gap is **integration and completeness**: unifying datasources in Grafana, adding distributed tracing, wiring up alert notifications, and adopting structured logging. These are low-to-medium effort fixes that dramatically improve operational readiness.

---

## Sources

- [Amazon CloudWatch data source — Grafana documentation](https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/)
- [Configure CloudWatch datasource — Grafana documentation](https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/configure/)
- [Grafana dashboard best practices](https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/best-practices/)
- [Container Insights — Amazon CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- [Best practice alarm recommendations — Amazon CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best-Practice-Alarms.html)
- [Tracing tools for Amazon EKS — AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/amazon-eks-observability-best-practices/tracing-tools.html)
- [Structured Logging with Spring Boot and Amazon CloudWatch](https://reflectoring.io/struct-log-with-cloudwatch-tutorial/)
- [Best practices for logging in Amazon EKS — AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/amazon-eks-observability-best-practices/logging-best-practices.html)
- [Structured Logging in Spring Boot — Baeldung](https://www.baeldung.com/spring-boot-structured-logging)
- [2026 observability trends — Grafana Labs](https://grafana.com/blog/2026-observability-trends-predictions-from-grafana-labs-unified-intelligent-and-open/)
