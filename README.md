# NAME

clone

# USAGE

    clone hostname [ info | build | verify | verify! | update | update! ]

# DESCRIPTION

This program assembles and overlays multiple directory trees onto remote
servers using `rsync`. It makes it easy to build something once and ensure
that it gets deployed to multiple locations exactly as intended. Use it to
control things in `/srv/www` or `/usr/local` or even `/etc`.

For example, say you want to compile Perl once and just deploy it to your
servers but man are RPMs and debs annoying. So you compile it on a build host,
tar it up, then plop it into `/clone/sources/perl-5.20.3`. Alongside that you
have `/clone/sources/perl-support` which has things like symlinks for
`/usr/local/bin/perl` so that the next time you don't need to remember to
recreate all the symlinks and generic configuration files after building the
new version of Perl. So you write:

    PERL = {
        software/perl-support
        PERL-5.20.3 = {
            software/perl-5.20.3
        }
    }

And then configure it to go to all of your hosts:

    COMMON_SOFTWARE = {
        $PERL-5.20.3
        $PYTHON-2.7.10
        $PYTHON-3.4.3
    }

And then you configure each host:

    FOO_NS = {
        common/local
        $COMMON_BASE
        $COMMON_SOFTWARE
    }

    _HOSTS_ = {
        foo/r~ [debian8 @foo.example.org] = $FOO_NS
    }

And then you deploy to your hosts and then each host gets exactly the same
version of everything installed on it. And if someone goes messing with Perl on
one of your hosts then those changes will get rolled back the next time the
host is updated. So you can guarantee that you've put everything on the host
that needs to be there and that only what you put there is what remains.

# ARGUMENTS

- hostname

    The name of the server to perform actions against. This name comes from the
    hosts configuration file.

- action

    The action to perform on the given host. This can be one of the following:

    - info

        Shows what sources make up the host.

    - build

        This will compile all of the pieces together to build what will be sent to a
        host.

    - verify

        This will compile all of the pieces together to build what will be sent to a
        host and then verify the list of changes that will be made to the host. No
        changes are actually made.

    - verify!

        This will skip the build component and just verify the list of changes that
        will be made to the host based on the last build. No changes are actually made.

    - update

        This will compile all of the pieces together to build what will be sent to a
        host and then send the changes to the host. **WARNING** This will make changes
        to the remote host!

    - update!

        This will skip the build component and send the changes to the host based on
        the last build. **WARNING** This will make changes to the remote host!

# OPTIONS

- -q|--quiet|--no-quiet

    This will quiet things down. Warnings will not be shown. The default is to show
    warnings when connected to a terminal and not show warnings when connected to
    something other than a terminal such as a pipe. Warnings can be shown when not
    connected to a terminal by using `--no-quiet`.

- -p|--paranoid

    Enable rsync checksums. Normally rsync will determine whether to update a file
    by comparing the file size and the modification time of the local and remote
    file. This flag will instead use the MD5 of the local and remove file. Using
    this flag will make rsync run signficantly longer.

- -f|--force

    Force an update to the remote host. For example, if the host has the `X` flag
    set in the hosts configuration file then the host will only be updated if
    forced.

- -c|--console

    Logs are written to the logs directory for all build, verify, and update
    actions. If this flag is set then the logs will also be simultaneously written
    to the console.

- -h|--help

    Shows this message.

# PREREQUISITES

There is one specific external software prerequisite. You must have rsync
version 3.1.0 or greater installed on the master and all slaves. Some of the
options used by this program depend upon that version to ensure that files are
copied to slaves in the most accurate way.

# INSTALLATION

Installation should be done as root. If it's not then the clone program will
not be able to do things like change file ownership. Thus, all the below
commands should be run as root.

## ON ALL SERVERS

It is assumed that your hosts restrict SSH connections from root. Based on that
assumption, a user needs to be created on all systems to initiate the SSH
connection over which rsync will run. This should be the same user on all
systems and the user should have the same user and group id on all systems.
For example:

    addgroup --gid 123 --system ref
    adduser --uid 123 --system --home /usr/local/ref --disabled-password --shell /bin/bash --ingroup ref ref

The user needs to be able to run rsync on the remote host through sudo. This is
complicated by the way rsync works when it calls itself on the remote host. To
work around this we are going to set an effective alias for rsync to force it
to run through sudo. To that end, set the user's `/usr/local/ref/.bashrc` file
like this:

    rsync() (
       /usr/bin/sudo /usr/bin/rsync $@
    )

The user should be allowed to use sudo to run rsync and the post-processing
program like this by creating `/etc/sudoers.d/ref` and putting this in it:

    Cmnd_Alias REF=/usr/bin/rsync, /usr/local/bin/rsync, /usr/local/ref/tools/process-updates
    ref ALL=NOPASSWD:REF

Ensure some file permissions are updated:

    chown ref:ref /usr/local/ref/.bashrc
    chmod 0440 /etc/sudoers.d/ref

## ON MASTER SERVER

