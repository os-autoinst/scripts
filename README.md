# os-autoinst scripts ![](https://github.com/os-autoinst/scripts/workflows/ci/badge.svg)


## Communication

If you have questions, visit us on IRC in [#opensuse-factory](irc://chat.freenode.net/opensuse-factory)


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
