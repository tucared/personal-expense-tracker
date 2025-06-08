# Pattern rule for any command and environment
%-dev:
	cd terragrunt/dev && terragrunt $* --terragrunt-non-interactive

%-prod:
	cd terragrunt/prod && terragrunt $* --terragrunt-non-interactive

# Make all -dev and -prod targets phony
.PHONY: %-dev %-prod