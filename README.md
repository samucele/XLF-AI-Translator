# XLF AI Translator

This repository contains a PowerShell script that automates the translation of XLF files using the Azure Cognitive Services Translator API. The script reads an Italian XLF file, maps the translations, and updates other XLF files with the corresponding translations.

## Prerequisites

- PowerShell
- Azure Cognitive Services Translator API subscription
- XLF files in the `./Translations` folder
- [NAB AL Tools] Visual Studio Code extension

## Setup

1. Clone the repository to your local machine.
2. Navigate to the repository directory.
3. Replace the placeholders in the script (`XLF-AI-Translator.ps1`) with your actual Azure API subscription key and category ID.

## Script Parameters

- `$subscriptionKey`: Your Azure Cognitive Services subscription key.
- `$location`: The region of your Azure Cognitive Services instance (e.g., "westeurope").
- `$categoryId`: The custom translator category ID.

## Custom Translator Category
To improve translation quality, it is recommended to train the AI with the base translations from Microsoft Dynamics 365 Business Central in the target language. This will ensure that the terminology and context are consistent with Business Central standards.
