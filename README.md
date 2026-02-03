# GitHub Workflow - AutoDoc

Workflow to update docs based on workflow or actions parameters.

It uses github-action [nrkno/github-action-action-workflow-autodoc](https://github.com/nrkno/github-action-action-workflow-autodoc) to generate documentation

<!-- start -->
## GitHub Workflow - AutoDoc

### Required Inputs

|Input name|Description|Type|Default|
|---|---|---|---|
|**runs-on**|Runs on, e.g. ubuntu-latest. <br>make sure to enclose in single quotes `'` if using a list:<br>`'["self-hosted", "Linux"]'`<br>|string|`ubuntu-latest`|
|**workflow_file**|Path to the workflow file to document|string|`action.yaml`|
|**doc_file**|Path to the markdown file to update with documentation|string|`README.md`|

### Optional Inputs

|Input name|Description|Type|Default|
|---|---|---|---|
|**start_token**|Token marking the start of the autodoc section|string|`<!-- autodoc start -->`|
|**end_token**|Token marking the end of the autodoc section|string|`<!-- autodoc end -->`|
|**table**|Format inputs as a markdown table|string|`false`|
|**debug**|Print debug messages. 0=none, 1=some, 2=more, 3=all|string|`0`|


### Outputs

|Output name|Description|
|---|---|
|autodoc_out|If enabled, the generated documentation for inputs, secrets, and outputs|
|autodoc_type|The type automaticly detected by the script of the input_file documented: workflow or action|

### Simple example usage (using steps 'uses' syntax)

```yaml
---
name: workflow-example
on:
  pull_request:

jobs:
  example-job:
    steps:
      - name: example job
        id: example_step
        uses: nrkno/github-workflow-action-workflow-autodoc/.github/workflows/workflow.yaml@main
        with:
          runs-on: 'ubuntu-latest'
          workflow_file: 'action.yaml'
          doc_file: 'README.md'
```

### Full example usage (using steps 'uses' syntax)

```yaml
---
name: workflow-example
on:
  pull_request:

jobs:
  example-job:
    steps:
      - name: example job
        id: example_step
        uses: nrkno/github-workflow-action-workflow-autodoc/.github/workflows/workflow.yaml@main
        with:
          runs-on: 'ubuntu-latest'
          workflow_file: 'action.yaml'
          doc_file: 'README.md'
          start_token: '<!-- autodoc start -->'
          end_token: '<!-- autodoc end -->'
          table: 'false'
          debug: '0'
```


<!-- end -->
