require('module-alias/register')

const { Before, After, Status } = require('cucumber'),
    puppeteer = require('@lib/puppeteer')

Before(async function() {
    const browser = await puppeteer.launch();
    const page = await browser.newPage();
    this.browser = browser;
    this.page = page;
})

After(async function(testCase) {
    // Get screenshot for some cases
    if (process.env.WP_ACCEPTANCE_SCREENSHOT_ALWAYS  ||
        testCase.result.status === Status.FAILED) {
        var stream = await this.page.screenshot()
        this.attach(stream, 'image/png')
    }
    // Teardown browser
    if (this.browser) {
        await this.browser.close();
    }
    // Cleanup DB
})
