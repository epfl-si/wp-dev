const {Given, When, Then} = require('cucumber'),
    assert = require('assert')


Then('je vois que le plug-in {string} est à jour', async function (pluginName) {
    assert(this.plugins.has(pluginName), `Le plugin ${pluginName} demandé n'est pas référencé par le code de test`)
    let plugin = this.plugins.get(pluginName)
    const latestVersion = await plugin.fetcher(plugin.url)
    assert(latestVersion)

    const currentVersionRegex = /Version\s(\d\.\d\.\d?)/
    const divValue = await this.page.$eval(`tr[data-plugin*="${pluginName}"] > td.column-description > div.plugin-version-author-uri`, el => el.innerText);
    const currentVersionMatch = divValue.match(currentVersionRegex)
    assert.ok(currentVersionMatch && currentVersionMatch.length > 1, `Impossible de trouver la version en cours du plugin ${pluginName}, est-il installé ? Texte recherché : ${divValue}`)
    const currentVersion = currentVersionMatch[1]
    assert.equal(currentVersion, latestVersion,
    `The ${pluginName} version mismatch with the latest provided by Github. Installed: ${currentVersion}, latest version: ${latestVersion}`);
});
