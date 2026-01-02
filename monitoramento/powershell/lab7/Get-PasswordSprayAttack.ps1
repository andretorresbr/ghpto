# Janela de observação dos logs (em horas)
$StartTime = (Get-Date).AddHours(-1)

# Extrai o nome do script sem a extensão
$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
# Define o path do script
$TranscriptFile = "$PSScriptRoot\$ScriptName`_execution.txt"
# Inicia o log de execução do script
Start-Transcript -Path $TranscriptFile -Force

# Retrieve a list of all domain controllers in the domain
Write-Host "Obtendo lista de Domain Controllers do dominio..." -ForegroundColor Green
$DomainControllers = Get-ADDomainController -Filter *

# Inicializa um array de achados
$AllFailedLogons = @()

# Iterate through each domain controller to collect Event ID 4625 & 4771 logs
foreach ($DC in $DomainControllers) {

    Write-Host "Analisando logs do $($DC.HostName)..." -ForegroundColor Yellow

    try {
        # NTLM / Logon Failure - Event ID 4625
        $FailedLogons4625 = Get-WinEvent -ComputerName $DC.HostName -FilterHashtable @{
            LogName   = 'Security'
            Id        = 4625
            StartTime = $StartTime
        } -ErrorAction SilentlyContinue | Select-Object `
            TimeCreated,
            @{Name="Account"; Expression={ $_.Properties[5].Value }},
            @{Name="IP";      Expression={ $_.Properties[19].Value }},
            @{Name="AuthType";Expression={ "NTLM" }}

        # Kerberos Pre-Auth Failure - Event ID 4771
        $FailedLogons4771 = Get-WinEvent -ComputerName $DC.HostName -FilterHashtable @{
            LogName   = 'Security'
            Id        = 4771
            StartTime = $StartTime
        } -ErrorAction SilentlyContinue | Select-Object `
            TimeCreated,
            @{Name="Account"; Expression={ $_.Properties[0].Value }},
            @{Name="IP";      Expression={ $_.Properties[6].Value }},
            @{Name="AuthType";Expression={ "Kerberos" }}

        # Consolida os eventos
        $AllFailedLogons += $FailedLogons4625
        $AllFailedLogons += $FailedLogons4771

    }
    catch {
        Write-Host "Erro ao consultar o $($DC.HostName): $_" -ForegroundColor Red
    }
}

# Limpeza de dados inválidos
$AllFailedLogons = $AllFailedLogons | Where-Object {
    $_.IP -and $_.IP -ne '::1'
}

# Análise de Password Spray
Write-Host "Analisando as tentativas de logon..." -ForegroundColor Green

$GroupedByIP = $AllFailedLogons | Group-Object -Property IP

# Threshold de tentativas por IP
$Threshold = 5

$SuspiciousIPs = $GroupedByIP | Where-Object {
    $_.Count -ge $Threshold
} | ForEach-Object {

    [PSCustomObject]@{
        IPAddress          = $_.Name
        AttemptCount       = $_.Count
        AttemptedAccounts  = ($_.Group | Select-Object -ExpandProperty Account | Sort-Object -Unique)
        AuthTypesObserved  = ($_.Group | Select-Object -ExpandProperty AuthType | Sort-Object -Unique)
        FirstSeen          = ($_.Group | Sort-Object TimeCreated | Select-Object -First 1).TimeCreated
        LastSeen           = ($_.Group | Sort-Object TimeCreated | Select-Object -Last 1).TimeCreated
    }
}

# Saída e notificação
if ($SuspiciousIPs) {

    Write-Host "`nAtaque potencial de Password Spray detectado!" -ForegroundColor Yellow
    $SuspiciousIPs | Format-Table -AutoSize

    $Message = $SuspiciousIPs | Out-String

    Write-Host "Enviando notificação via Telegram..." -ForegroundColor Green
    . .\Send-TelegramNotification.ps1

    Send-TelegramNotification `
        -Source $env:COMPUTERNAME `
        -Title "Ataque potencial de Password Spray detectado!" `
        -Message $Message
}
else {
    Write-Host "Não foram detectadas atividades de Password Spray." -ForegroundColor Green
}

Stop-Transcript
