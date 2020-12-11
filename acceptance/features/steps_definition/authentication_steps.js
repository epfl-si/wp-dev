const { Given, When, Then } = require('cucumber'),
  assert = require('assert')

When('je me loggue sur le site en tant qu\'administrateur', async function () {
    await this.page.goto(this.urls.login)

    //FIXME: which one of credentials is used depends on url, maybe
    await this.page.focus('#user_login')
    await this.page.keyboard.type(this.credentials.wordpress_admin_local.user)

    await this.page.focus('#user_pass')
    await this.page.keyboard.type(this.credentials.wordpress_admin_local.password)
});
