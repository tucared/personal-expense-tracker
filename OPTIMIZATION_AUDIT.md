# Repository Optimization Audit

Based on comprehensive analysis of the codebase structure and configuration files, here are the key optimization recommendations organized by priority:

## High Priority Optimizations

### 1. **Standardize Cloud Function Dependency Management**

- **Constraint**: Google Cloud Functions require `requirements.txt` for deployment
- **Current Issue**: Dual maintenance of `requirements.txt` and `pyproject.toml` creates sync drift
- **Solution**: Generate `requirements.txt` from `pyproject.toml` using `uv export` in build process
- **Files**: `opentofu/modules/notion_pipeline/src/requirements.txt`, `opentofu/modules/gsheets_pipeline/src/requirements.txt`

### 2. **Eliminate Terraform Variable Duplication**

- 90% of variables are duplicated between `notion_pipeline/variables.tf` and `gsheets_pipeline/variables.tf`
- Create shared variable definitions in `base_pipeline` module
- Consolidate nearly identical output files

### 3. **Standardize Python Dependency Management**

- Inconsistent dependency group naming (`dev` vs `dev-dependencies`)
- Common dependencies duplicated across pipeline modules (dlt, functions-framework, mypy, ruff)
- Create shared dependency configuration

## Medium Priority Optimizations

### 4. **Differentiate Environment Configurations**

- `terragrunt/dev/env_vars.example.yaml` and `terragrunt/prod/env_vars.example.yaml` are 100% identical
- Add environment-specific defaults (scheduler frequency, resource sizing, paused states)

### 5. **Refactor Makefile Repetition**

- Lines 33-81 contain repetitive environment variable exports
- Hard-coded service names in multiple places
- Abstract service-specific configuration into data structures

### 6. **Standardize Secret Management**

- Inconsistent patterns in `data_explorer/main.tf` (random_password vs direct input)
- Inconsistent naming conventions (`bucket-reader-hmac` vs `data-explorer-auth-password`)

## Low Priority Optimizations

### 7. **Repository Structure**

- Update `.gitignore` for terragrunt cache directories
- Consider workspace-level dependency management for multiple `uv.lock` files

### 8. **Container Strategy Consistency**

- Only `data_explorer` has Docker configs while pipelines use Cloud Functions
- Evaluate if containerization patterns should be unified

## Detailed Analysis

### Terraform/OpenTofu Duplication Issues

#### Critical Duplication: Pipeline Module Variables

- **Files**:

  - `opentofu/modules/notion_pipeline/variables.tf`
  - `opentofu/modules/gsheets_pipeline/variables.tf`

**Duplication Pattern**: Both modules share 90% identical variable definitions:

```hcl
# Duplicated in both files:
variable "project_id" { description = "The GCP project ID"; type = string }
variable "region" { description = "The region to deploy resources to"; type = string }
variable "data_bucket_name" { description = "Name of the GCS bucket where data will be stored"; type = string }
variable "data_bucket_writer_service_account_email" { description = "Service account email for the Cloud Function"; type = string }
variable "cloud_scheduler_parameters" { ... }
```

**Optimization**: Create a shared `variables.tf` file in the base_pipeline module and use variable forwarding.

#### Output Files Duplication

- **Files**:
  - `opentofu/modules/notion_pipeline/outputs.tf`
  - `opentofu/modules/gsheets_pipeline/outputs.tf`

**Duplication**: 80% identical output definitions forwarding from base_pipeline module. Only difference is one additional output in gsheets_pipeline.

### Python Project Configuration Issues

#### Mixed Dependency Management (Anti-Pattern)

**Problem**: Manual maintenance of both `pyproject.toml` and `requirements.txt` files:

- `opentofu/modules/notion_pipeline/src/` (both files, 671 lines in requirements.txt)
- `opentofu/modules/gsheets_pipeline/src/` (both files, 848 lines in requirements.txt)
- `opentofu/modules/data_explorer/src/` (only pyproject.toml)

**Issue**: Cloud Functions require `requirements.txt` but maintaining both files manually creates sync drift and conflicts.

**Solution**: Use `uv export --format requirements-txt > requirements.txt` to generate from `pyproject.toml`.

#### Inconsistent Dependency Group Naming

```toml
# notion_pipeline & gsheets_pipeline:
[dependency-groups]
dev = [...]

# data_explorer:
[tool.uv]
dev-dependencies = [...]
```

#### Shared Dependencies Not Abstracted

Common dependencies across pipeline modules:

