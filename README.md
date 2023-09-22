<h1 align="center">
  WordPress@EPFL: the development environment
</h1>

> In this repository you will find everything a developer needs to get started or 
participate in wordpress development at EPFL. Concisely, it will brings the dev
> and ops part of the development stack to your laptop.

# Installation and usage

## Prerequistes

The prerequisites are a *nix operating system with Git and Docker (or
WSL; a “plain Windows®” clone made with e.g. git bash will **not**
work).

If you want to be able to push your changes to production or otherwise
operate the [wp-ops](https://github.com/epfl-si/wp-ops) repository,
you will need to install [Keybase] and obtain membership to the
relevant teams. Some of these tasks need [eyaml], but this can be
handled by the [Ansible suitcase].

## Initial setup

1. Clone the [wp-dev] repository. <br> ⚠ A “plain” Git clone on a
   Windows® filesystem will **not** work, because shell scripts are
   not executable in such an environment.

From here you can either choose to fetch the *whole stack* (meaning you have 
access to the secrets and the EPFL network) or choose the *minimal install*.

1. Minimal installation can be acheived with  
   `make checkout MINIMAL=1`.

For the complete install (which will get all the plugins and themes), follow
theses steps:

*  If you don't have `eyaml` version 3.2.0 on your system, you need first to
   run `make wp-ops` (which will clone the [wp-ops] repository) and launch the
   `wpsible` command to initialize the [Ansible suitcase]: from the `wp-ops`
   directory, run `./ansible/wpsible --check`.
*  If you have `eyaml` version 3.2.0, jump to the next step.

1. Run `make checkout` to download and setup all the required codebases.
1. Edit your `/etc/hosts` or platform equivalent and set up a line like this:  
   `127.0.0.1       wp-httpd`
1. Type `make` to bring up the development stack.  
   💡 If working outside EPFL and/or without VPN access, use instead  
   `make MINIMAL=1`
1. Type `make exec` to enter the so-called management container.
1. Have [nvm](https://github.com/nvm-sh/nvm) installed and type `make gutenberg`
   to start using the [wp-gutenberg-epfl] plugin.


## Populate the serving tree

> :warning: These options are intended to be executed by people who have access
   to team's secrets and EPFL network.

### Copy from production

This is the easiest way, as you get all the DB, without the media. Assuming you 
have production access, from outside the container, run  
`export WP_VERSION=6 && ./devscripts/copy-enac-from-prod.sh`  
(Change `WP_VERSION` value if you import a different site version)

It will to copy a subset of the production serving tree of `www.epfl.ch` into 
your wp-dev checkout:
- https://wp-httpd/
- https://wp-httpd/schools
- https://wp-httpd/schools/enac
- https://wp-httpd/schools/enac/education

Then you can, optionally, run `./devscripts/customize-local-sites.sh`. You will 
be asked if you want to activate debug mode or get back to standard 
authentification on the copied sites.

### Empty site

This is more difficult, as the sites created in this way are initially “bare”
(they lack symlinks to the plugins, must-use plugins and themes; and they are
devoid of configuration and data).

1. Enter the management container (see above), then create one or
   more sites under `/srv/${WP_ENV}/wp-httpd/htdocs` using either
   the `wp` command-line tool (for a “vanilla” WordPress site) or the
   [`new-wp-site.sh`] command (such a site comes with a number of EPFL-specific
   presets, main theme disabled etc.)
1. Install and activate the EPFL theme with the following command:  
   `wp theme install --activate wp-theme-2018`
1. Browse the site. You should now see a working EPFL theme, and a “raw” 
   WordPress without plugins.
1. If required, you can install additional plugins with the  
   `wp plugin install --activate pluginName`  
   command.

### Restore from a backup

Another option is to user the [local-restore-from-restic.sh] script which will
restore a site from its S3 backups (files and database). From the `devscripts` 
directory of this repo, run (for instance):
```bash
SITE_ORIGINAL_URL=https://www.epfl.ch/campus/services/website/canari-wpforms/ \
SITE_ANSIBLE_IDENTIFIER=www__campus__services__website__canari_wpforms \
RESTORED_SITE_DIR_NAME=canari-wpforms \
./local-restore-from-restic.sh
```


## Access the admin area

1. Tack `/wp-admin` to the end of the URL to get at the login screen
1. Log in with the `administrator` account (scroll back in your Terminal looking for `Admin password:` to get at the password)
1. Because of production-specific reverse-proxy shenanigans, you will be redirected to port 8443 at some point. Just edit the URL to get rid of the `:8443` part.


## Day-to-day operations

1. Type `make checkout up`
1. Hack on things
1. Additional helpful commands are: `make exec`, `make httpd` and more (try
   `make help` for an overview)

### Apache access and error logs

To follow the Apache access and error logs, type (respectively)
```bash
make tail-access
make tail-errors
```

In addition, you can use
```bash
make logs
make lnav
make tail-sql
```

### Debugger

Once the Docker containers are up and running, type
`./devscripts/php-xdebug start` to turn on debugging using
[Xdebug](https://xdebug.org/docs/remote#starting).

(When you are done with debugging, type `./devscripts/php-xdebug stop`)

⚠ The first run of `./devscripts/php-xdebug start` needs to download
and install some support software into the `wp-httpd` container.

#### IDE configuration and path mapping

Your debugger or IDE must be listening for incoming Xdebug connections
on port 9000. Additionally, the debugger should be set up to understand that the paths it receives (from inside the `wp-httpd` container) differ from the ones that is sees (outside the container). This is known as **path mapping**.

- Visual Studio Code with [PHP Debug](https://marketplace.visualstudio.com/items?itemName=felixfbecker.php-debug) extension
    - Set your `wp-dev/.vscode/launch.json` to
    <pre>{
      "version": "0.2.0",
      "configurations": [
          {
              "name": "Listen for XDebug",
              "type": "php",
              "request": "launch",
              "port": 9000,
              "pathMappings": {
                  "/wp": "${workspaceRoot}/volumes/wp"
                }
          }
      ]
    }
    </pre>

- PHPStorm / IntelliJ
  - [Additional instructions to configure PHPStorm / IntelliJ](https://www.jetbrains.com/help/idea/configuring-xdebug.html)

💡 If your IDE breakpoints don't quite work because of path mapping issues,
try inserting the following line in an appropriate place in your
PHP code (instead of clicking in the IDE to set up breakpoints):<pre>xdebug_break();</pre>

### Indexation (ctags / etags)

If you are a ctags / etags user, type `make tags` resp. `make TAGS` to
index the checked out sources (including the core of WordPress and the
third-party plugins).

### Acceptance tests

To run the acceptance tests in their developer-friendly ("unpacked")
incarnationagainst the local development environment, using a browser
that is re-used across test runs, do<pre>
cd docker/acceptance
npm i
./bin/run-chrome
</pre>

and follow the instructions that appear on-screen.

To build and run the same in the "canned" version (the one that runs
within the Jenkins pipeline) try<pre>
cd docker/acceptance
npm run docker --  --screenshot-always
</pre>

### Database access

The development environment provides a
[PHPMyAdmin](https://www.phpmyadmin.net/) instance on
http://localhost:8080/ . The database host is "db"; the user and
password are in the `.env` file, as the values of the
`MYSQL_SUPER_USER` and `MYSQL_SUPER_PASSWORD` variables, respectively.

As far as command-line access is concerned, you can access a superuser
MySQL prompt by typing
```bash
docker exec -it wp-local_db_1 bash -c 'mysql -p$MYSQL_ROOT_PASSWORD'
```

and you can activate and follow the generate query log with
```bash
make tail-sql
```

### Reset administrator password

1. Enter the so-called “management” container with <pre>make exec</pre>
2. Type the following commands (💡 change the password as you please):<pre>
cd /srv/test/wp-httpd/htdocs/
wp user update admin --user_pass=tototutu1234
</pre>

### Backup / Restore

`make backup` will create a `wordpress-state.tgz` containing all the
files under `volumes/srv`, plus a database dump in SQL format.

`make restore` performs the opposite operation.


# Technical documentation

## `docker-compose.yml`

Unlike production (which uses Kubernetes / OpenShift), the bunch is
tied together using the `docker-compose.yml` file on the developer's
workstation. Some containers (e.g. `phpmyadmin`) only run in
development mode; others (e.g. `httpd`) have additional Docker volumes
mounted, so as to "reach into" them from the developer's IDE or code
editor.


## `.env` file

The `.env` file contains environment variable declarations, some
specific to the development rig (e.g. `WP_PORT_PHPMA` for the
PHPMyAdmin port that Docker exposes), some identical to production
(`MYSQL_*`, `WP_VERSION`, `WP_ADMIN_*` and `WP_ENV`).


## Volumes

### `volumes/db`

The MySQL persistent database directory, used by the `mysql` container

### `volumes/srv` (mounted as `/srv`)

The serving directory tree, comprised of any number of WordPress
instances and/or other Apache-servable assets (e.g. directories
containing just a `.htaccess` file). The purpose and layout are
identical to the `/srv` directory in production (which is hosted on a
NAS); in particular, the subdirectory structure is the same:

| Path fragment | Purpose |
| --- | --- |
| `/srv/` | The root of the serving directory |
| `${WP_ENV}/` | The so-called *environment* mimicking the top-level NAS subdirectories in production (one per serving replicated `httpd` pod in OpenShift) |
| `wp-httpd/` | The host name in termes of Apache's [`VirtualDocumentRoot` directive](https://httpd.apache.org/docs/2.4/mod/mod_vhost_alias.html#virtualdocumentroot). When running locally, the host name must match both the name of the `httpd` container in `devsupport/docker-compose.yml`, and a suitable entry in `/etc/hosts` so that one can navigate to the sites below this directory |
| `htdocs/` | Dictated by the `VirtualDocumentRoot` value |
| `sub/dir/` | Any path can go here, affording for a hierarchy of nested WordPress instances to be installed locally |
| `wp-config.php`<br/>`index.php`<br/>etc. | A typical WordPress installation |

### `volumes/wp` (mounted as `/wp`)

Contains a "live" copy of all the PHP code (WordPress + VPSI-authored,
standard-issue themes and plug-ins) - Unlike in production, where that
same `/wp` directory is baked into the Docker image. From any given
site under `/srv`, symlinks may (or may not) be used to alias the
WordPress code and plug-ins into the site.

The intent of this volume is to allow developers to edit the source
code of both the WordPress core, the "official" plug-ins and the
plug-ins and themes authored by EPFL staff. The latter are
additionally checked out as part of their original Git depots, so that
developers can push their changes back upstream.

You can audit the development rig by yourselves if you type
`find volumes/wp/5.* -type l -o -name .git -prune`. Here is what you'll find:

| Path under `volumes/wp/5.*`                                                                                                                                                            | Implementation                                                                                                                                                               | Purpose                                                                                                                                                                                                                                                                                                                                                                                                                               |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `wp-content/mu-plugins`                                                                                                                                                            | Git checkout of [epfl-si/wp-mu-plugins](https://github.com/epfl-si/wp-mu-plugins)                                                                                            | The "must-use" plugins                                                                                                                                                                                                                                                                                                                                                                                                                |
| `wp-content/plugins/accred`<br/>`wp-content/plugins/tequila`<br/>`wp-content/plugins/epfl`<br/>`wp-content/plugins/epfl-restauration`<br/>`wp-content/plugins/EPFL-Content-Filter`<br/>etc. | Git checkouts of the respective plug-ins from the [epfl-si GitHub namespace](https://github.com/epfl-si/)                                                                    | Plug-ins available for WordPress sites (in `/srv`) to symlink to. Depending on policy (expressed through Ansible), some are installed on as few as just one site (e.g. `epfl-restauration`), while others are active on all production sites (e.g. `accred`, `tequila`). wp-dev ensures that these paths are working git checkouts from the corresponding repositories (so that when editing the files in there, one can there                                   |
| `wp-content/themes`                                                                                                                                                                | Git checkout of [`wp-theme-2018`](https://github.com/epfl-si/wp-theme-2018/)                                                                                                 | The modern WordPress theme, that implements [the 2018 style guide](https://epfl-si.github.io/elements/#/), declined into the “main” theme (in subdirectory `wp-theme-2018`) and the “lightweight” theme with no menu integration (`wp-theme-light`)                                                                                                                                                                                   |
| `wp-content/index.php`<br/>`wp-content/plugins/shortcodes-ultimate`<br/> and more (basically all files except the ones mentioned above)                                            | Extracted from the Docker image by `make checkout`                                                                                                                           | These files or plug-ins are required by WordPress, and one can even edit them, but the development kit doesn't help with pushing the changes upstream. (In fact, doing `make checkout` again will revert the edits.)                                                                                                                                                                                                                  |

[Ansible suitcase]: https://github.com/epfl-si/ansible.suitcase
[eyaml]: https://github.com/voxpupuli/hiera-eyaml
[Keybase]: https://keybase.io
[local-restore-from-restic.sh]: ./devscripts/local-resotre-from-restic.sh
[`new-wp-site.sh`]: https://github.com/epfl-si/wp-ops/blob/master/docker/mgmt/new-wp-site.sh
[wp-dev]: https://github.com/epfl-si/wp-dev
[wp-ops]: https://github.com/epfl-si/wp-ops
[wp-gutenberg-epfl]: https://github.com/epfl-si/wp-gutenberg-epfl
