# os-autoinst scripts ![](https://github.com/os-autoinst/scripts/workflows/ci/badge.svg)


## Communication

If you have questions, visit us on IRC in [#opensuse-factory](irc://chat.freenode.net/opensuse-factory)


## How to use

Checkout the individual scripts and either call them manually or automatically, e.g. in CI jobs

### auto-review - Automatically detect known issues in openQA jobs, label openQA jobs with ticket references and optionally retrigger

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

* [openqa-monitor-investigation-candidates](https://github.com/os-autoinst/scripts/blob/master/openqa-monitor-investigation-candidates)
  queries the dabase of an openQA instance (ssh access is necessary) and
  output the list of failed jobs that are suitable for triggering
  investigation jobs on, compare to "openqa-monitor-incompletes"

* [openqa-investigate](https://github.com/os-autoinst/scripts/blob/master/openqa-investigate)
  can take a list of openQA jobs, for example output of
  "openqa-monitor-investigation-candidates" and trigger "investigation jobs",
  e.g. a plain retrigger, using the "last good" tests as well as "last good"
  build


### Combine auto-review and openqa-investigate

A possible approach to combine handling known issues and unknown issues is to
run "openqa-label-known-issues" against all "investigation candidates" and
pass all unknown issues to "openqa-investigate":

```
./openqa-monitor-investigation-candidates | ./openqa-label-known-issues 3>&1 1>/dev/null 2>&3- | sed -n 's/\(\S*\) : Unknown issue, to be reviewed.*$/\1/p' | ./openqa-investigate
```

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
