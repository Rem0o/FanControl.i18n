param (
    [string]$Path = ".",
    [switch]$Fix = $false
)

$newline = [Environment]::NewLine
$charD = [System.Convert]::ToChar(0xD)
$charA = [System.Convert]::ToChar(0xA)
$CRLF = "$charD$charA"

function Format-Json {
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Json,
        [int]$Indentation = 4
    )

    $indent = 0
    $regexUnlessQuoted = '(?=([^"]*"[^"]*")*[^"]*$)'

    $result = $Json -split $CRLF |
    ForEach-Object {
        # If the line contains a ] or } character, 
        # we need to decrement the indentation level, unless:
        #   - it is inside quotes, AND
        #   - it does not contain a [ or {
        if (($_ -match "[}\]]$regexUnlessQuoted") -and ($_ -notmatch "[\{\[]$regexUnlessQuoted")) {
            $indent = [Math]::Max($indent - $Indentation, 0)
        }

        # Replace all colon-space combinations by ": " unless it is inside quotes.
        $line = (' ' * $indent) + ($_.TrimStart() -replace ":\s+$regexUnlessQuoted", ': ')

        # If the line contains a [ or { character, 
        # we need to increment the indentation level, unless:
        #   - it is inside quotes, AND
        #   - it does not contain a ] or }
        if (($_ -match "[\{\[]$regexUnlessQuoted") -and ($_ -notmatch "[}\]]$regexUnlessQuoted")) {
            $indent += $Indentation
        }

        # Powershell 5.10 doesn't handle some chars well
        # Replace escapped "\u0027" with "'"
        # Replace escapped "\u0026" with "&"
        $line = $line -replace "\\u0027", "'"
        $line = $line -replace "\\u0026", "&"

        $line
    }

    $res = ($result -Join $CRLF)

    return $res
}

function Compare-Json {
    param (
        [System.Collections.Specialized.OrderedDictionary]$Base,
        [System.Collections.Specialized.OrderedDictionary]$Translation
    )
    $missingKeys = @()
    $superfluousKeys = @()

    foreach ($key in $Base.Keys) {
        if (-not $Translation.Contains($key)) {
            $missingKeys += $key
        }
    }

    foreach ($key in $Translation.Keys) {
        if (-not $Base.Contains($key)) {
            $superfluousKeys += $key
        }
    }

    return [pscustomobject]@{
        MissingKeys     = $missingKeys
        SuperfluousKeys = $superfluousKeys
    }
}

function ConvertTo-OrderedDictionary { 
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [pscustomobject]$object
    )
    $ordered = [ordered]@{}

    foreach ($property in $object.PSObject.Properties) {
        $ordered[$property.Name] = $property.Value
    }

    return $ordered
}

function ConvertTo-OrderedDictionaryFromArray { 
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$object
    )
    $ordered = [ordered]@{}

    foreach ($item in $object) {
        $ordered[$item.Name] = $item.Value
    }

    return $ordered
}

$fullPath = $Path | Resolve-Path
Write-Output "Scanning $fullPath"
Write-Output "$newline"

$baseFiles = Get-ChildItem -Path $Path -Filter "*.json" -Recurse | Where-Object { $_.Name -notmatch "\.[a-z]{2}(-[a-z]{2})?\.json$" }

$exitCode = 0
$problem = ""

