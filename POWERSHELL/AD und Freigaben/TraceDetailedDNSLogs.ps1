function Get-DNSDebugLog
{
    <#
    .SYNOPSIS
    This cmdlet parses a Windows DNS Debug log with details.

    Author: @jarsnah12
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

    .DESCRIPTION
    When a DNS log is converted with this cmdlet it will be turned into objects for further parsing.

    .EXAMPLE
    PS C:\> Get-DNSDebugLog -DNSLog ".\Something.log"

        IP            Port  DNS query        Data     
        --            ----  ---------        ----     
        192.168.1.102 49893 potato.lab.local 127.0.0.2
        192.168.1.10  4893  potato.lab.local 127.0.0.2
        

    #>

    [CmdletBinding()]
    param(
      [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
      [Alias('Fullname')]
      [ValidateScript({Test-Path($_)})]
      [string] $DNSLog = 'StringMode')


    BEGIN { }

    PROCESS {
        try
        {
            #empty array
            $AllObjectsArray = @()

            $Log = Get-Content $DNSLog
            $Matches = $Log | Select-String -Pattern "UDP response info" -Context 0,35
                        
            foreach($entry in $Matches)
            {
                
                #Data
                if($entry.Context.PostContext[34] -like "*127.0.0.2*")
                {

                    $LogObject = New-Object PSObject
                    $LogObject | Add-Member NoteProperty 'IP' $entry.Context.PostContext[1].Split(" ")[4].split(",")[0]
                    $LogObject | Add-Member NoteProperty 'Port' $entry.Context.PostContext[1].Split(" ")[6]

                    #DNS Name queried
                    if($entry.Context.PostContext[24].Split("`"")[1])
                    {
                        $LogObject | Add-Member NoteProperty 'DNS query' ((($entry.Context.PostContext[24].Split("`"")[1]) -replace "`\(.*?`\)","." -replace "^.","").trim("."))
                    }

                    $LogObject | Add-Member NoteProperty 'Data' $entry.Context.PostContext[34].Split(" ")[9]
                    $AllObjectsArray += $LogObject
                }
            }
            return $AllObjectsArray
        }
        catch
        {
            Write-Error $_
        }
        finally
        {
        }
    }
    END { }
}