# Janela de observação dos logs (em horas)
$StartTime = (Get-Date).AddHours(-1)

# Retrieve a list of all domain controllers in the domain
Write-Host "Obtendo lista de Domain Controllers do dominio..." -ForegroundColor Green
$DomainControllers = Get-ADDomainController -Filter *

# Inicializa um array de achados
$AllLogs = @()

foreach ($DC in $DomainControllers) {
    Write-Host "Analisando logs do $($DC.HostName)..." -ForegroundColor Yellow
    try {
        $Logs = Get-WinEvent -ComputerName $DC.HostName -FilterHashtable @{LogName='Security'; Id=4662; StartTime=$StartTime} | Where-Object { $_.Message -match '{1131f6aa-9c07-11d1-f79f-00c04fc2dcd2}' }
        $AllLogs += $Logs
    } catch {
        Write-Host "Erro ao consultar o $($DC.HostName): $_" -ForegroundColor Red
    }
}

# Obtém o(s) usuário(s) MSOL do Entra Connect
$msolUsers = Get-ADUser -Filter 'SamAccountName -like "MSOL_*"' -Properties SamAccountName

$LogsDCSync = $false
# Verifica se há logs que não sejam de DC nem do usuário MSOL do Entra Connect
foreach ($Log in $AllLogs)
{
    # Tira o $ do final dos computadores
    $Actor = $Log.Properties[1].Value.TrimEnd('$')
    # Checa se quem executou a operação não é um DC nem o usuário MSOL do Entra Connect
    if (($DomainControllerNames -notcontains $Actor) -and ($msolUsers.Name -notcontains $Actor))
    {
        $LogsDCSync = $true
    }
}

if ($LogsDCSync)
{
    $AllLogs
    $Message = @"
Execução de DCSync detectada


"@
    $DomainControllerNames = $DomainControllers | Select-Object -ExpandProperty Name
    $previousLog = $null
    foreach ($Log in $AllLogs)
    {
        # Tira o $ do final dos computadores
        $Actor = $Log.Properties[1].Value.TrimEnd('$')
        # Checa se quem executou a operação não é um DC nem o usuário MSOL do Entra Connect
        if (($PreviousLog -ne $null) -and ($DomainControllerNames -notcontains $Actor) -and ($msolUsers.Name -notcontains $Actor) -and ($PreviousLog.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss") -eq $Log.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss")))
        {
            Write-Host ("Usuario " + $Actor + " não é um DC ou conta MSOL e executou DCSync.")
            $Message += @"
💻 <b>Origem do log</b>: $($Log.MachineName)
📆 <b>Data/hora do log</b>: $($Log.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss"))
👤 <b>Usuário que executou</b>: $($Log.Properties[1].Value)


"@
        }
        $previousLog = $Log
        
    }
    Write-Host "Enviando notificação via Telegram..." -ForegroundColor Green
    . .\Send-TelegramNotification.ps1
    Send-TelegramNotification -Source $env:COMPUTERNAME -Title "Execução de DCSync detectada!" -Message $Message
} else
{
    Write-Host "Não foram encontrados logs de DCSync." -ForegroundColor Yellow
}
