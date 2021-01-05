const { Before, After } = require('cucumber'),
    puppeteer = require('../../../lib/puppeteer'),
    { checkForScreenshot } = require('./screenshots')


Before(async function() {
    const browser = await puppeteer.launch();
    const page = await browser.newPage();
    this.browser = browser;
    this.page = page;
})

After(async function(scenario) {
    await checkForScreenshot(scenario)
    // Teardown browser
    if (this.browser) {
        await this.browser.close();
    }
    // Cleanup DB
})
