<!-- In case this addressed an existing issue 
Fixes ${ISSUE_URL}
-->

### Change type

<!-- choose the kind of change this PR introduces -->

* [ ] Fix
* [ ] Feature
* [ ] Documentation
* [ ] Security / Upgrade

### Basic information 

* [ ] THIS CHANGE REQUIRES A DEPLOYMENT PACKAGE RELEASE
* [ ] THIS CHANGE REQUIRES A WIRE-DOCS RELEASE

### Testing

* [ ] I ran/applied the changes myself, in a test environment.
* [ ] The CI job attached to this repo will test it for me.

#### Offline Build CI (label-based)
Add one or more labels to trigger offline builds:
- `build-default` - Full production build (ansible, terraform, all packages)
- `build-demo` - Demo/WIAB build
- `build-wiab-staging` - WIAB-staging build
- `build-min` - Minimal build (fastest, essential charts only)
- `build-all` - Run all three builds

**Note:** No builds run by default. Add a label to trigger CI.

### Tracking

* [ ] I added a new entry in an appropriate subdirectory of `changelog.d`
* [ ] I mentioned this PR in Jira, OR I mentioned the Jira ticket in this PR.
* [ ] I mentioned this PR in one of the issues attached to one of our repositories.

### Knowledge Transfer
* [ ] An Asciinema session is attached to the Jira ticket.

### Motivation

<!--
What is the motivation for introducing this change?
Which scenario(s) is/are addressed by the change?
What problem does the change try to solve? 
-->


### Objective

<!--
What kind behaviour does it change, add, or remove?
How did it behave before? How does it behave now? 
-->


### Reason

<!--
How did you fix the issue?
Why did you solve it this way? 
-->


### Use case

<!--
How is the change used? maybe share some example code.
Does the change introduce any incompatibility?
-->
