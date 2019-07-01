'use strict'

const { setWorldConstructor, Before } = require('cucumber'),
      puppeteer = require('../lib/puppeteer'),
      credentials = require('../lib/credentials'),
      urls = require('../lib/urls'),
      _ = require('lodash')

// In the beginning, the world was void.
let world = module.exports = {}

// But then, the world was made (How? When? See below!)
async function makeWorld (world, config) {
  world.credentials = await credentials(world)
  world.urls = await urls(world)

  world.browser = await puppeteer.launch(world)
  world.newPage = world.browser.newPage =
    pageFacet(world, world.browser.newPage.bind(world.browser))
}

(function() {
  let worldIsMade = false
  setWorldConstructor(function(config) {
    // We would like to call `makeWorld()` here, but we can't since it
    // is async; so we just stash `config` away for later.
    _.extend(world, config)
    return world  // So that all step functions share the world together
  })

  // First call to Before() is the the soonest we can makeWorld()
  Before(async function() {
    if (worldIsMade) return
    await makeWorld(world, world.config)
    worldIsMade = true
  })
})()

// "Facets" stash some important return values of the Puppeteer API to
// provide natural chaining between When's and Then's
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
