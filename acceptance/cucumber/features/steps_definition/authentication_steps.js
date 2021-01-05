const { Given, When, Then } = require('cucumber'),
    assert = require('assert')

async function admin_login(context) {
    await context.page.goto(context.urls.login, { waitUntil:'domcontentloaded' })

    //TODO: get the right credentials, depending of where it is launched
    await context.page.$eval('input[name=log]', (el, value) => el.value = value, context.credentials.wordpress_admin_local.user)
    await context.page.$eval('input[name=pwd]', (el, value) => el.value = value, context.credentials.wordpress_admin_local.password)

    await Promise.all([
        context.page.click("#wp-submit"),
        context.page.waitForNavigation()
    ])
}

When('je me loggue sur le site en tant qu\'administrateur', async function () {
    await admin_login(this)
})

Given('je suis administrateur du site', async function () {
    await admin_login(this)
})
