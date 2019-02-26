const { When, Then } = require('cucumber'),
      assert = require('assert')

When('je navigue vers la page d\'accueil', async function () {
  this.page = await this.newPage()
  await this.page.goto(this.urls.home)
})

Then('je n\'ai pas d\'erreurs', async function () {
  assert.equal(200, this.result.status())
})
