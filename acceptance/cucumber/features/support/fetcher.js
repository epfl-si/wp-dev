const fetch = require('node-fetch')


const versionFromOnlinePluginIni = async url => {
    const response = await fetch(url)
    const text = await response.text()

    const regexVersion = /\*\sVersion:\s*(\d\.\d\.\d?)/
    const versionNumber = text.match(regexVersion)
    return versionNumber[1]
}

const versionFromOnlineFile = async url => {
    const response = await fetch(url)
    return await response.text()
}

module.exports = {
    versionFromOnlinePluginIni,
    versionFromOnlineFile
}
