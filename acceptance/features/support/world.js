const { setWorldConstructor, setDefaultTimeout } = require('cucumber'),
    credentials = require('../../lib/credentials'),
    urls = require('../../lib/urls')


function CustomWorld({attach, parameters}) {
    this.attach = attach
    this.parameters = parameters

    setDefaultTimeout(60 * 1000);

    this.credentials = credentials()
    this.urls = urls()
}

setWorldConstructor(CustomWorld)
