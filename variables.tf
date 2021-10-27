variable "prefix" {
  type    = string
  default = "asmt3-nagzhigitov"
}

variable "lambda_sqs_role" {
  type    = string
  default = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

variable "lambda_subnets" {
  type    = list(string)
  default = ["subnet-0c98e1819f7381e46", "subnet-04d9ba157b61c1802"]
}

variable "lambda_sg" {
  type    = list(string)
  default = ["sg-05f458da58e048aa1", "sg-05f3088b18a0199cf"]
}
