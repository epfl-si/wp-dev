'use strict'

const { After, Status } = require('cucumber'),
      puppeteer = require('../../lib/puppeteer')

function isScreenshotWorthy(testCase) {
  return process.env.WP_ACCEPTANCE_SCREENSHOT_ALWAYS ||
    testCase.result.status === Status.FAILED
}

// https://github.com/cucumber/cucumber-js/blob/master/docs/support_files/attachments.md
After(async function(testCase) {
  if (isScreenshotWorthy(testCase)) {
    const pngBuffer = await this.page.screenshot()
    await this.attach(pngBuffer, 'image/png')
  }

  this.page.close()
})