foreach ($baseFile in $baseFiles) {
    $baseJson = [IO.File]::ReadAllText($baseFile.FullName, [System.Text.Encoding]::UTF8)
    $baseDictionary = $baseJson | ConvertFrom-Json | ConvertTo-OrderedDictionary
    $translationFiles = $translationFiles = Get-ChildItem -Path $baseFile.DirectoryName -Filter "$($baseFile.BaseName).*.json"

    foreach ($translationFile in $translationFiles) {
        $translationJson =[IO.File]::ReadAllText($translationFile.FullName, [System.Text.Encoding]::UTF8);
        $translation = $translationJson  | ConvertFrom-Json | ConvertTo-OrderedDictionary
        $comparison = Compare-Json -Base $baseDictionary -Translation $translation

        if ($comparison.MissingKeys.Count -gt 0 -or $comparison.SuperfluousKeys.Count -gt 0) {
            $exitCode = -1
            Write-Output "File: $($translationFile.FullName)"
            Write-Output "Missing Keys: $($comparison.MissingKeys -join ', ')"
            Write-Output "Superfluous Keys: $($comparison.SuperfluousKeys -join ', ')"

            if ($Fix) {
                foreach ($key in $comparison.MissingKeys) {
                    $translation[$key] = $baseDictionary[$key]
                }

                foreach ($key in $comparison.SuperfluousKeys) {
                    $translation.Remove($key)
                }
                
                $formattedJson = ConvertTo-OrderedDictionaryFromArray($translation.GetEnumerator() | Sort-Object -Property Name ) | ConvertTo-Json -Depth 100 | Format-Json -Indentation 2

                if ($formattedJson -ne $translationJson) {
                    Write-Output "Fixing translationFile"
                    [IO.File]::WriteAllText($translationFile.FullName, $formattedJson, [System.Text.Encoding]::UTF8)
                }
            }
        }
        else {
            $formattedTranslationJson = ConvertTo-OrderedDictionaryFromArray($translation.GetEnumerator() | Sort-Object -Property Name) | ConvertTo-Json -Depth 100 | Format-Json -Indentation 2
            if ($formattedTranslationJson -ne $translationJson) {
                $exitCode = -1
                $problem += "Formatting for [$translationFile] is wrong" + $newline

                $length = [math]::Min($formattedTranslationJson.Length, $translationJson.Length)
                for ($i = 0; $i -lt $length; $i++) {
                    if ($formattedTranslationJson[$i] -ne $translationJson[$i]) {
                        $hex1 = [System.Convert]::ToString([System.Convert]::ToInt32($formattedTranslationJson[$i]), 16)
                        $hex2 = [System.Convert]::ToString([System.Convert]::ToInt32($translationJson[$i]), 16)
                        Write-Output "Difference at position {$i}: (0x$hex1) vs (0x$hex2)"
                        break;
                    }
                }


                if ($Fix) {
                    Write-Output "Formatting [$translationFile]"
                    [IO.File]::WriteAllText( $translationFile.FullName, $formattedTranslationJson, [System.Text.Encoding]::UTF8)
                }
            }
        }
    }

    $formattedBaseJson = ConvertTo-OrderedDictionaryFromArray( $baseDictionary.GetEnumerator() | Sort-Object -Property Name) | ConvertTo-Json -Depth 100 | Format-Json -Indentation 2
    if ($formattedBaseJson -ne $baseJson) {
        $exitCode = -1;
        $problem += "Formatting for [$baseFile] is wrong" + $newline

        

        $length = [math]::Min($formattedBaseJson.Length, $baseJson.Length)
        for ($i = 0; $i -lt $length; $i++) {
            if ($formattedBaseJson[$i] -ne $baseJson[$i]) {
                $hex1 = [System.Convert]::ToString([System.Convert]::ToInt32($formattedBaseJson[$i]), 16)
                $hex2 = [System.Convert]::ToString([System.Convert]::ToInt32($baseJson[$i]), 16)
                Write-Output "Difference at position {$i}: (0x$hex1) vs (0x$hex2)"
                break;
            }
        }

        if ($Fix) {
            Write-Output "Formatting [$baseFile]"
            [IO.File]::WriteAllText($baseFile.FullName,  $formattedBaseJson, [System.Text.Encoding]::UTF8)
        }
    }
}

Write-Output "$newline"
if ($Fix -and ($exitCode -eq -1)) {
    $exitCode = 0
}
elseif ( $exitCode -eq -1) {
    Write-Output "Problems found!"
    if (-Not [String]::IsNullOrEmpty($problem) ) {
        Write-Output $problem
    }
}
# Success (0)
else { 
    Write-Output "No problem found!"
}

exit $exitCode