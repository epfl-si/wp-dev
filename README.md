<h1 align="center">
  WordPress @ EPFL: the development environment
</h1>

In this repository you will find:

- Support for running the VPSI WordPress stack locally

# Install and Usage

## Initial Setup

1. Clone the repository
1. Edit your `/etc/hosts` or platform equivalent and set up a line like this:<pre>127.0.0.1       wp-httpd</pre>
1. Type `make` to bring up the development stack, then `make exec` to enter the so-called management container
1. Within the management container, type<pre>
cd /srv/${WP_ENV}/
mkdir -p wp-httpd/htdocs
cd wp-httpd/htdocs
</pre>
1. Create one or more sites under `/srv/${WP_ENV}/wp-httpd/htdocs` using either the `wp` command-line tool (for a “vanilla” WordPress site) or `jahia2wp create`
</pre>

## Day-To-Day Operations

1. Type `make checkout up`
1. Hack on things
1. Additional helpful commands are: `make exec`, `make httpd` and more (try `make help` for an overview)

### Acceptance tests

To build and run the "canned" version try<pre>
cd docker/acceptance
npm run docker --  --screenshot-always
</pre>

To run the "unpacked" version of same against the local development
environment, using a browser that is re-used across test runs, do<pre>
cd docker/acceptance npm i ./bin/run-chrome
</pre>

and follow the instructions that appear on-screen.



# Technical Documentation

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
developers can push their changes back upstream - That includes the
[jahia2wp repository](https://github.com/epfl-idevelop/jahia2wp),
which (for historical reasons) is a Python-based utility that contains
some WordPress plugins and mu-plugins.

You can audit the development rig by yourselves if you type `find volumes/wp -type l -o -name .git` . Here is what you'll find:

| Path under `volumes/wp` | Implementation | Purpose |
|-------------------------|---------|----------------|
| `jahia2wp` | Git checkout from the [jahia2wp depot](https://github.com/epfl-idevelop/jahia2wp) | Provides the targets for the `plugins` and `mu-plugins` symlinks below, both inside and outside the Docker containers |
| `wp-content/mu-plugins` | Symlink to `../../jahia2wp/data/wp/wp-content/mu-plugins` | The "must-use" plugins (we only use those from jahia2wp at the moment) |
| `wp-content/plugins/epfl`<br/>`wp-content/plugins/epfl-404`<br/>`wp-content/plugins/EPFL-Content-Filter`<br/>`wp-content/plugins/epfl-404`<br/>etc. | Symlinks to the corresponding plug-ins in `../../jahia2wp/data/wp/wp-content/plugins` | These plug-ins are available for WordPress sites (in `/srv`) to symlink to; but unlike in production, they are symlinks themselves (so that when editing the files in there, one does so in the correct Git depot) |
| `volumes/wp/wp-content/plugins/accred` | Git checkout of [the Accred plug-in](https://github.com/epfl-sti/wordpress.plugin.accred/) | A (mostly) VPSI-authored WordPress plug-in, that lives in its own Git repository  |
| `volumes/wp/wp-content/plugins/tequila` | Git checkout of [the Tequila plug-in](https://github.com/epfl-sti/wordpress.plugin.tequila/) | Ditto (at some point, we probably want to refactor the ones under jahia2wp in this way as well) |
| `volumes/wp/wp-content/themes/wp-theme-2018` | Git checkout of [`wp-theme-2018`](https://github.com/epfl-idevelop/wp-theme-2018/) | The modern WordPress theme, that implements [the 2018 style guide](https://epfl-idevelop.github.io/elements/#/) |
| `volumes/wp/wp-content/themes/wp-theme-2018` | Git checkout of [`wp-theme-2018`](https://github.com/epfl-idevelop/wp-theme-2018/) | The modern WordPress theme, that implements [the 2018 style guide](https://epfl-idevelop.github.io/elements/#/) |
| `volumes/wp/wp-content/themes/epfl-blank`<br/>`volumes/wp/wp-content/themes/epfl-master` | Symlinks to jahia2wp (like the `EPFL-*` and `epfl*` plug-ins above) | So-called "2010-style" themes,  provided as part of the jahia2wp codebase for historical reasons. (These themes are obsolescent, as obviously further development focuses on `wp-theme-2018`) |
| `wp-content/index.php`<br/>`wp-content/plugins/shortcodes-ultimate`<br/> and more (basically all files except the ones mentioned above)  | Extracted from the Docker image by `make checkout` | These files or plug-ins are required by WordPress, and one can even edit them, but the development kit doesn't help with pushing the changes upstream. (In fact, doing `make checkout` again will revert the edits.)<br/> 💡 <b>There might be some plug-ins (even VPSI-authored plugins) in that state</b> — See below |

💡 Depending on which branch of jahia2wp is checked out, there might be some plug-ins that exist in the Docker image, but not in `volumes/wp/jahia2wp/data/wp/wp-content/plugins`. If you type `make checkout` after changing branches in jahia2wp, the Makefile extracts the "orphan" plugins from the image, but (obviously) doesn't symlink them back into jahia2wp. These are not really source code — That is, you could edit these files, but you won't be able to push the changes upstream, and the next `make checkout` will revert the changes.
