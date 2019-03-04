module.exports = function urls () {
  let homesite = process.env.WP_ACCEPTANCE_TARGET || 'https://wp-httpd/'

  return {
    home: homesite,
    wp_admin: homesite + 'wp-admin'
  }
}
