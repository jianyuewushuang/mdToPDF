chcp 65001 | Out-Null
Set-Location $PSScriptRoot
Get-ChildItem -Path "./src" -Filter "*.md" | ForEach-Object {
    $inputFile = $_.FullName
    $outputFile = Join-Path "./build" ($_.BaseName + ".pdf")
    pandoc $inputFile `
        -o $outputFile `
        --from markdown+alerts `
        --template "./resources/latex/eisvogel.latex" `
        --syntax-highlighting idiomatic `
        --pdf-engine "lualatex" `
        -V CJKmainfont="SimSun" `
        -V mainfont="Source Sans 3" `
        -V mainfontfallback="Noto Color Emoji:mode=harf" `
        -V mainfontfallback="FreeSans:mode=harf" `
        -V mainfontfallback="DejaVu Sans:mode=harf" `
        --lua-filter "./resources/alerts.lua"
}
