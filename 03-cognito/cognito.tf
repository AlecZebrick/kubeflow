data "aws_acm_certificate" "**************" {
  domain      = "*.alpha.**************.net"
  statuses    = ["ISSUED"]
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

resource "aws_cognito_user_pool" "kubeflow" {
  name = "kubeflow"
  auto_verified_attributes = ["email"]
}

data "aws_route53_zone" "kubeflow" {
  name         = "alpha.**************.net"
  private_zone = false
}

resource "aws_cognito_user_pool_domain" "main" {
  domain          = "kubeflow-**************"
  user_pool_id    = aws_cognito_user_pool.kubeflow.id
}

data "aws_secretsmanager_secret" "google-oauth" {
  name = "google-oauth-kubeflow"
}

data "aws_secretsmanager_secret_version" "google" {
  secret_id = data.aws_secretsmanager_secret.google-oauth.id
}

resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.kubeflow.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    authorize_scopes = "email"
    client_id        = jsondecode(data.aws_secretsmanager_secret_version.google.secret_string)["google-client-id"]
    client_secret    = jsondecode(data.aws_secretsmanager_secret_version.google.secret_string)["google-secret"]
  }

    attribute_mapping = {
    email    = "email"
    username = "sub"
    // Verify this is set in attribute mapping. Sometimes you have to delete/recreate the email verification. Can cause issue logging into kubeflow with google
    "Email Verified" = "email_verified"
  }
}

resource "aws_cognito_user_pool_client" "client" {
  depends_on = [aws_cognito_user_pool.kubeflow, aws_cognito_identity_provider.google]
  name = "client"
  allowed_oauth_flows_user_pool_client = "true"
  generate_secret = "true"
  callback_urls = ["https://kubeflow-**************.alpha.**************.net/oauth2/idpresponse"]
  user_pool_id = aws_cognito_user_pool.kubeflow.id
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  supported_identity_providers = ["Google", "COGNITO"]
}

resource "aws_route53_record" "auth-cognito-A" {
  name    = "kubeflow-**************.alpha.**************.net"
  type    = "A"
  zone_id = data.aws_route53_zone.kubeflow.zone_id
  ttl     = "5"
  records = ["127.0.1.2"]

}

