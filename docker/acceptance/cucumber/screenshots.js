'use strict'

const { After, Status } = require('cucumber'),
      puppeteer = require('../lib/puppeteer')

function isScreenshotWorthy(testCase) {
  return testCase.result.status === Status.FAILED;
}


// https://github.com/cucumber/cucumber-js/blob/master/docs/support_files/attachments.md
After(async function(testCase) {
  if (! isScreenshotWorthy(testCase)) return

  const pngBuffer = await this.page.screenshot()
  await this.attach(pngBuffer, 'image/png')
})
