<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a name="readme-top"></a>

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <!-- <a href="https://github.com/tucared/lakehouse-starter">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a> -->

<h1 align="center">Lakehouse Starter</h1>

  <strong><p align="center">
    A production-ready data lakehouse template using OpenTofu, DLT, and Streamlit on Google Cloud Platform (GCP).</strong>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#overview">Overview</a>
      <ul>
        <li><a href="#tech-stack">Tech Stack</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation-steps">Installation Steps</a></li>
            <ul>
                <li><a href="#setup-notion-database">Setup Notion Database</a></li>
                <li><a href="#configure-local-repository">Configure Local Repository</a></li>
                <li><a href="#setup-google-cloud-project">Setup Google Cloud Project</a></li>
                <li><a href="#configure-service-account">Configure Service Account</a></li>
                <li><a href="#deploy-infrastructure">Deploy Infrastructure</a></li>
            </ul>
      </ul>
    </li>
    <li><a href="#usage">Usage</a>
        <ul>
            <li><a href="#data-flow">Data Flow</a></li>
            <li><a href="#triggering-data-ingestion">Triggering Data Ingestion</a></li>
            <li><a href="#cleanup">Cleanup</a></li>
            <li><a href="#sequence-diagram">Sequence diagram</a></li>
        </ul>
    </li>
    <li><a href="#cost-management">Cost Management</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- OVERVIEW -->
## Overview

This project provides a template for building a modern data lakehouse that:

- Deploys infrastructure-as-code using OpenTofu on GCP
- Includes a modular data pipeline powered by DLT (starting with Notion integration)
- Enables SQL analytics using DuckDB for efficient data querying
- Features a Streamlit web application for interactive data exploration
- Stays within GCP's free tier limits when used as provided

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Tech Stack

- [![OpenTofu][OpenTofu.org]][OpenTofu-url]
- [![Google Cloud][Console.cloud.google.com]][Google-Cloud-url]
- [![Terragrunt][Terragrunt.io]][Terragrunt-url]
- [![Python][Python.org]][Python-url]
- [![Streamlit][Streamlit.io]][Streamlit-url]
- [![Dlt][dltHub.com]][dlt-url]
- [![Notion][Notion.so]][Notion-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

To get a copy of the project up and running follow the steps below.

### Prerequisites

- [Notion account]
- [Google Cloud billing account]
- [gcloud CLI] installed
- [OpenTofu] installed
- [Terragrunt] installed

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Installation Steps

#### Setup Notion Database

- [Create an internal Notion integration] with read permissions

- [Connect the integration to your database]

#### Configure Local Repository

```shell
cp -a terragrunt/example terragrunt/prod
```

Edit `terragrunt/prod/env_vars.yaml` with your:

- project_id (unique GCP identifier)
- notion_secret_value

#### Setup Google Cloud Project

```shell
export BILLING_ACCOUNT_ID=your_billing_account_id
cd terragrunt/prod
export PROJECT_ID=$(grep "project_id" env_vars.yaml | awk '{print $2}' | tr -d '"')

gcloud projects create $PROJECT_ID
gcloud beta billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT_ID

# Enable required APIs
gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudfunctions.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudscheduler.googleapis.com --project=$PROJECT_ID
gcloud services enable run.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID
gcloud services enable iam.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudresourcemanager.googleapis.com --project=$PROJECT_ID
```

#### Configure Service Account

```shell
unset GOOGLE_CREDENTIALS
gcloud auth application-default login --no-launch-browser
```

Then create and configure the service account using the provided script below.

<details><summary>Script to create service account and assign permissions</summary>

```shell
export PROJECT_ID=$(grep "project_id" env_vars.yaml | awk '{print $2}' | tr -d '"')
export TOFU_SERVICE_ACCOUNT=$(grep "sa_tofu" env_vars.yaml | awk '{print $2}' | tr -d '"')
export USER_ACCOUNT_ID=$(echo `gcloud config get core/account`)

gcloud iam service-accounts create $TOFU_SERVICE_ACCOUNT \
    --display-name "OpenTofu SA" \
    --description "Used when running OpenTofu commands" \
    --project $PROJECT_ID

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:$TOFU_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --project $PROJECT_ID \
    --role "roles/editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:$TOFU_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --project $PROJECT_ID \
    --role "roles/secretmanager.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:$TOFU_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --project $PROJECT_ID \
    --role "roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:$TOFU_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --project $PROJECT_ID \
    --role "roles/iam.serviceAccountCreator"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:$TOFU_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --project $PROJECT_ID \
    --role "roles/resourcemanager.projectIamAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:$TOFU_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --project $PROJECT_ID \
    --role "roles/cloudfunctions.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:$TOFU_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --project $PROJECT_ID \
    --role "roles/cloudscheduler.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member "serviceAccount:$TOFU_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --project $PROJECT_ID \
    --role "roles/run.admin"

gcloud iam service-accounts add-iam-policy-binding \
    $TOFU_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com \
    --project $PROJECT_ID \
    --member "user:$USER_ACCOUNT_ID" \
    --role "roles/iam.serviceAccountTokenCreator"
```

</details>

#### Deploy Infrastructure

```shell
terragrunt apply

# Deploy Streamlit app
gcloud builds triggers run $(terragrunt output streamlit_build_trigger_name | sed 's/"//g') \
    --region=$(terragrunt output streamlit_build_trigger_region | sed 's/"//g')
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE -->
## Usage

### Data Flow

1. **Source**: Data stored in Notion databases
2. **Ingestion**: Automated via Cloud Scheduler or manual triggers
3. **Storage**: Data stored in Cloud Storage
4. **Analysis**: Access via Streamlit webapp using DuckDB

<details><summary>Sequence diagram</summary>

```mermaid
sequenceDiagram
    actor U as User
    participant N as Notion
    box Google Cloud Platform
    participant CS as Cloud Scheduler
    participant CF as HTTP Cloud Function
    participant GCS as Cloud Storage
    participant CR as Cloud Run
    end

    U->>N: Logs in

    U->>N: Modifies or<br>several database
    opt
        U-)CF: Forces run
    end
    loop Hourly
        CS-)+CF: Triggers dlt pipeline
    end

    CF->>+N: Queries all pages in database
    N-->>-CF: Returns all pages
    CF->>-GCS: Stores data as parquet

    U->>+CR: Opens website and query data
    CR->>+GCS: Queries data<br>using DuckDB
    GCS--)-CR: Receives data
    CR-->>-U: Displays queried data
