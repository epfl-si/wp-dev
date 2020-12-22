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

When('je navigue vers le thème EPFL 2018', async function () {
  const response = await this.page.goto(this.urls.theme2018View)
  assert.equal(response.status(), 200)
  await this.page.waitForSelector("div.theme-info > h2.theme-name", { timeout: 1000 })
});
