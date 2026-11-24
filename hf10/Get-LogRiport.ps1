<#
.SYNOPSIS
    Webszerver-log összesítése PowerShell-objektumokként.
.DESCRIPTION
    A HF4 generátorának formátumát dolgozza fel. A státuszszűrés minden
    statisztikára érvényes; az órák a logban szereplő helyi időt követik.
    Az eredmény egységes mezőket tartalmazó riport-sorokból áll. A Csendes
    kapcsoló csak az összefoglaló sort adja vissza.
.EXAMPLE
    .\Get-LogRiport.ps1 -Path access.log | Format-Table
.EXAMPLE
    .\Get-LogRiport.ps1 -Path access.log -Status 404 -Top 3 |
        Export-Csv riport.csv -NoTypeInformation
.EXAMPLE
    .\Get-LogRiport.ps1 -Path access.log -Csendes | ConvertTo-Json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$Top = 10,

    [ValidateRange(100, 599)]
    [int]$Status,

    [switch]$Csendes
)

function New-RiportSor {
    param(
        [string]$Tipus,
        [AllowNull()][object]$Kulcs = $null,
        [int]$Keresek = 0,
        [AllowNull()][object]$Arany = $null,
        [AllowNull()][object]$EgyediIP = $null,
        [AllowNull()][object]$AtlagValaszido = $null,
        [AllowNull()][object]$Atlag200 = $null,
        [AllowNull()][object]$Atlag500 = $null,
        [AllowNull()][object]$Csucs = $null
    )

    [pscustomobject][ordered]@{
        Tipus = $Tipus
        Kulcs = $Kulcs
        Keresek = $Keresek
        Arany = $Arany
        EgyediIP = $EgyediIP
        AtlagValaszido = $AtlagValaszido
        Atlag200 = $Atlag200
        Atlag500 = $Atlag500
        Csucs = $Csucs
    }
}

try {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item -isnot [System.IO.FileInfo]) {
        throw "A megadott útvonal nem fájl: $Path"
    }

    $pattern = '^(?<ip>\S+)\s+\S+\s+\S+\s+\[(?<date>\d{2}/[A-Za-z]{3}/\d{4}:\d{2}:\d{2}:\d{2})\s+\S+\]\s+"[^"\s]+\s+(?<url>\S+)\s+[^"\s]+"\s+(?<status>\d{3})\s+\S+\s+(?<time>\d+(?:\.\d+)?)\s*$'
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $records = [System.Collections.Generic.List[object]]::new()
    $lineNumber = 0

    foreach ($line in Get-Content -LiteralPath $item.FullName -ErrorAction Stop) {
        $lineNumber++
        if ($line -cnotmatch $pattern) {
            throw "Hibás logformátum a(z) $lineNumber. sorban."
        }

        $timestamp = [datetime]::MinValue
        $responseTime = [decimal]::Zero
        if (-not [datetime]::TryParseExact(
                $Matches.date, 'dd/MMM/yyyy:HH:mm:ss', $culture,
                [System.Globalization.DateTimeStyles]::None, [ref]$timestamp) -or
            -not [decimal]::TryParse(
                $Matches.time, [System.Globalization.NumberStyles]::AllowDecimalPoint,
                $culture, [ref]$responseTime)) {
            throw "Hibás időbélyeg vagy válaszidő a(z) $lineNumber. sorban."
        }

        $code = [int]$Matches.status
        if ($PSBoundParameters.ContainsKey('Status') -and $code -ne $Status) {
            continue
        }

        $records.Add([pscustomobject]@{
            IP = $Matches.ip
            URL = $Matches.url
            Status = $code
            Ora = $timestamp.Date.AddHours($timestamp.Hour)
            Valaszido = $responseTime
        })
    }

    $total = $records.Count
    $ips = @($records | Group-Object -Property IP -CaseSensitive |
        Sort-Object -CaseSensitive -Property @{ Expression = 'Count'; Descending = $true }, Name)
    $average = $null
    $average200 = $null
    $average500 = $null
    $topIP = $null
    $topShare = $null
    if ($total -gt 0) {
        $average = ($records | Measure-Object -Property Valaszido -Average).Average
        $topIP = $ips[0].Name
        $topShare = 100.0 * $ips[0].Count / $total
        $status200 = @($records | Where-Object Status -eq 200)
        $status500 = @($records | Where-Object Status -eq 500)
        if ($status200.Count -gt 0) {
            $average200 = ($status200 | Measure-Object -Property Valaszido -Average).Average
        }
        if ($status500.Count -gt 0) {
            $average500 = ($status500 | Measure-Object -Property Valaszido -Average).Average
        }
    }

    New-RiportSor -Tipus 'Osszesen' -Kulcs $topIP -Keresek $total `
        -Arany $topShare -EgyediIP $ips.Count -AtlagValaszido $average `
        -Atlag200 $average200 -Atlag500 $average500

    if (-not $Csendes) {
        foreach ($group in @($ips | Select-Object -First $Top)) {
            New-RiportSor -Tipus 'IP' -Kulcs $group.Name -Keresek $group.Count `
                -Arany (100.0 * $group.Count / $total)
        }
        foreach ($group in @($records | Group-Object -Property Status | Sort-Object { [int]$_.Name })) {
            New-RiportSor -Tipus 'Status' -Kulcs ([int]$group.Name) -Keresek $group.Count `
                -Arany (100.0 * $group.Count / $total)
        }
        foreach ($group in @($records | Where-Object { $_.Status -ge 400 -and $_.Status -lt 600 } |
                Group-Object -Property URL -CaseSensitive | Sort-Object -CaseSensitive Name)) {
            New-RiportSor -Tipus 'HibasURL' -Kulcs $group.Name -Keresek $group.Count
        }
        $hours = @($records | Group-Object -Property Ora | Sort-Object { $_.Group[0].Ora })
        $peak = if ($hours.Count -gt 0) {
            ($hours | Measure-Object -Property Count -Maximum).Maximum
        }
        foreach ($group in $hours) {
            New-RiportSor -Tipus 'Ora' -Kulcs $group.Group[0].Ora -Keresek $group.Count `
                -Csucs ($group.Count -eq $peak)
        }
    }
}
catch {
    throw
}
