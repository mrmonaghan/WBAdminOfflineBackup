#Function to create basic logging objects for each step of the process
Function New-LogObject {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory)]
        [object]$Text,

        [Parameter(Mandatory)]
        [object]$Status
    )

    begin {}
    process {
            $LogObject = [PSCustomObject]@{
                Text = $Text
                Status = $Status
                Timestamp = Get-Date
            }
        }
    end {
            Write-Output $LogObject
    }
}
#function to send mail using AWS SES
function Send-SESEmail {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory)]
        [string]$To,

        [Parameter(Mandatory)]
        [String]$Subject,

        [Parameter(Mandatory)]
        [object]$Body,

        [Parameter()]
        [String]$Attachment


        )

    begin {
        $AWSSMTPUsername = "<ENTER USERNAME HERE>"
        $AWSSMTPSecret = "<ENTER SECRET KEY HERE>"


        $SECURE_KEY = $(ConvertTo-SecureString -AsPlainText -String $AWSSMTPSecret -Force)
        $creds = $(New-Object System.Management.Automation.PSCredential ($AWSSMTPUsername, $SECURE_KEY))

        $Params = @{
            To = $To
            From = "<ENTER 'FROM' ADDRESS HERE>"
            Subject = $Subject
            Body = $Body
            SmtpServer = "<ENTER AWS SES REGION URL HERE>"
            Credential = $Creds
            Port = 587
            UseSSL = $True
            }
    }

    process {
        if ($Attachment) {
            $Params.Attachments = $Attachment
            }
        }

    end {
        Send-MailMessage @Params
        }
}

#Create a new List object to add LogObjects to
$LogResults = New-Object System.Collections.Generic.List[System.Object]

#Start Transcript, captures verbose output
$Date = Get-Date -Format "yyyy-MM-dd"
Start-Transcript -Path "C:\Users\$env:Username\Logs\WindowsImageBackup - $Date.log"

#Meat and/or potatoes
try {
    #Mount the volume and log the results to $LogResults
    $Step = "Mount Volume"
    Write-Verbose $Step
    $VolumeID = '<Insert Volume GUID string>'
    mountvol E: $VolumeID
    $LogResults.Add((New-LogObject -Text $Step -Status "Complete"))

    #Close any open SMB connections (LOB Application Requirement)
    $Step = "Closing Open SMB Files"
    Write-Verbose $Step
    Get-SMBOpenFIle | Where-Object {$_.Path -like "<YOUR LOB APP>"} | Close-SMBOpenFile -Force
    $LogResults.Add((New-LogObject -Text $Step -Status "Complete"))

    #Start the WBAdmin process, wait for the backup process to finish, log the results.
    $Step = "Starting WBAdmin"
    Write-Verbose $Step
    $Process = Start-Process -File "wbadmin" -ArgumentList 'start backup -backupTarget:E: -include:C: -quiet -allCritical' -PassThru
    $Step = "Waiting on WBADmin Job to Complete"
    Wait-Process -InputObject $Process
    $LogResults.Add((New-LogObject -Text "WBAdmin Backup Job" -Status "Complete"))

    #Check for backups older than defined by $RetentionDays and remove them. BY FORCE.
    $RetentionDays = "<SET RETENTION DAYS HERE>"
    $Step = "Remove backups older than $RetentionDays days"
    Write-Verbose $Step
    $RetentionPeriod = (get-date (Get-Date).AddDays(-$RetentionDays) -Format "yyyy-MM-dd hh:mm:ss tt")
    Get-ChildItem E:\WindowsImageBackup -Recurse -Force| Where-Object {$_.LastWriteTime -le $RetentionPeriod} | Remove-Item -Force -recurse
    $LogResults.Add((New-LogObject -Text $Step -Status "Complete"))

    #Eject volume and log the results to $LogResults
    $Step = "Eject Drive"
    Write-Verbose $Step
    $EjectDrive = Get-WmiObject -Class Win32_Volume | Where-Object {$_.label -like "<ENTER BACKUP DRIVE NAME OR PARTIAL NAME HERE>"}
    $EjectDriveLetter = $EjectDrive.DriveLetter
    mountvol $EjectDriveLetter /p
    $LogResults.Add((New-LogObject -Text $Step -Status "Complete"))
    $ScriptComplete = $true
    }
catch {
    Write-Verbose "Error encountered. Error code: $Error"
    $LogResults.Add((New-LogObject -Text $Step -Status $Error))
}

$LogResults | Out-File C:\Temp\Results.log
$LogString = $LogResults | Out-String
$LogResults.Add((New-LogObject -Text "Output Log File" -Status "Complete"))
if ($ScriptComplete) {
    Send-SESEmail -To youremail@domain.com -Subject "Backup Complete" -Body $LogString -Attachment C:\Temp\Results.log
    }
else {
    Send-SESEmail -To youremail@domain.com-Subject "Backup Error on $env:Computername" -Body $LogString -Attachment C:\Temp\Results.log
}

Stop-Transcript
