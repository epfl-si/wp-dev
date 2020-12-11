module.exports = function get() {
  return {
    wordpress_admin_local: {
      user: 'admin',
      password: 'password'
    },
    wordpress_admin: {
      user: 'kermit',
      password: process.env.KERMIT_PASSWORD
    }
  }
}
