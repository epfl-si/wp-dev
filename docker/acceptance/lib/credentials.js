module.exports = async function get(world) {
  return {
    wordpress_admin: {
      user: 'kermit',
      password: process.env.KERMIT_PASSWORD
    }
  }
}
