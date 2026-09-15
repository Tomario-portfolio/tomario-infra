resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tomario-${var.env}-vpc"
  }
}

# VPC作成時にAWSが自動生成するdefault SGは、素の状態だとingress/egressが空でなく
# 誰も参照していなくても存在するだけでSecurity Hub findingになるため、明示的に空にする
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "tomario-${var.env}-default-sg"
  }
}

resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "tomario-${var.env}-public-${var.azs[count.index]}"
  }
}

resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "tomario-${var.env}-private-${var.azs[count.index]}"
  }
}
