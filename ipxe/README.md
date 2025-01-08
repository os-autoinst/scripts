These PXE boot files and configs are used on the following hosts:

- `openqa.opensuse.org`
- `qa-jump.qe.nue2.suse.org`
- `netboot.qe.prg2.suse.org`

The git repo is checked out at `/srv/tftpboot/ipxe/os-autoinst-scripts`.

For `qa-jump` and `netboot` it is sufficient to retrigger the latest
deploy pipeline on these gitlab repos to get the git checkout updated.

- https://gitlab.suse.de/qa-sle/qa-jump-configs
- https://gitlab.suse.de/qa-sle/netboot-configs

For `openqa.opensuse.org` you will need to login manually and run
`git pull --rebase` in `/srv/tftpboot/ipxe/os-autoinst-scripts`.
