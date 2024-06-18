# Azure API parameters
$subscriptionKey = "YOUR_SUBSCRIPTION_KEY"  # <-- Replace with your actual subscription key
$endpoint = "https://api.cognitive.microsofttranslator.com/"
$location = "westeurope" # Specify the API region, for example, "westeurope"

# Custom translator category
$categoryId = "YOUR_CATEGORY_ID"  # <-- Replace with your actual category ID

# Translations folder
$translationsFolder = "./Translations"

# Find the Italian file (.xlf) in the translations folder
$itFile = Get-ChildItem -Path $translationsFolder -Filter "*it-IT.xlf" | Select-Object -First 1

# Check if the Italian file exists
if (-not $itFile) {
    Write-Host "Italian file not found."
    exit
}
Write-Host "Italian file found: $($itFile.Name)"

# Read the content of the Italian XLF file
[xml]$itXlf = Get-Content -Path $itFile.FullName -Encoding UTF8

# XML namespace management
$namespaceManager = New-Object System.Xml.XmlNamespaceManager($itXlf.NameTable)
$namespaceManager.AddNamespace("x", "urn:oasis:names:tc:xliff:document:1.2")

# Create a map to associate English and Italian translations
$translationMap = @{}
$translationUnits = $itXlf.SelectNodes("//x:trans-unit", $namespaceManager)
foreach ($unit in $translationUnits) {
    $id = $unit.id
    $sourceText = $unit.SelectSingleNode("x:source", $namespaceManager).'#text'
    $targetText = $unit.SelectSingleNode("x:target", $namespaceManager).'#text'
    $translationMap[$id] = [PSCustomObject]@{ English = $sourceText; Italian = $targetText }
}

# Function to translate text using Azure AI Translator with ERP context
function Translate-Text {
    param (
        [string]$text,
        [string]$toLang,
        [string]$subscriptionKey,
        [string]$endpoint,
        [string]$location,
        [string]$categoryId
    )

    $path = "translate?api-version=3.0"
    $params = "&to=$toLang&category=$categoryId"
    $uri = $endpoint + $path + $params

    # Add ERP context to the text to be translated
    $contextualText = $text

    # HTTP request for translation
    $body = @(
        @{
            Text = $contextualText          
        }
    ) | ConvertTo-Json

    $jsonBody = "[" + $body + "]"

    $headers = @{
        "Ocp-Apim-Subscription-Key" = $subscriptionKey
        "Ocp-Apim-Subscription-Region" = $location
        "Content-Type" = "application/json; charset=utf-8"
    }

    $jsonBody = [System.Text.Encoding]::UTF8.GetBytes($jsonBody);

    try {
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $jsonBody
        $translatedText = $response.translations[0].text
        return $translatedText
    } catch {
        Write-Host "Error during translation: $_"
        return $null
    }
}

# Find all XLF files except the Italian one and those ending with ".g.xlf"
$otherFiles = Get-ChildItem -Path $translationsFolder -Filter "*.xlf" | Where-Object { $_.Name -notlike "*it-IT.xlf" -and $_.Name -notlike "*.g.xlf" }
Write-Host "Files found for translation: $($otherFiles.Count)"

# Translate and update each XLF file
$totalTranslations = 0
foreach ($file in $otherFiles) {
    [xml]$xlf = Get-Content -Path $file.FullName -Encoding UTF8
    $fileTranslations = 0

    # Extract the language code from the file name
    $toLang = ($file.Name -split '\.')[1]

    $translationUnits = $xlf.SelectNodes("//x:trans-unit", $namespaceManager)

    foreach ($unit in $translationUnits) {
        $id = $unit.id
        $target = $unit.SelectSingleNode("x:target", $namespaceManager).'#text'
        if ($target -eq "[NAB: NOT TRANSLATED]") {
            if ($translationMap.ContainsKey($id)) {
                $itText = $translationMap[$id].Italian

                # Add ERP context to the translation request
                $translatedText = Translate-Text -text $itText -toLang $toLang -subscriptionKey $subscriptionKey -endpoint $endpoint -location $location -categoryId $categoryId
                if ($translatedText) {
                    $unit.SelectSingleNode("x:target", $namespaceManager).'#text' = $translatedText
                    $fileTranslations++
                }
            }
        }
    }

    # Save the updated XLF file
    try {
        $xlf.Save($file.FullName)
    } catch {
        Write-Host "Error saving file: $_"
    }

    Write-Host "File: $($file.Name) - Translations done: $fileTranslations"
    $totalTranslations += $fileTranslations
}

Write-Host "Translation completed. Total translations done: $totalTranslations"
