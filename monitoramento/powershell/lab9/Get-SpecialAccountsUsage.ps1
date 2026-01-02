# Janela de observação dos logs (em horas)
$StartTime = (Get-Date).AddHours(-1)

# Extrai o nome do script sem a extensão
$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
# Define o path do script
$TranscriptFile = "$PSScriptRoot\$ScriptName`_execution.txt"
# Inicia o log de execução do script
Start-Transcript -Path $TranscriptFile -Force

# Define paths
$BasePath = "C:\Tools\Scripts"
$AccountsToMonitorFile = "$BasePath\ContasEspeciais_Monitoradas.txt"           # File with the list of monitored users
$FileToAttach = "$PSScriptRoot\$ScriptName`_attach.txt"

# Remove o anexo anterior
Remove-Item -Path $FileToAttach -Force -ErrorAction SilentlyContinue

# Retrieve a list of all domain controllers in the domain
Write-Host "Obtendo lista de Domain Controllers do dominio..." -ForegroundColor Green
$DomainControllers = Get-ADDomainController -Filter *

# Inicializa um array de achados
$AllLogs = @()

# Ensure base directory exists
if (-not (Test-Path -Path $BasePath)) {
    New-Item -ItemType Directory -Path $BasePath | Out-Null
}

# Carrega as contas especiais do arquivo
# Based on https://specterops.github.io/TierZeroTable/
if (-not (Test-Path -Path $AccountsToMonitorFile)) {
    Write-Output "Arquivo com contas a monitorar não encontrado: $AccountsToMonitor" -ForegroundColor Red
    Exit
}

Write-Host ("Monitorando atividades das contas presentes no arquivo : $($AccountsToMonitor -join ', ')") -ForegroundColor Yellow

$AccountsToMonitor = Get-Content -Path $AccountsToMonitorFile | Where-Object { $_ -ne "" }

# Define event IDs to monitor and their descriptions
$EventIDDescriptions = @{
    4624 = "Logon da conta com sucesso"
    4625 = "Tentativa de logon da conta com falha"
    4648 = "Credencial explícita utilizada"
    4720 = "Criação da conta"
    4722 = "Conta habilitada"
    4723 = "Tentativa de mudança de senha"
    4724 = "Reset da senha"
    4725 = "Conta desabilitada"
    4726 = "Conta deletada"
    4738 = "Propriedade da conta alterada"
	5136 = "Propriedade da conta alterada"
    4740 = "Contra travada (locked)"
}

# Extract the event IDs from the hash table
$EventIDs = @($EventIDDescriptions.Keys)


foreach ($DC in $DomainControllers) {
    Write-Host "Analisando logs do $($DC.HostName)..." -ForegroundColor Yellow
    try {
        $Logs = Get-WinEvent -ComputerName $DC.HostName -FilterHashtable @{LogName='Security'; Id=$EventIDs; StartTime=$StartTime} -ErrorAction SilentlyContinue | Where-Object { $_.Message -match ($AccountsToMonitor -join "|") }
        $AllLogs += $Logs
    } catch {
        Write-Host "Erro ao consultar o $($DC.HostName): $_" -ForegroundColor Red
    }
}



# Se houver logs
if ($AllLogs.Count -ne 0)
{
    $AllLogs
    $Message = @"
		Ação(ões) em contas especiais monitoradas encontrada(s)


"@
    $PreviousLog = $null

    foreach ($Log in $AllLogs)
    {
        if ( ($null -eq $PreviousLog) -or ( $PreviousLog.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss") -ne $Log.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss")) )
        {
            $Message += @"
💻 <b>Origem do log</b>: $($Log.MachineName)
📆 <b>Data/hora do log</b>: $($Log.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss"))
⚙️ <b>Ação executada</b>: $($Log.Id) ($($EventIDDescriptions[$Log.Id]))


"@
            
            @"
$($Log.Message)

-----------------------------------------------------------------
"@ | Out-File -FilePath $FileToAttach -Append -Encoding UTF8
        }

        $previousLog = $Log
    }
    
    Write-Host "Enviando notificação via Telegram..." -ForegroundColor Green
    . .\Send-TelegramNotification.ps1
    Send-TelegramNotification -Source $env:COMPUTERNAME -Title "Ação em contas especiais monitoradas detectada!" -Message $Message -AttachedFile $FileToAttach
} else
{
    Write-Host "Não foram encontrados logs." -ForegroundColor Yellow
}

Stop-Transcript
