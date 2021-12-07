# How to upgrade wire (SFT only)

You should have received a deployment artifact from the Wire team in order to upgrade your SFT calling service.

Your deployment artifact contains three things: the new chart, the new values file, and an image for sftd.

## Uploading the Image into Kubernetes hosts

The image needs to be imported with 'docker load' on each of the kubernetes hosts.

Copy the sft image to the kubernetes hosts, and docker load it on each of the kubernetes hosts.

To load into docker as root, you can "cat quay.io_wire_sftd_2.1.19.tar | docker load". If you are using a non-priviledged user, and sudo (wire's recommendation), you can use:

```
sudo bash -c "cat quay.io_wire_sftd_2.1.19.tar | docker load"
```

## Replacing your SFT Chart

Move your sft/ chart out of the charts folder in the workspace where you're working with wire, and replace it wit the one in the deliverable. Keep this, in case you need to step back.

## Examining your Values

Examine the values file we've provided, comparing it to the one you used when last deploying SFT. Make sure there are no changes to make with the new chart. If there are changes to make, make a backup copy before you make changes!

## Deploying:

Use helm install --upgrade in the same fashion as the installation process guided you through.

## Verifying your deployment was successful:

In the web client, place a call, and then go to 'gear icon' -> Audio / Video -> and then to 'Save the calling debug report'.
When you read that file, search for a line that starts with "a=tool:sftd". that has your sft server version on it.

# How to step back, if this has made things worse:

Just move your old SFT chart and values file back into place, and use helm uninstall, and then helm install.

