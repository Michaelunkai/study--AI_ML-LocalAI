function Get-SafeStem {
    param(
        [string]$Path
    )

    if ($null -eq $Path) {
        return $null
    }

    $leaf = Split-Path -Leaf $Path
    if ([string]::IsNullOrWhiteSpace($leaf)) {
        return ""
    }

    return ($leaf -split '\.')[0]
}
