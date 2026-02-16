data "aws_caller_identity" "current" {}

# --- EKS Cluster Role ---

resource "aws_iam_role" "eks_cluster" {
  name = "${var.project}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-eks-cluster-role"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# --- EKS Node Group Role ---

resource "aws_iam_role" "eks_node_group" {
  name = "${var.project}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-eks-node-role"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# --- IRSA Role for Application Service Accounts ---

resource "aws_iam_role" "app_service_account" {
  name = "${var.project}-${var.environment}-app-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.eks_namespace}:*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-app-irsa-role"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_iam_policy" "app_service_account" {
  name        = "${var.project}-${var.environment}-app-irsa-policy"
  description = "Policy for application service accounts via IRSA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project}-${var.environment}-*",
          "arn:aws:s3:::${var.project}-${var.environment}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "arn:aws:sqs:*:${data.aws_caller_identity.current.account_id}:${var.project}-${var.environment}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.project}/${var.environment}/*"
      }
    ]
  })

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "app_service_account" {
  policy_arn = aws_iam_policy.app_service_account.arn
  role       = aws_iam_role.app_service_account.name
}

# --- CI/CD Role ---

resource "aws_iam_role" "cicd" {
  name = "${var.project}-${var.environment}-cicd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-cicd-role"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_iam_policy" "cicd" {
  name        = "${var.project}-${var.environment}-cicd-policy"
  description = "Policy for CI/CD pipeline"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = var.ecr_repository_arns
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/${var.project}-${var.environment}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "cicd" {
  policy_arn = aws_iam_policy.cicd.arn
  role       = aws_iam_role.cicd.name
}
