const { Given, When, Then } = require('cucumber'),
  assert = require('assert')


When('je navigue vers la page d\'accueil', async function () {
  this.page = await this.newPage()
  await this.page.goto(this.urls.home)
})

When('je retourne vers la page d\'accueil', async function () {
  await this.page.goto(this.urls.home)
})
