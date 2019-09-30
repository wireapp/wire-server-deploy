# Instroduction

This is an experimental easy-to-type bootstrap procedure (from ubuntu to a kubernetes cluster - could be extended, possibly). This downloads a bash script which downloads a docker alternative (since kubespray removes any running docker image during installation), and uses that to run the quay.io/wire/networkless-admin image. Within that image, it creates a host file and uses that to install kubernetes to the host system.

# Status: experimental, may not work for you

# Procedure for installing kubernetes on ubuntu

1. log onto a server running ubuntu
2. become root: `sudo su -`
3. Run this init script:

```
curl -sSfL https://raw.githubusercontent.com/wireapp/wire-server-deploy/develop/bin/bootstrap/init.sh > init.sh && chmod +x init.sh && ./init.sh
```
