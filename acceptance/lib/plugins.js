const fetch = require('node-fetch')


const versionFromOnlinePluginIni = async url => {
    const response = await fetch(url)
    const text = await response.text()

    const regexVersion = /\*\sVersion:\s*(\d\.\d\.\d?)/
    const versionNumber = text.match(regexVersion)
    return versionNumber[1]
}

module.exports = function plugins () {
    listPlugins = new Map()

    listPlugins.set('wp-gutenberg', {
        fetcher: versionFromOnlinePluginIni,
        url: 'https://raw.githubusercontent.com/epfl-si/wp-gutenberg-epfl/master/plugin.php'
    })

    return listPlugins
}
