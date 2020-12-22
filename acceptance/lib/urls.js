'use strict'

const once = require('once'),
      logOnce = once(console.log)

module.exports = function urls () {
  let homesite = process.env.WP_ACCEPTANCE_TARGET || 'https://wp-httpd/'
  logOnce('Testing at ' + homesite)

  return {
    home: homesite,
    wp_admin: homesite + 'wp-admin',
    login: homesite + 'wp-login.php',
    pluginsList: homesite + 'wp-admin/plugins.php',
    theme2018View: homesite + 'wp-admin/themes.php?theme=wp-theme-2018'
  }
}
