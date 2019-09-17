# Installing kubernetes on ubuntu

1. log onto a server running ubuntu
2. become root: `sudo su -`
3. Run this init script:

```
curl -sSfL https://raw.githubusercontent.com/wireapp/wire-server-deploy/feature/simple-bootstrap/bin/bootstrap/init.sh > init.sh && chmod +x init.sh && ./init.sh
```
