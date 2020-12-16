const { Given, When, Then } = require('cucumber'),
    assert = require('assert')

async function admin_login(context) {
    await context.page.goto(context.urls.login)

    //TODO: get the right credentials, depending of where it is launched
    await context.page.$eval('input[name=log]', (el, value) => el.value = value, context.credentials.wordpress_admin_local.user);
    await context.page.$eval('input[name=pwd]', (el, value) => el.value = value, context.credentials.wordpress_admin_local.password);

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
