# Azure API parameters
$subscriptionKey = "YOUR_SUBSCRIPTION_KEY"  # <-- Replace with your actual subscription key
$subscriptionKeyOpenAI = "" #openAI subscription key
$endpoint = "https://api.cognitive.microsofttranslator.com/"
$endpointOpenAI = "https://openaisii.openai.azure.com/"
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

‎XLF-AI-Translator.ps1
+66
Original file line number	Diff line number	Diff line change
@@ -36,6 +36,72 @@ foreach ($unit in $translationUnits) {
    $translationMap[$id] = [PSCustomObject]@{ English = $sourceText; Italian = $targetText }
}

function Set-ToFullLanguageName {
    param (
        [string]$toLang
    )
    if ($toLang -eq 'pl') {
        $toLang = 'polish'
    }
    if ($toLang -eq 'it') {
        $toLang = 'italian'
    }
    if ($toLang -eq 'en') {
        $toLang = 'english'
    }
    return $toLang
}

# Function to translate text using Azure OpenAI with ERP context
# 1 - Create an Azure OpenAI resource, then
# 2 - Click "Go to the Azure AI Foundry portal"
# 3 - Deploy an Azure OpenAI model
# 4 - Replace 
function TranslateOpenAI-Text {
    param (
        [string]$text,
        [string]$toLang,
        [string]$subscriptionKey, #placeholder, replaced by $subscriptionKeyOpenAI
        [string]$endpoint, #placeholder, replaced by $endpointOpenAI
        [string]$location, #placeholder
        [string]$categoryId #placeholder
    )

    $path = "openai/deployments/gpt-4o/chat/completions"
    $params = "?api-version=2025-01-01-preview"
    $uri = $endpointOpenAI + $path + $params
    $toLangFull = Set-ToFullLanguageName -toLang $toLang

    # Add ERP context to the text to be translated
    $contextualText = $text

    # HTTP request for translation
    $messages = @(
        @{
            role = "system"
            content = "You are a helpful assistant specialized in Microsoft Dynamics 365 Business Central. Translate the provided sentences into the $toLangFull language, preserving the Business Central context. After translation, verify if the result matches the level expected from a senior Business Central specialist. Output only the translated text, in the same format as the original, without any additional comments or explanations."
        },
        @{
            role = "user"
            content = $contextualText
        }
    )
    
    $jsonBody = @{
        model = "gpt-4o"
        temperature = 0.2
        top_p = 1
        messages = $messages
    } | ConvertTo-Json -Depth 10
    

    $headers = @{
        "Content-Type" = "application/json"
        "api-key" = $subscriptionKeyOpenAI 
    }

    try {
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $jsonBody
        $translatedText = $response.choices[0].message.content
        return $translatedText
    } catch {
        Write-Host "OpenAI Error during translation: $_"
        return $null
    }
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
                #$translatedText = Translate-Text -text $itText -toLang $toLang -subscriptionKey $subscriptionKey -endpoint $endpoint -location $location -categoryId $categoryId
                $translatedText = TranslateOpenAI-Text -text $itText -toLang $toLang -subscriptionKey $subscriptionKey -endpoint $endpoint -location $location -categoryId $categoryId
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
