'use strict'

const puppeteer = require('puppeteer'),
      isDocker = require('is-docker'),
      util = require('util'),
      request = require('request')

function getUserSpecifiedPort (world) {
  if (process.env.CHROME_REMOTE_DEBUGGING_PORT) {
    return Number(process.env.CHROME_REMOTE_DEBUGGING_PORT)
  }
}

module.exports.launch = async function launch (world) {
  const userSpecifiedPort = getUserSpecifiedPort()
  if (userSpecifiedPort) {
    const resp = await util.promisify(request)(`http://localhost:${userSpecifiedPort}/json/version`)
    const { webSocketDebuggerUrl } = JSON.parse(resp.body)
    return puppeteer.connect({browserWSEndpoint: webSocketDebuggerUrl})
  }

  let launchOpts = { args: ["--ignore-certificate-errors"] }
  if (isDocker()) {
    launchOpts.headless = true
    launchOpts.args = launchOpts.args.concat(
      ['--no-sandbox', '--disable-setuid-sandbox'])
  } else {
    launchOpts.headless = false
    launchOpts.slowMo = 5
  }
return puppeteer.launch(launchOpts)
}
