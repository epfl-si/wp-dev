const { Status } = require('cucumber');

function isScreenshotWorthy(scenario) {
  return process.env.WP_ACCEPTANCE_SCREENSHOT_ALWAYS ||
    scenario.result.status === Status.FAILED
}

// https://github.com/cucumber/cucumber-js/blob/master/docs/support_files/attachments.md
exports.checkForScreenshot = async (scenario) => {
  if (isScreenshotWorthy(scenario)) {
    const pngBuffer = await this.page.screenshot()
    this.attach(pngBuffer, 'image/png')
  }
};
