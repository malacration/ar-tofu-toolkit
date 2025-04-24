
# resource "aws_ses_email_identity" "email" {
#   email = "${var.email_address}@${var.domain}"
# }

resource "aws_iam_user" "smtp_user" {
  name = "ses-${var.email_address}"
  tags = {
      Name = "ses-${var.email_address}"
  }
}

resource "aws_iam_access_key" "smtp_key" {
  user = aws_iam_user.smtp_user.name
}

resource "aws_iam_user_policy" "ses_send_email_policy" {
  name = "SESSendEmailPolicy"
  user = aws_iam_user.smtp_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ]
      Resource = "*"
    }]
  })
}

output "smtp_username" {
  value = aws_iam_access_key.smtp_key.id
}

output "smtp_password" {
  value     = nonsensitive(aws_iam_access_key.smtp_key.secret)
}

output "mail" {
  value     = "mail.${var.domain}"
}
