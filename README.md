# github-workflow-setenv

Set environment.

<!-- autodoc start -->
## GitHub Workflow - AutoDoc

### Required Inputs

|Input name|Description|Type|Default|
|---|---|---|---|
|**runs-on**|Runs on, e.g. ubuntu-latest|string|`unknown`|
|**workflow_file**|Path to the workflow file to document|string|`unknown`|
|**doc_file**|Path to the markdown file to update with documentation|string|`unknown`|

### Optional Inputs

|Input name|Description|Type|Default|
|---|---|---|---|
|**start_token**|Token marking the start of the autodoc section|string|`None`|
|**end_token**|Token marking the end of the autodoc section|string|`None`|
|**table**|Format inputs as a markdown table|string|`None`|
|**github_output**|Print documented inputs, secrets, and outputs to GitHub Action outputs|string|`None`|
|**debug**|Print debug messages. 0=none, 1=some, 2=more, 3=all|string|`None`|



### Simple example usage

```yaml
---
name: workflow-example
on:
  pull_request:

jobs:
  example-job:
    name: example job
    uses: nrkno/github-workflow-action-workflow-autodoc/.github/workflows/workflow.yaml@main
    secrets: inherit
    with:
      runs-on: `<value>`
      workflow_file: `<value>`
      doc_file: `<value>`
```

### Full example usage

```yaml
---
name: workflow-example
on:
  pull_request:

jobs:
  example-job:
    name: example job
    uses: nrkno/github-workflow-action-workflow-autodoc/.github/workflows/workflow.yaml@main
    secrets:
    with:
      runs-on: `<value>`
      workflow_file: `<value>`
      doc_file: `<value>`
      start_token: `<value>` # Optional
      end_token: `<value>` # Optional
      table: `<value>` # Optional
      github_output: `<value>` # Optional
      debug: `<value>` # Optional
```


<!-- autodoc end -->
