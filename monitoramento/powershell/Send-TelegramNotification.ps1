function Get-UserDirectChatId {   
    param (
        [Parameter(Mandatory)]
        [string]$User
    )

    $ChatMappingFile = ".\TelegramUsersMapping.txt"
    # Load the chat mapping from the text file
    if (Test-Path $ChatMappingFile) {
        # Read the file and create the hashtable
        $ChatMapping = @{}
        Get-Content $ChatMappingFile | ForEach-Object {
            $parts = $_ -split "="
            if ($parts.Length -eq 2) {
                $ChatMapping[$parts[0]] = $parts[1]
            }
        }
    } else {
        #Write-Error "Chat mapping file '$ChatMappingFile' not found."
        return $null
    }

    # Determines Chat ID
    if ($ChatMapping.ContainsKey($User)) {
        # Sets ChatID to the respective user
        $ChatID = $ChatMapping[$User]
        return $ChatID
    } else {
        #Write-Error "The provided User key '$User' is not defined in the mapping."
        return $null
    }
}

function Send-TelegramNotification {
    ### Needs to be run from a 6.1.0+ PowerShell session
    ### Install PoshGram module from PSGallery
    #Install-Module -Name PoshGram -Repository PSGallery -Scope CurrentUser -AllowClobber -Force

    # How to create bots: https://github.com/jacauc/WinLoginAudit
    # https://stackoverflow.com/questions/41664810/how-can-i-send-a-message-to-someone-with-my-telegram-bot-using-their-username
    
    param (
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter()]
        [string]$AttachedFile
    )
    
    # Set your bot token and chat channel id
    $botToken = "66xxxxxx:yyyyyyyyyyyyyyyWqUc"
    # ID do chat do grupo que vai receber as mensagens
    $chatID = "-40xxxxxxxxx3"
    #$LogFile = "C:\Tools\Scripts\logs.txt"

    try
    {
        # https://core.telegram.org/bots/api#formatting-options
        # https://poshgram.readthedocs.io/en/latest/PoshGram-Basics/
        # https://emojidb.org/server-emojis
        Import-Module -Name PoshGram
        $Message = @"
		⚠️ <b>ALERTA DE ATIVIDADES - Active Directory</b> ⚠️

		🌐 Coletor do log: <b>$Source</b>

		⛔ <u>$Title</u> ⛔

		<pre><code class="language-powershell">
		$Message
		</code></pre>

"@

        Send-TelegramTextMessage -BotToken $botToken -ChatID $chatID -Message $Message
        if ($AttachedFile)
        {
            Send-TelegramLocalDocument -BotToken $botToken -ChatID $chatID -File $AttachedFile
        }        
    }
    catch [Exception]
    {
        $_.Exception.ToString().Split(".")[2]
    }
}

function Send-DirectTelegramNotification {   
    param (
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$SendTo,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter()]
        [string]$AttachedFile
    )
    
    # Obtém o chatID do usuário informado. Se não estiver cadastrado no arquivo de mapeamento, obtém $null
    $chatID = Get-UserDirectChatId -User $SendTo

    if ($null -ne $chatID)
    {
        # Token of ghadd_bot
        $botToken = "66xxxxxx:yyyyyyyyyyyyyyyWqUc"
        
        try
        {
            Import-Module -Name PoshGram
            $MessageBody = $Message   # conteúdo técnico previamente montado

			$Message = @"
			⚠️ <b>ALERTA DE ATIVIDADES - Active Directory</b> ⚠️

			👤 Usuário: <b>$SendTo</b>
			🌐 Coletor do log: <b>$Source</b>

			⛔ <u>$Title</u> ⛔

			<pre><code class="language-powershell">
			$MessageBody
			</code></pre>

"@
            
            Send-TelegramTextMessage -BotToken $botToken -ChatID $chatID -Message $Message
            if ($AttachedFile)
            {
                Send-TelegramLocalDocument -BotToken $botToken -ChatID $chatID -File $AttachedFile
            }
        }
        catch [Exception]
        {
            $_.Exception.ToString().Split(".")[2]
        }
    }
    else {
        Write-Host ("Destinatario " + $SendTo + " não está na cadastrado no arquivo de mapeamento de usuários do Telegram") -ForegroundColor Yellow
    }
    
}

