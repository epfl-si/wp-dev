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
  let userSpecifiedPort
  if (isDocker()) {
    return puppeteer.launch({headless: true,
                             args: ['--no-sandbox', '--disable-setuid-sandbox']})
  } else if (userSpecifiedPort = getUserSpecifiedPort()) {
    const resp = await util.promisify(request)(`http://localhost:${userSpecifiedPort}/json/version`)
    const { webSocketDebuggerUrl } = JSON.parse(resp.body)
    return puppeteer.connect({browserWSEndpoint: webSocketDebuggerUrl})
  } else {
    return puppeteer.launch({headless: false, slowMo: 5})
  }
}
