'use strict'

const once = require('once'),
      logOnce = once(console.log)

module.exports = function urls () {
  let homesite = process.env.WP_ACCEPTANCE_TARGET || 'https://wp-httpd/'
  logOnce('Testing at ' + homesite)

  return {
    home: homesite,
    wp_admin: homesite + 'wp-admin'
  }
}
