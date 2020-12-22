const {Given, When, Then} = require('cucumber'),
    assert = require('assert'),
    {
        versionFromOnlinePluginIni,
        versionFromOnlineFile
    } = require('../support/fetcher')


Then('je vois que le plug-in wp-gutenberg est à jour', async function () {
    const latestVersion = await versionFromOnlinePluginIni('https://raw.githubusercontent.com/epfl-si/wp-gutenberg-epfl/master/plugin.php')
    assert(latestVersion)

    const currentVersionRegex = /Version\s(\d.*\.\d.*\.?\d.?)/
    const pluginName = 'wp-gutenberg'
    const divValue = await this.page.$eval(`tr[data-plugin*="${pluginName}"] > td.column-description > div.plugin-version-author-uri`, el => el.innerText);
    const currentVersionMatch = divValue.match(currentVersionRegex)
    assert.ok(currentVersionMatch && currentVersionMatch.length > 1, `Impossible de trouver la version en cours du plugin ${pluginName}, est-il installé ? Texte recherché : ${divValue}`)
    const currentVersion = currentVersionMatch[1]
    assert.equal(currentVersion.trim(), latestVersion.trim(),
    `The ${pluginName} version mismatch with the latest provided by Github. Installed: ${currentVersion}, latest version: ${latestVersion}`);
});

Then('je vois que le thème EPFL 2018 est à jour', async function () {
    const latestVersion = await versionFromOnlineFile('https://raw.githubusercontent.com/epfl-si/wp-theme-2018/master/wp-theme-2018/VERSION')
    assert(latestVersion)

    const currentVersionRegex = /Version:\s(\d.*\.\d.*\.?\d.?)/
    const divValue = await this.page.$eval(`div.theme-info > h2.theme-name > span.theme-version`, el => el.innerText);
    const currentVersionMatch = divValue.match(currentVersionRegex)
    assert.ok(currentVersionMatch && currentVersionMatch.length > 1, `Impossible de trouver la version en cours du thème, est-il installé ? Texte recherché : ${divValue}`)
    const currentVersion = currentVersionMatch[1]
    assert.equal(currentVersion.trim(), latestVersion.trim(),
        `The thème EPFL 2018 version mismatch with the latest provided by Github. Installed: ${currentVersion}, latest version: ${latestVersion}`);
});
