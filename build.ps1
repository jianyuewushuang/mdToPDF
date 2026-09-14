chcp 65001 | Out-Null
Set-Location $PSScriptRoot
Get-ChildItem -Path "./src" -Filter "*.md" | ForEach-Object {
    $inputFile = $_.FullName
    $outputFile = Join-Path "./build" ($_.BaseName + ".pdf")
    pandoc $inputFile `
        -o $outputFile `
        --from gfm+alerts `
        --template "./resources/latex/eisvogel.latex" `
        --syntax-highlighting idiomatic `
        --pdf-engine "xelatex" `
        -V CJKmainfont="SimSun"`
        --lua-filter "./resources/alerts.lua"
}
