# Janela de observação dos logs (em horas)
$StartTime = (Get-Date).AddHours(-1)

# Define paths
$BasePath = "C:\Tools\Scripts"
$GroupFile = "$BasePath\Grupos_Monitorados.txt"           # File with the list of monitored groups

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
$AllLogs = @()

# Ensure base directory exists
if (-not (Test-Path -Path $BasePath)) {
    New-Item -ItemType Directory -Path $BasePath | Out-Null
}

# Load monitored groups from file
# Based on https://specterops.github.io/TierZeroTable/
if (-not (Test-Path -Path $GroupFile)) {
    Write-Output "Group file not found: $GroupFile"
    Exit
}

$MonitoredGroups = Get-Content -Path $GroupFile | Where-Object { $_ -ne "" }

# Define Event IDs to monitor
$EventIDs = @("4728", "4729", "4732", "4733", "4756", "4757")


foreach ($DC in $DomainControllers) {
    Write-Host "Analisando logs do $($DC.HostName)..." -ForegroundColor Yellow
    try {
        $Logs = Get-WinEvent -ComputerName $DC.HostName -FilterHashtable @{LogName='Security'; Id=$EventIDs; StartTime=$StartTime} -ErrorAction SilentlyContinue | Where-Object { $_.Message -match 'Group Name:\s*' + ($MonitoredGroups -join "|") } 
        $AllLogs += $Logs
    } catch {
        Write-Host "Erro ao consultar o $($DC.HostName): $_" -ForegroundColor Red
    }
}

# Se houver logs
if ($AllLogs.Count -ne 0)
{
    $AllLogs
    $Message = "" + $AllLogs.Count + " modificação(ões) de grupos monitorados encontrado(s)`n"
    foreach ($Log in $AllLogs)
    {
        if ($Log.Message -match "added")
        {
            $Acao = "adicionada"
        } else {
            $Acao = "removida"
        }

        $Message += "
        💻 <b>Origem do log</b>: " + $Log.MachineName + "
        📆 <b>Data/hora do log</b>: " + $Log.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss") + "
        👥 <b>Grupo modificado</b>: " + $Log.Properties[2].Value + "
        👤 <b>Usuário que executou</b>: " + $Log.Properties[6].Value + "
        👨‍💼 <b>Conta " + $Acao + "</b>: " + $Log.Properties[0].Value + "`n`n" 
    }
    Write-Host "Enviando notificação via Telegram..." -ForegroundColor Green
    . .\Send-TelegramNotification.ps1
    Send-TelegramNotification -Source $env:COMPUTERNAME -Title "Modificação de grupos monitorados detectada!" -Message $Message
} else
{
    Write-Host "Não foram encontrados logs." -ForegroundColor Yellow
}

Stop-Transcript
