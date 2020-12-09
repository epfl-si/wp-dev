const { Given, When, Then } = require('cucumber'),
  assert = require('assert')

Then('je vois la page d\'accueil', async function () {
  assert.equal(200, this.result.status())
})

Then('je vois que la page a un titre EPFL', async function () {
  const pageTitle = await this.page.title()
  assert.ok(pageTitle.includes('EPFL'), "Le titre ne possède pas l'acronyme EPFL")
});

Then('je vois le bandeau "cookie consent"', async function () {
  await this.page.waitForSelector("[class~='cc-btn']")
})

When('je clique le boutton "OK" du cookie consent', async function () {
  await this.page.click("a[class~='cc-btn']")
})

Then('le bandeau "cookie consent" n\'est plus là', async function () {
  await this.page.waitForSelector("[class~='cc-btn']", { hidden: true, timeout: 5000 })
})
