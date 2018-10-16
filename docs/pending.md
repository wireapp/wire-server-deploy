### Referencing helm charts from this repo

After [this issue](https://github.com/hypnoglow/helm-s3/issues/45) is solved, charts can be referenced publicly. Currently, this does not work. Instead, you'll need to checkout this repo and run `./bin/update.sh <chart-name>` for each chart before use.

<!--

For the below commands, ensure you enabled the `wire` helm chart repository:

```
helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
helm repo update
```

Then you should be able to

```
helm search wire
```

-->