```

</details>

### Triggering Data Ingestion

Manual trigger:

```shell
curl -i -X POST $(terragrunt output function_uri | sed 's/"//g') \
    -H "Authorization: bearer $(gcloud auth print-identity-token)"
```

Force scheduler run:

```shell
gcloud scheduler jobs run $(terragrunt output scheduler_dlt_name | sed 's/"//g') \
    --project=$PROJECT_ID \
    --location=$(terragrunt output scheduler_append_region | sed 's/"//g')
```

### Cleanup

Option 1 - Remove resources except state bucket:

```shell
terragrunt destroy
```

Option 2 - Delete entire project:

```shell
gcloud projects delete $PROJECT_ID
rm -rf .terraform.lock.hcl .terragrunt-cache
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- COST MANAGEMENT -->
## Cost Management

This project stays within GCP's free tier when:

- It's your only active GCP project
- Notion databases are moderate in size (~few thousands rows without images)

Use [Infracost] to estimate costs ([free tier ignored]):

```shell
export TG_DIR=terragrunt/dev/
infracost breakdown --path=$TG_DIR --usage-file=infracost-usage.yml
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ROADMAP -->
## Roadmap

- [ ] Transform the DLT notion pipeline and Streamlit app into OpenTofu modules
- [ ] Create a branch for embedding DLT to Streamlit (removing need for Cloud Storage)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature)`
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

Tucared - <1v8ufskf@duck.com>

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[OpenTofu.org]: https://img.shields.io/badge/OpenTofu-FFDA18?style=for-the-badge&logo=opentofu&logoColor=black
[OpenTofu-url]: https://opentofu.org/
<!-- https://github.com/simple-icons/simple-icons/issues/7650 -->
[Terragrunt.io]: https://img.shields.io/badge/terragrunt-565AE1?style=for-the-badge&logo=terragrunt
[Terragrunt-url]: https://terragrunt.gruntwork.io/
[Python.org]: https://img.shields.io/badge/Python-FFD43B?style=for-the-badge&logo=python&logoColor=blue
[Python-url]: https://www.python.org/
[Streamlit.io]: https://img.shields.io/badge/Streamlit-FF4B4B?style=for-the-badge&logo=Streamlit&logoColor=blue
[Streamlit-url]: https://streamlit.io/
[dltHub.com]: https://img.shields.io/badge/Dlt-C6D300?style=for-the-badge&logo=dlt&logoColor=green
[dlt-url]: https://dlthub.com/

[Notion.so]: https://img.shields.io/badge/Notion-000000?style=for-the-badge&logo=notion&logoColor=white
[Notion-url]: https://www.notion.so/
[Console.cloud.google.com]: https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white
[Google-Cloud-url]: https://console.cloud.google.com

[Notion account]: https://www.notion.so/signup
[Google Cloud billing account]: https://cloud.google.com/billing/docs/how-to/create-billing-account
[gcloud CLI]: https://cloud.google.com/sdk/docs/install
[OpenTofu]: https://opentofu.org/docs/intro/install/
[Terragrunt]: https://terragrunt.gruntwork.io/docs/getting-started/install/

[Create an internal Notion integration]: https://developers.notion.com/docs/authorization#internal-integration-auth-flow-set-up
[Connect the integration to your database]: https://www.notion.so/help/add-and-manage-connections-with-the-api#add-connections-to-pages

[Infracost]: https://github.com/infracost/infracost/tree/master

[free tier ignored]: https://www.infracost.io/docs/supported_resources/google/
