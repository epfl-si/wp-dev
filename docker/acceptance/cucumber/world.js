const { setWorldConstructor, Before, BeforeAll } = require('cucumber'),
      puppeteer = require('../lib/puppeteer'),
      credentials = require('../lib/credentials'),
      urls = require('../lib/urls')


// In the beginning, the world was void.
let world = module.exports = {}

setWorldConstructor(function() { return world })

// But then, Cucumber invoked BeforeAll() and there was Puppeteer and
// more.
BeforeAll(async () => {
  world.credentials = await credentials(world)
  world.urls = await urls(world)

  world.browser = await puppeteer.launch(world)
  world.newPage = world.browser.newPage =
    pageFacet(world, world.browser.newPage.bind(world.browser))
})

function pageFacet(world, boundFunctionReturningPage) {
  return async function(/* arguments */) {
    world.page = await boundFunctionReturningPage.apply({}, arguments)
    world.page.goto = resultFacet(world, world.page.goto.bind(world.page))
    return world.page
  }
}

function resultFacet(world, boundFunctionReturningResult) {
  return async function(/* arguments */) {
    world.result = await boundFunctionReturningResult.apply({}, arguments)
    return world.result
  }
}
