
resource "aws_s3_bucket" "test_bucket" {
  bucket = "test-bucket"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "index.py"
  output_path = "file_lambda.zip"
}

resource "aws_lambda_function" "file_lambda" {
  filename      = "file_lambda.zip"
  function_name = "file_lambda_function"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.handler"
  runtime       = "python3.8"
  

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.file_processing.arn
      FILE_NAME_KEY     = "FileName"
    }
  }
}

resource "aws_s3_bucket_notification" "example_notification" {
  bucket = aws_s3_bucket.test_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.file_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role" "stepfunction_role" {
  name = "stepfunction_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_stepfunctions_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

variable "file_name_key" {
  type    = string
  default = "FileName"
}
resource "aws_sfn_state_machine" "file_processing" {
  name     = "FileProcessing"
  role_arn = aws_iam_role.stepfunction_role.arn
  definition = <<EOF
{
  "Comment": "A simple state machine that writes to DynamoDB",
  "StartAt": "WriteToDynamoDB",
  "States": {
    "WriteToDynamoDB": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:putItem",
      "Parameters": {
        "TableName": "${aws_dynamodb_table.table_db.name}",
        "Item": {
          "${var.file_name_key}": {
            "S.$": "$.${var.file_name_key} || 'default_value'"
          }
        }
      },
      "End": true
    }
  }
}
EOF
}

resource "aws_dynamodb_table" "table_db" {
  name           = "Files"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "FileName"
  attribute {
    name = "FileName"
    type = "S"
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.test_bucket.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.table_db.name
}

output "stepfunction_arn" {
  value = aws_sfn_state_machine.file_processing.arn
}