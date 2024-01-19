# db-operations

Some of these playbooks might be useful to run or serve as operational documentation in environments in which cassandra and elasticsearch are installed on bare VMs (not inside kubernetes). They can be used when:

* you installed cassandra and/or elasticsearch using ansible playbooks contained within wire-server-deploy
* you need to perform some specific maintenance work
* you are comfortable writing or changing ansible playbooks to fit your needs
* you are using ansible version 2.7.x (or possibly 2.9.x). They may no longer work in more recent versions of ansible.

:warning: The playbooks here *were* in use by Wire for our production systems in the past; however we no longer make active use of them, and won't be able to provide much support for them. They are rather intended as a useful starting point by an operator able to write or change their own ansible playbooks and understand what they do.

Here be dragons!

That said, playbooks here can serve (but may not be sufficient, and still require you to understand what you're doing) in the following cases:

- `cassandra_rolling_repair`: cassandra repairs were misconfigured; and you wish to repair all of them before re-activating the repair cron jobs
- `cassandra_restart`: Restart cassandra nodes one by one in a controller, graceful fashion.
- `cassandra_alter_keyspace`: you'd like to perform a cassandra migration to a new datacenter (this is a complicated topic, this playbook is not sufficient)
- `cassandra_cleanup`: you have scaled up the number of cassandra nodes (say from 3 to 6); then this allows you to free some disk space from the original cassandra nodes. Has no effect if there was no cluster topology change.
- `cassandra_(pre|post)_upgrade`: Useful when upgrading cassandra version (e.g. from 3.11 to 4.0)
- `elasticsearch_...` See the name of playbook or comment in the files for their purpose.

While the original playbooks were in use and worked as expected, porting them over to wire-server-deploy causes some changes which have not been tested, so there might be small issues. If you find an issue, feel free to send a PR.
