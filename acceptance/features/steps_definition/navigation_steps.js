const { Given, When, Then } = require('cucumber'),
  assert = require('assert')

When('je navigue vers la page d\'accueil', async function () {
  const response = await this.page.goto(this.urls.home)
  assert.equal(response.status(), 200)
})

When('je navigue vers la liste des plugins', async function () {
  const response = await this.page.goto(this.urls.pluginsList)
  assert.equal(response.status(), 200)
  await this.page.waitForSelector("table.plugins", { timeout: 1000 })
});
