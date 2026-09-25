chcp 65001 | Out-Null
Set-Location $PSScriptRoot
$env:MERMAID_BIN = (Resolve-Path (Join-Path $PSScriptRoot "..\node_modules\.bin\mmdc.cmd")).Path
Get-ChildItem -Filter "*.md" | ForEach-Object {
    $inputFile = $_.FullName
    $outputFile = Join-Path "../build" ($_.BaseName + ".pdf")
    pandoc $inputFile `
        -o $outputFile `
        --from markdown+alerts `
        --template "../resources/eisvogel.latex" `
        --syntax-highlighting idiomatic `
        --pdf-engine "lualatex" `
        -V CJKmainfont="SimSun" `
        -V mainfont="Source Sans 3" `
        -V mainfontfallback="Noto Color Emoji:mode=harf" `
        -V mainfontfallback="FreeSans:mode=harf" `
        -V mainfontfallback="DejaVu Sans:mode=harf" `
        --lua-filter "../resources/alerts.lua" `
        --lua-filter "../resources/diagram.lua"
}