All files need to have their permissions updated:

    mkdir /usr/local/ref/.ssh
    chown ref:ref /usr/local/ref/.ssh
    chmod 700 /usr/local/ref/.ssh

SSH keys need to be created:

    ssh-keygen -b 4096 -N "" -f /usr/local/ref/.ssh/id_rsa
    chown ref:ref /usr/local/ref/.ssh/id_rsa*
    cp /usr/local/ref/.ssh/id_rsa.pub /usr/local/ref/.ssh/authorized_keys
    chown ref:ref /usr/local/ref/.ssh/authorized_keys
    chmod 600 /usr/local/ref/.ssh/authorized_keys
    cp /usr/local/ref/.ssh/id_rsa* /root/.ssh/

Note on the master server that the SSH keys for `ref` should be the same as
`root` on the or things will not work. The public SSH key needs to be sent to
the cloned servers:

    scp -p /usr/local/ref/.ssh/authorized_keys joe@clone:/tmp

## ON ALL CLONED SERVERS

The public SSH key needs its permissions updated:

    mkdir /usr/local/ref/.ssh
    chown ref:ref /usr/local/ref/.ssh
    chmod 700 /usr/local/ref/.ssh
    mv ~joe/authorized_keys /usr/local/ref/.ssh/
    chown ref:ref /usr/local/ref/.ssh/authorized_keys
    chmod 600 /usr/local/ref/.ssh/authorized_keys

## ON MASTER SERVER

The application does not need to be installed like a regular Perl module. All
that needs to be done is to copy the program where you want it and run it.

# CONFIGURATION

## config.ini

A configuration file in `/conf/config.ini` needs to exist. This defines basic
functionality of the clone program. There are no required options. Options in
this file are defined simply as `foo = bar`. Any line in this file beginning
with a # (hash) will be ignored as a comment.

Here is an example of a configuration file:

    user = ref
    home = /usr/local/ref

    [runner]
    ssh = /usr/bin/ssh
    rsync = /usr/local/bin/rsync
    sudo = /usr/bin/sudo

    [paths]
    sources = /clone/sources
    builds = /clone/builds
    logs = /clone/logs
    tools = /clone/tools

Here is an explanation of each option:

- user

    This defines the unprivileged user over which all SSH connections will be made.
    The default is to connect as user `ref`.

- home

    This defines the path to the unprivileged user's home directory on the remote
    server. The default is `/usr/local/<user>`.

- key

    This defines the path to the private SSH key for the unprivileged user over
    which all SSH connections will be made. The default is
    `<home>/.ssh/id_rsa`.

- ssh

    This is the path to the SSH client. The default is `/usr/bin/ssh`.

- rsync

    The path to the rsync client. The default is `/usr/bin/rsync`.

- sudo

    The path to the sudo program. The default is `/usr/bin/sudo`.

- sources

    This is the path to the source trees. The default is to look in the `sources`
    directory found in `$FindBin::RealBin/../`.

- builds

    This is the path where all of the trees will be assembled for each host. The
    default is to use the `builds` directory found in `$FindBin::RealBin/../`.

- logs

    This is the path where log files will be stored on each run. The default is to
    write logs to the `logs` directory found in `$FindBin::RealBin/../`.

- tools

    This is the path to tools that need to be deployed to each host. Anything found
    in the path defined here will be deployed to `<home>/tools`. The
    default is to use `$FindBin::RealBin/../`.

## hosts

A configuration file in `/conf/hosts` also needs to exist. This configuration
file defines which sources to go which hosts. This file can be thought of to be
a programming language of its own containing variables and definitions.
Variables can reference other variables to build composites.

Variables and definitions are expanded lazily so order should not matter. There
is only one required variable: `_HOSTS_`. This contains the definitions of all
hosts and which sources they will receive. For example:

    _HOSTS_ = {
        foo/r [debian8 @foo.example.com] = $BAR_DEBIAN8_NS
        bar/r [debian7 @bar.example.com] = $BAR_DEBIAN7_NS
    }

The format of each line in the hosts definition can be read:

    name/flags [platform @fqdn] = $VAR

There are several parts to this defintion:

- `name`

    This is the name that will be used to refer to the host. This is used when
    calling `clone`, like this: `clone name build`.

- `flags`

    These are flags for the host. The list of flags may contain nothing. There are
    also two options for flags that affect how hosts are updated:

    - `X`

        If this flag is set then the host is disabled and neither a verify nor an
        update is allowed without the use of the `--force` flag.

    - `~`

        Normally this program will effectively take control of the entire file system
        for a host and any file that is neither excepted nor controlled by `clone`
        will be removed from the host. If this flag is set then only an "overlay" will
        be done and no files will be removed from the remote host by default. If you
        set this flag but want to selectively choose certain directories that _are_
        controlled entirely by `clone` then you can use the `directory` option in a
        filter for the host.

- `platform`

    This is the type of platform on which the host runs. This can be any arbitrary
    string but it is used to automatically load a source tree based on the platform
    and host name. For example, if the platform is `debian8` and the hostname is
    `foo` then the source tree `debian8/foo` would automatically be added to the
    list of source trees.

