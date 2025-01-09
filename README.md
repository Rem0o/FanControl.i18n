# FanControl.i18n
All of [FanControl's](https://github.com/Rem0o/FanControl.Releases) string resources for translation.

## To contribute
For a given language, say french, each json file needs a ".fr.json" version, with the exact same keys in the json file as the default ".json".
Any missing key will result this specific string to use the default (english) string.
Try and keep the relative size of the string close to the original, to avoid layout issues.

[IETF BCP 47](https://www.ietf.org/rfc/bcp/bcp47.txt) is used as default for Windows locale names, like suggested [here](https://learn.microsoft.com/en-us/globalization/locale/standard-locale-names).
<br/>
The most common language codes can be found [here](https://www.techonthenet.com/js/language_tags.php).

Translations will be pulled into the main software periodically.

## Formatting script
The formatting script will run on every PR. It makes sure all the json files are formatted the same. Run the script locally before committing:
```powershell
./format-json.ps1 -Fix
```
