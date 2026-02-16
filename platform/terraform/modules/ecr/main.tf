resource "aws_ecr_repository" "services" {
  for_each = toset(var.repository_names)

  name                 = "${var.project}-${var.environment}-${each.value}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-${each.value}"
    Project     = var.project
    Environment = var.environment
    Service     = each.value
  })
}

resource "aws_ecr_lifecycle_policy" "services" {
  for_each = toset(var.repository_names)

  repository = aws_ecr_repository.services[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last ${var.max_image_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