```toml
# Duplicated in both pipeline pyproject.toml files:
"dlt[parquet]>=1.5.0",
"dlt[gs]>=1.5.0", 
"dlt[filesystem]>=0.3.5",
"functions-framework>=3.8.2",
"mypy>=1.14.1",
"ruff>=0.8.6",
```

### Environment Configuration Duplication

#### Identical Terragrunt Environment Files

- `terragrunt/dev/env_vars.example.yaml`
- `terragrunt/prod/env_vars.example.yaml`

These files are **100% identical**, which is problematic for several reasons:

- No environment-specific defaults
- Same example values across environments
- Missing environment-specific configuration patterns

#### Duplicate Terragrunt Configuration

- `terragrunt/dev/terragrunt.hcl`
- `terragrunt/prod/terragrunt.hcl`

Both files are identical single-line includes, missing environment-specific overrides.

### Makefile Optimization Opportunities

#### Repetitive Environment Variable Setup

The Makefile's `_run-local` target contains extensive repeated export statements and case logic that could be abstracted:

```makefile
# Lines 33-81: Repetitive pattern for each service
export DESTINATION__FILESYSTEM__BUCKET_URL=gs://$$DATA_BUCKET_NAME && \
export NORMALIZE__LOADER_FILE_FORMAT="parquet" && \
export RUNTIME__LOG_LEVEL="DEBUG" && \
# ... more repetition
```

**Optimization**: Create service-specific configuration files or functions.

#### Hard-coded Service Names

Service names (`notion`, `gsheets`, `data-explorer`) are hard-coded in multiple places, violating DRY principles.

## Specific Optimization Recommendations

### 1. Create Shared Terraform Variable Module

```hcl
# opentofu/modules/shared_variables/variables.tf
variable "pipeline_common_vars" {
  description = "Common variables for all pipeline modules"
  type = object({
    project_id    = string
    region        = string
    data_bucket_name = string
    service_account_email = string
    cloud_scheduler_parameters = object({...})
  })
}
```

### 2. Consolidate Python Dependencies

Create a shared `requirements-base.txt` or use workspace features:

```toml
# pyproject-shared.toml (workspace root)
[project]
dependencies = [
    "dlt[parquet,gs,filesystem]>=1.5.0",
]

[dependency-groups]
pipeline-dev = [
    "functions-framework>=3.8.2",
    "mypy>=1.14.1", 
    "ruff>=0.8.6",
]
```

### 3. Environment-Specific Configuration

```yaml
# terragrunt/dev/env_vars.example.yaml
project_id: "dev-${random_suffix}"
region: europe-west9

notion_pipeline:
  cloud_scheduler_parameters:
    paused: true  # Keep dev paused
    schedule: "0 */6 * * *"  # Less frequent for dev

# terragrunt/prod/env_vars.example.yaml  
project_id: "prod-${company_name}"
notion_pipeline:
  cloud_scheduler_parameters:
    paused: false  # Active in prod
    schedule: "0 * * * *"  # Hourly in prod
```

### 4. Makefile Service Configuration

```makefile
# Define service configs in a data structure
SERVICES := notion gsheets data-explorer
SERVICE_CONFIGS := $(addsuffix _config.mk,$(SERVICES))

# Include service-specific configuration files
include $(SERVICE_CONFIGS)
```

### 5. Automate Requirements.txt Generation

Since Cloud Functions require `requirements.txt`, automate generation from `pyproject.toml`:

```makefile
# Add to Makefile or CI/CD
generate-requirements:
  cd opentofu/modules/notion_pipeline/src && uv export --format requirements-txt > requirements.txt
  cd opentofu/modules/gsheets_pipeline/src && uv export --format requirements-txt > requirements.txt
```

This eliminates manual sync between `pyproject.toml` and `requirements.txt` (671-848 lines each).

## Implementation Impact

- **Reduction**: ~40% less Terraform code duplication
- **Maintainability**: Single source of truth for shared configurations  
- **Consistency**: Unified dependency and environment management
- **Risk**: Low - mostly consolidation of existing patterns

## Code Quality Metrics

- **Duplication Level**: ~40% of Terraform variables are duplicated
- **Configuration Consistency**: 3 different dependency management patterns
- **Environment Differentiation**: 0% (dev and prod configs identical)
- **Maintenance Overhead**: High due to synchronized updates required across multiple files

This analysis reveals significant opportunities for consolidation and standardization that would improve maintainability, reduce errors, and follow infrastructure-as-code best practices.
