# Notion Budget Tracker

Budget tracker levering [Notion](notion.so) as expense recorder, and Google Cloud Platform for transformation and visualisation.

- The **User** manually logs each expense as a [Page](https://developers.notion.com/reference/page) in a [Notion database](https://developers.notion.com/reference/database), as it happens
- Either the User, or the **Cloud Scheduler**, calls a private **HTTP Cloud Function** (`notion-to-bigquery`) to extract new and updated Pages from said Notion database, then load (upserts) them into a **BigQuery** native table
- A **Looker Studio** report provides visualisations based on BigQuery views

```mermaid
sequenceDiagram
    actor User
    participant Notion
    participant Cloud Scheduler
    participant HTTP Cloud Function
    participant BigQuery
    participant Looker Studio

    User->>Notion: Logs expenses

    rect rgb(0, 255, 255)
        note right of User: Extract and load pipeline
        alt manual
            User-)+HTTP Cloud Function: Triggers
        else according to schedule
            Cloud Scheduler-)+HTTP Cloud Function: Triggers
        end
        HTTP Cloud Function->>Notion: Queries expenses
        Notion--)HTTP Cloud Function: Returns expenses
        loop if new or updated expenses
            HTTP Cloud Function->>-BigQuery: Upserts expenses
        end
    end

    User->>Looker Studio: Asks for visualisations
    Looker Studio->>BigQuery: Queries aggregated data
    BigQuery--)Looker Studio: Returns aggregated data
    Looker Studio--)User: Provides visualisations
```
<details>
<summary>Draft documentation
</summary>

## Example project 

- Add Notion example database
- Add Looker Studio example report

## Setting up tool

### Notion

- Duplicate template page
- Get database ID
- Create API key
- Store key in Google Secret Manager

### Extract and load pipeline

- Create google cloud platform project
- Create service account

**HTTP Cloud Function**

- Create BigQuery dataset and table, and define in env vars
- Deploy and test function locally
- Deploy and test functions remotely

**Cloud Scheduler**

- Create and test a schedule locally ([instructions](https://cloud.google.com/community/tutorials/using-scheduler-invoke-private-functions-oidc))
- Create and test a schedule remotely

### Looker Studio

- Duplicate template report
- Change data source to your own BigQuery

</details>