- `fqdn`

    This is the fully qualified domain name of the host. This will be looked up in
    DNS during compilation of the hosts configuration file so it had better resolve
    to something or your hosts file will not compile correctly.

Finally, `$VAR` is the variable that defines the sources that will comprise
the host. To create variables to build a host one can start easy with something
like:

    FOO_DEBIAN7_NS = foo/bar

This would build the host `ref` with files from `foo/bar`. To create a more
complex definition one can include multiple values in a variable with something
like this:

    FOO_DEBIAN7_NS = {
        foo/bar
        common/asdf
        common/test
    }

This would combine all files from each `foo/bar`, `common/asdf`, and
`common/test`. One could also include variables instead. For example, the
following is functionally equivalent to the previous example:

    FOO = foo/bar
    REF_DEBIAN7_NS = {
        $FOO
        common/asdf
        common/test
    }

As a shortcut, a parenthetical can be added after the variable definition and
this will postfix whatever is in the parenthetical to the value. Again, this
example would be functionally equivalent to the two previous examples:

    FOO = foo/bar
    REF_DEBIAN7_NS (asdf) = {
        $FOO
        common/
        common/test
    }

Multiple arguments could be provided in the parenthetical as well. The next
example would be _almost_ functionally equivalent to the three previous
examples:

    FOO = foo/bar
    REF_DEBIAN7_NS (asdf test) = {
        $FOO
        common/
    }

However while previous example will search for `common/asdf` and
`common/test`,  `$FOO` will not be expanded to include either `asdf` or
`test`.

Variables can also be embedded in other variables, too. For example:

    FOO = {
        common/asdf
        BAR = {
            common/test
        }
        BAZ = common/fdsa
    }

The previous example would be functionally equivalent to:

    FOO = {
        common/asdf
    }

    BAR = {
        $FOO
        common/test
    }

    BAZ = {
        $FOO
        common/fdsa
    }

Finally, using the directory expansion does apply to embedded variables. For
example:

    FOO (bar) = {
        common/
        FOO_BAZ = baz/
        FOO_BAT = bat/
    }

The previous example would be functionally equivalent to:

    FOO = {
        common/bar
    }

    FOO_BAZ = {
        common/bar
        baz/bar
    }

    FOO_BAT = {
        common/bar
        bat/bar
    }

# FILTER FILES

The default configuration is to copy all files to the remote host and remove
any files that aren't controlled by `clone`. You can configure a host such
that files that aren't controlled by `clone` aren't removed by setting the
`~` flag in the hosts configuration file. This can also be changed or more
finely controlled by putting filter files into the root of source trees.

The filter file should be named with the format `filter.foo` where `foo` can
be anything as long as it is unique among all source directories that comprise
a host. An example file name might be `/clone/sources/common/asdf/filter.foo`.

There are five sections that can be used in a filter file.

- =directory

    This defines directory paths that will be kept synchronized on the host. That
    means that when a host is updated then anything under the directory that is not
    found in the host's sources on the master will be removed from the host. This
    section means nothing unless the host has the `~` flag set because the default
    configuration for `clone` is such that every directory will be kept fully
    synchronized.

- =except

    This defines things to exclude from being synced on both the source and the
    destination. That means that paths in this section won't be removed from the
    destination and they won't be sent from the master to the host. The pattern
    should match the acceptable formats for `rsync`. There is no guaranteed order
    to how these will be put into the filters.

- =perishable

    This defines things to exclude from removing but that will be removed if they
    are the last thing in a directory and are preventing the directory from being
    removed. The same applies here that applies to `except`: the pattern should
    match the acceptable formats for `rsync` and there is no guaranteed order to
    how these will be put into the filters.

- =command `keyword`

    For all of the paths under this section, if any of them change, the script
    named `keyword` will be run at the end of the update. An environment variable
    named `FILES` will be passed to the script containing a list of all files that
    triggered the script, delimited with a colon.

    The actual programs can be found under `/tools/scripts`. Everything under
    `/tools` will be deployed to all remote hosts under `<home>/tools`.

    As an example, if it this were configured:

        =command foobar
            /foo/bar/.*

    Then anything under the path `/foo/bar/` that changes will cause the program
    named `<home>/tools/scripts/foobar` to be called when updates are
    finished.

An example filter file might look like this:

    =directory
        /srv

    =except
        /srv/foobar
        .*/.toprc

    =command bind
        /etc/bind/.*

The above example will synchronize all files in `/srv` and remove files on the
host that weren't found in the configured sources, except `/srv/foobar` which
will be left in place if found. Additionally, if any file is matched by the
regular expression `/etc/bind/.*`, such as `/etc/bind/named.conf.local` or
`/etc/bind/named.conf.options` for example, then the program called `bind`
found in `<home>/tools/scripts` will be run.

# CREDITS

This project is based on a system called "ref" used by the University of
Washington's Information Technology department. The code you see here has been
developed by Paul Lockaby and Eric Horst.
