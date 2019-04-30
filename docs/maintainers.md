# Maintainers of wire-server-deploy

Apart from the usual development setup, you'll additionally need [yq](https://github.com/mikefarah/yq) on your PATH.

For local development, instead of `helm install wire/<chart-name>`, use

```
./bin/update.sh <chart-name> # this will clean and re-package subcharts
helm install charts/<chart-name> # specify a local file path
```

## ./bin/sync.sh

This script is used to mirror the contents of this github repository with S3 to make it easier for us and external people to use helm charts. You may need to run that manually after bumping versions.
