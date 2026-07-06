#!/bin/bash
#############################################
# Validation Script
# Runs pre-commit checks before deployment
#############################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔍 Running Terraform validation..."
terraform -chdir="$TERRAFORM_DIR" fmt --check --recursive . || {
  echo "❌ Formatting check failed. Run: terraform fmt -recursive ."
  exit 1
}

terraform -chdir="$TERRAFORM_DIR" validate || {
  echo "❌ Terraform validation failed"
  exit 1
}

# Check for tfsec if installed
if command -v tfsec &> /dev/null; then
  echo "🔒 Running tfsec security scan..."
  tfsec "$TERRAFORM_DIR" --minimum-severity high || {
    echo "⚠️  tfsec found issues. Review above."
    # Don't fail on tfsec, just warn
  }
else
  echo "⚠️  tfsec not installed. Skipping security scan."
  echo "   Install: brew install tfsec (macOS) or visit https://aquasecurity.github.io/tfsec/latest/"
fi

# Check for checkov if installed
if command -v checkov &> /dev/null; then
  echo "✅ Running Checkov compliance check..."
  checkov -d "$TERRAFORM_DIR" --framework terraform --quiet || {
    echo "⚠️  Checkov found issues. Review above."
    # Don't fail on checkov, just warn
  }
else
  echo "⚠️  Checkov not installed. Skipping compliance check."
  echo "   Install: pip install checkov"
fi

echo "✅ Validation passed!"
