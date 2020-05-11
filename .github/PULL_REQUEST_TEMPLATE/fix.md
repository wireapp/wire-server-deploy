---
name: Fix (PR)
about: template for a PR that fixes an issue 
title: "FIX: [FIX NAME]"
labels: 
assignees:
---

Technology (Ansible, Helm, Terraform):

Fixes # ${ISSUE_ID}


### How  did you fix the issue?

TODO


### Why did you fix it this way?

TODO


### Checklist:

Please tick the following before handing in your PR:

* [ ] I ran `ansible-playbook` and it succeeded without any failure.
* [ ] I ran `helm install/upgrade` and it went through with every pod being either `Running` or `Completed`.
* [ ] I ran `terraform apply` and the expected stage was reached.
