const { setWorldConstructor, setDefaultTimeout } = require('cucumber'),
    credentials = require('../../../lib/credentials'),
    urls = require('../../../lib/urls'),
    plugins = require('../../../lib/plugins')


function CustomWorld({attach, parameters}) {
    this.attach = attach
    this.parameters = parameters

    setDefaultTimeout(60 * 1000);

    this.credentials = credentials()
    this.urls = urls()
    this.plugins = plugins()
}

setWorldConstructor(CustomWorld)
