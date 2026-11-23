#!/usr/bin/env bats

@test "gitops bootstrap dry-run renders overlay" {
  export GITOPS_DRY_RUN=1
  export TFVARS="${BATS_TEST_DIRNAME}/../../clusters/public/terraform.tfvars"
  run bash "${BATS_TEST_DIRNAME}/../../scripts/gitops-bootstrap.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cluster-observability-operator"* ]]
  [[ "$output" == *"lightspeed-operator"* ]]
  [[ "$output" == *"rhcl-operator"* ]]
}