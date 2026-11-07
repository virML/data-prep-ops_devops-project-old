.PHONY: test terraform-validate terraform-plan terraform-apply terraform-destroy

test:
	python3 -m pytest -q

terraform-validate:
	terraform -chdir=terraform fmt -recursive
	terraform -chdir=terraform init
	terraform -chdir=terraform validate

terraform-plan:
	terraform -chdir=terraform plan

terraform-apply:
	terraform -chdir=terraform apply

terraform-destroy:
	terraform -chdir=terraform destroy
