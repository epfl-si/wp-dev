<h1 align="center">
  WordPress @ EPFL: the development environment
</h1>

In this repository you will find:

- Support for running the VPSI WordPress stack locally

# Install and Usage

## Initial Setup

1. Clone the repository
1. Edit your `/etc/hosts` or platform equivalent and set up a line like this:<pre>127.0.0.1       wp-httpd</pre>
1. `git clone` the repository onto your hard drive
1. Go into the `wp-local` subdirectory and copy and modify `env.sample` into `.env`
1. Type `make up` to bring up the development stack, then `make exec` to enter the so-called management container:<pre>
cd /srv/${WP_ENV}/
mkdir -p wp-httpd/htdocs
cd wp-httpd/htdocs
</pre>
1. Create one or more sites under `/srv/${WP_ENV}/wp-httpd/htdocs` using either the `wp` command-line tool (for a “vanilla” WordPress site) or `jahia2wp create`
1. If you want to modify the EPFL-provided themes and plug-ins interactively, you can do so by replacing the deployed subdirectories with symlinks to `/wp/wp-content`, e.g. <pre>
cd /srv/${WP_ENV}/wp-httpd/htdocs/
cd where/ever/is/my/WordPress/wp-content
rm -rf themes/wp-theme-2018 plugins/epfl* plugins/EPFL-*
ln -s /wp/wp-content/plugins/epfl{,-scienceqa,-stats,-tequila,-infoscience} \
      /wp/wp-content/plugins/EPFL-{Content-Filter,settings} plugins/
ln -s /wp/wp-content/themes/wp-theme-2018 themes/
</pre>

## Day-To-Day Operations

1. Go into the `wp-local` subdirectory and `make up`
1. Hack on things
1. Additional helpful commands are: `make exec`, `make httpd` and more (try `make help` for an overview)

### Volumes

#### `volumes/db`

The MySQL persistent database directory, used by the `mysql` container

#### `volumes/srv` (mounted as `/srv`)

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

#### `volumes/wp-content` (mounted as `/wp/wp-content`)

Contains the VPSI-specific code that goes into an ordinary WordPress
`wp-content` directory. A set of symlinks may (or may not) be used to
reference these from `/srv` (as seen from the inside of the
`httpd` container)


