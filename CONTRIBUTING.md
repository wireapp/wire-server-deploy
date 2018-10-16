# Introduction

Thank you for considering contributing to the deployment options of wire-server.

This is an open source project and we are happy to receive contributions! Improvements to our helm charts or documentation, submitting bugs or issues about e.g. possible incompatibilities or problems using different versions or hosting on different platforms; or alternative ways of how you installed wire-server are all valuable. 

## Guidelines

*Before we can accept your pull request, you have to sign a [CLA](https://cla-assistant.io/wireapp/wire-server)*

If submitting pull requests, please follow these guidelines:

* if you want to make larger changes, it might be best to first open an issue to discuss the change.
* if helm charts are involved, 
    * use the `./bin/update.sh <chart-name>` script, to ensure changes in a subchart (e.g. brig) are correctly propagated to the parent chart (e.g. wire-server) before linting or installing.
    * ensure they pass linting, you can check with `helm lint -f path/to/extra/values-file.yaml charts/mychart`. 
    * If you can, try to also install the chart to see if they work the way you intended.

If you find yourself wishing for a feature that doesn't exist, open an issue on our issues list on GitHub which describes the feature you would like to see, why you need it, and how it should work.

Since our team is fairly small, while we try to respond to issues and pull requests within a few days, it may in some cases take up to a few weeks before getting a response.
