# os-autoinst scripts ![](https://github.com/os-autoinst/scripts/workflows/ci/badge.svg)


## Communication

If you have questions, visit us on IRC in [#opensuse-factory](irc://chat.freenode.net/opensuse-factory)


## How to use

Checkout the individual scripts and either call them manually or automatically, e.g. in CI jobs

### auto-review - Automatically detect known issues in openQA jobs, label openQA jobs with ticket references and optionally retrigger

Based on simple regular expressions in the subject line of tickets on
progress.opensuse.org within https://progress.opensuse.org/projects/openqav3
or any subproject of it, commonly
https://progress.opensuse.org/projects/openqatests/ , openQA jobs can be
automatically labeled with the corresponding ticket and optionally retriggered
where it makes sense. For this the subject line of a ticket must include text
following the format `auto_review:"<search_term>"[:retry]` with
`<search_term>` being the perl extended regex to search for and an optional
boolean switch `:retry` after the quoted search term to instruct for
retriggering the according openQA job. Example: `auto_review:"error 42
found":retry`. The search terms are crosschecked against the logfiles and
"reason" field of the openQA jobs. A multi-line search is possible, for
example using the `<search_term>` `(?s)something to match earlier.*something
to match some lines further down`. Other double quotes in the subject line
than around the search term should be avoided. Also be careful to not specify
a too generic search term to prevent false matches of job failures unrelated
to the specified ticket.

* [openqa-monitor-incompletes](https://github.com/os-autoinst/scripts/blob/master/openqa-monitor-incompletes)
  queries the database of an openQA instance (ssh access is necessary) and
  output the list of "interesting" incompletes, where "interesting" means not
  all incompletes but the ones likely needing actions by admins, e.g.
  unreviewed, no clones, no obvious "setup failure", etc.
* [openqa-label-known-issues](https://github.com/os-autoinst/scripts/blob/master/openqa-label-known-issues)
  can take a list of openQA jobs, for example output from
  "openqa-monitor-incompletes" and look for matching "known issues", for
  example from progress.opensuse.org, label the job and retrigger if specified
  in the issue (see the source code for details how to mark tickets)

For tickets referencing "auto_review" it is suggested to add a text section based on the following template:

```
## Steps to reproduce

Find jobs referencing this ticket with the help of
https://raw.githubusercontent.com/os-autoinst/scripts/master/openqa-query-for-job-label ,
for example to look for ticket 12345 call `openqa-query-for-job-label poo#12345`
```

### openqa-investigate - Automatic investigation jobs with failure analysis in openQA

openQA can be configured to automatically trigger investigation jobs whenever
there is no carry-over and no automatic ticket assignment by auto-review.

* [openqa-monitor-investigation-candidates](https://github.com/os-autoinst/scripts/blob/master/openqa-monitor-investigation-candidates)
  queries the dabase of an openQA instance (ssh access is necessary) and
  output the list of failed jobs that are suitable for triggering
  investigation jobs on, compare to "openqa-monitor-incompletes"

* [openqa-investigate](https://github.com/os-autoinst/scripts/blob/master/openqa-investigate)
  can take a list of openQA jobs, for example output of
  "openqa-monitor-investigation-candidates" and trigger "investigation jobs",
  e.g. a plain retrigger, using the "last good" tests as well as "last good"
  build and a combination of both. The results of all these four jobs should
  give a pretty good indication if something is a test regression, a product
  regression, an infrastructure problem or a sporadic issue.


### Combine auto-review and openqa-investigate

A possible approach to combine handling known issues and unknown issues is to
run "openqa-label-known-issues" against all "investigation candidates" and
pass all unknown issues to "openqa-investigate":

```
./openqa-review-failed
```

which does the equivalent of:

```
./openqa-monitor-investigation-candidates | ./openqa-label-known-issues | ./openqa-investigate
```

with minor changes to the input/output format used between the commands.

### openQA hook scripts - Call auto-review or investigation steps in openQA after every job is done

openQA supports custom job done hook scripts that can be called whenever a job
is done, see
http://open.qa/docs/#_enable_custom_hook_scripts_on_job_done_based_on_result
for details. For the purpose of being called as these hook scripts here the
following scripts are provided:

* [openqa-label-known-issues-hook](https://github.com/os-autoinst/scripts/blob/master/openqa-label-known-issues-hook)
  calls "openqa-label-known-issues" on the specified job
* [openqa-label-known-issues-and-investigate-hook](https://github.com/os-autoinst/scripts/blob/master/openqa-label-known-issues-and-investigate-hook)
  calls "openqa-label-known-issues" on the specified job and if no label was
  found, "openqa-investigate". Compare to section
  "Combine auto-review and openqa-investigate"


## Contribute

This project lives in https://github.com/os-autoinst/scripts

Feel free to add issues in github or send pull requests.

### Rules for commits

* For git commit messages use the rules stated on
  [How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/) as
  a reference

If this is too much hassle for you feel free to provide incomplete pull
requests for consideration or create an issue with a code change proposal.

### Local testing
#### openqa-label-known-issues
Generate a list of recent incomplete jobs of your local openQA instance. Here's an example using `psql`:

```
psql \
 --dbname=openqa-local \
 --command="select concat('http://localhost:9526/tests/', id, ' ', TEST) from jobs where result = 'incomplete' order by t_finished desc limit 10;" \
 --csv \
 | tail -n +2 > tests/local_incompletes
```

Perform a dry run on the local instance using the generated job list:
```
cat tests/local_incompletes | env scheme=http host=localhost:9526 dry_run=1 sh -ex ./openqa-label-known-issues
```

## License

This project is licensed under the MIT license, see LICENSE file for details.
