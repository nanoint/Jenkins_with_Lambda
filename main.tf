terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "eu-central-1"
}

terraform {
  backend "s3" {
    key    = "nagzhigitov/nagzhigitov.tfstate"
    region = "eu-central-1"
    bucket = "finalasmt3-nagzhigitov-tfstate"
  }
}

#permissions
resource "aws_iam_role" "iam_for_lambda" {
  name = "${var.prefix}-lambda_role-${terraform.workspace}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"

}

resource "aws_iam_role_policy_attachment" "lambda_cloudWatch_attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"

}

resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda1.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda-tg.arn
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.terraform_queue.arn
  function_name    = aws_lambda_function.lambda2.arn
}


#lambdas
data "archive_file" "lambda1-zip" {
  type        = "zip"
  output_path = "lambda1.zip"
  source {
    content  = file("files/lambdafile1/main.py")
    filename = "main.py"
  }
}

data "archive_file" "lambda2-zip" {
  type        = "zip"
  output_path = "lambda2.zip"
  source {
    content  = file("files/lambdafile2/main.py")
    filename = "main.py"
  }
}

resource "aws_lambda_function" "lambda1" {
  filename         = data.archive_file.lambda1-zip.output_path
  function_name    = "${var.prefix}-lambda1-${terraform.workspace}"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "main.lambda_handler"
  source_code_hash = data.archive_file.lambda1-zip.output_base64sha256
  runtime          = "python3.9"

  environment {
    variables = {
      MY_CONSTANT   = "Pizza"
      SQS_QUEUE_URL = aws_sqs_queue.terraform_queue.url
    }
  }
  tags = {
    Environment = "${terraform.workspace}"
  }
}

resource "aws_lambda_function" "lambda2" {
  filename         = data.archive_file.lambda2-zip.output_path
  function_name    = "${var.prefix}-lambda2-${terraform.workspace}"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "main.lambda_handler"
  source_code_hash = data.archive_file.lambda2-zip.output_base64sha256
  runtime          = "python3.9"

  tags = {
    Environment = "${terraform.workspace}"
  }
}

resource "aws_sqs_queue" "terraform_queue" {
  name                      = "${var.prefix}-sqs-${terraform.workspace}"
  delay_seconds             = 90
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10

  tags = {
    Environment = "${terraform.workspace}"
  }
}

#alb

resource "aws_lb" "lambda" {
  name               = "${var.prefix}-alb-${terraform.workspace}"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["subnet-0ad4947b529ea6577", "subnet-0056cb89cd49ab2e4"]
  security_groups    = [aws_security_group.lambdasg.id, ]

  tags = {
    Environment = "${terraform.workspace}"
  }
}

resource "aws_lb_target_group" "lambda-tg" {
  name        = "${var.prefix}-tg-${terraform.workspace}"
  target_type = "lambda"
}

resource "aws_lb_target_group_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.lambda-tg.arn
  target_id        = aws_lambda_function.lambda1.arn
  depends_on       = [aws_lambda_permission.alb]
}

resource "aws_lb_listener" "lb-listener" {
  load_balancer_arn = aws_lb.lambda.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda-tg.arn
  }
}

#sgs

resource "aws_security_group" "lambdasg" {
  name   = "${var.prefix}-sg-${terraform.workspace}"
  vpc_id = "vpc-087b4e0167a2591a9"


  ingress = [
    {
      description      = "from anywhere"
      from_port        = 80
      to_port          = 80
      protocol         = "TCP"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = true
    },
  ]

  egress = [
    {
      description      = "to anywhere"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = true
    },
  ]

  tags = {
    Name = "access on port 80"
  }
}

output "tf_workspace" {
  value = terraform.workspace
}
