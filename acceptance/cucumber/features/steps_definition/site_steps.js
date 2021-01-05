const { Given, When, Then } = require('cucumber'),
  assert = require('assert')

Then('je vois la page d\'accueil', async function () {
  await this.page.waitForSelector("body[class~='home']")
})

Then('je vois que la page a un titre EPFL', async function () {
  const pageTitle = await this.page.title()
  assert.ok(pageTitle.includes('EPFL'), "Le titre ne possède pas l'acronyme EPFL")
});

Then('je vois la barre d\'administration', async function () {
  await this.page.waitForSelector("#wpadminbar")
});

Then('je ne vois pas la barre d\'administration', async function () {
  try {
    await this.page.waitForSelector("#wpadminbar", { hidden: true, timeout: 3000 })
  } catch (e) {
    // ok, we admin, let's logoff by going to the provided url
    const logoutUrl = await this.page.$eval('#wp-admin-bar-logout > a:nth-child(1)', el => el.href)
    await this.page.goto(logoutUrl)
    await this.page.goto(this.urls.home)
    try {
      await this.page.waitForSelector("#wpadminbar", {hidden: true, timeout: 3000})
    } catch (e2) {
      throw "Je vois encore la barre d'administration. " + e2.message
    }
  }
});

Then('je vois le bandeau "cookie consent"', async function () {
  await this.page.waitForSelector("[class~='cc-window']")
})

When('je clique le boutton "OK" du cookie consent', async function () {
  await this.page.click("a[class~='cc-btn']")
  this.page.waitForTimeout(1500)  // don't go to fast, it need time to disapear
})

Then('le bandeau "cookie consent" n\'est plus là', async function () {
  await this.page.waitForSelector("[class~='cc-window']", { visible: false, timeout: 2000 })
})
