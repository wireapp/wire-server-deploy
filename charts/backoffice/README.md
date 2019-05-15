Backoffice frontend
===================

This chart provides a basic frontend app that is composed of nginx serving swagger and will soon be found here [here](https://github.com/wireapp/wire-server/blob/develop/tools/backoffice-frontend/README.md). It serves as a tool to perform operations on users and teams such as visualising their user profiles, suspending or even deleting accounts. It is used internally at Wire to provide customer support the means to respond to certain queries from our customers and can be used by anyone that decides to deploy it on their cluster(s).

It is intended to be accessed, at the moment, only by means of port forwarding and therefore only available to cluster admins (or more generally, clusters users able to port forward).

:warning: **DO NOT expose this chart to the public internet** with an ingress - doing so would give anyone the ability to read part of the user database, delete users, etc.

Once the chart is installed, and given default values, you can access the frontend with 2 steps:

 * kubectl port-forward svc/backoffice 8080:8080
 * Open your local browser at http://localhost:8080
