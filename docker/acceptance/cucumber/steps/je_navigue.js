const { Given, When, Then } = require('cucumber'),
      assert = require('assert')

When('je navigue vers la page d\'accueil', async function () {
  this.page = await this.newPage()
  await this.page.goto(this.urls.home)
})

Then('je n\'ai pas d\'erreurs', async function () {
  assert.equal(200, this.result.status())
})

Given('un nouveau site', function () {
  // Write code here that turns the phrase above into concrete actions
  return 'pending';
});

When('je me connecte sur wp-admin', function () {
  // Write code here that turns the phrase above into concrete actions
  return 'pending';
});

 When('je navigue vers {string}', function (url) {
   // Write code here that turns the phrase above into concrete actions
   return 'pending';
 });

 Then('je vois que le plug-in {string} est à jour', function (plugin) {
   // Write code here that turns the phrase above into concrete actions
   return 'pending';
 });
