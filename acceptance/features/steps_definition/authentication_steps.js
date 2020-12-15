const { Given, When, Then } = require('cucumber'),
  assert = require('assert')

async function admin_login(context) {
    await context.page.goto(context.urls.login)

    //FIXME: which one of credentials is used depends on url, maybe
    await context.page.focus('#user_login')
    await context.page.keyboard.down('Control')
    await context.page.keyboard.press('a')
    await context.page.keyboard.up('Control')
    await context.page.keyboard.press('Delete')

    await context.page.keyboard.type(context.credentials.wordpress_admin_local.user)

    await context.page.focus('#user_pass')
    await context.page.keyboard.type(context.credentials.wordpress_admin_local.password)
    await context.page.click("#wp-submit")
}

When('je me loggue sur le site en tant qu\'administrateur', async function () {
    await admin_login(this)
})

Given('je suis administrateur du site', async function () {
    try {
        await this.page.waitForSelector("#wpadminbar", { timeout: 1000 })
    } catch (e) {
        // no wpadminbar, let's log
        await admin_login(this)
    }
})
