##################################################
# HelloID-Conn-Prov-Target-Blue-Dolphin-Delete
# PowerShell V2
##################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-Blue-DolphinError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            $httpErrorObj.FriendlyMessage = $errorDetailsObject.details
        } catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    Write-Information 'Verifying if a Blue-Dolphin account exists'
    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Authorization', "Bearer $($actionContext.Configuration.AccessToken)")
    $headers.Add('Content-Type', 'application/scim+json')

    $splatGetUsersParams = @{
        Uri     = "$($actionContext.Configuration.BaseUrl)/scim/v2/$($actionContext.Configuration.TenantId)/users/$($actionContext.References.Account)"
        Method  = 'GET'
        Headers = $headers
    }
    try {
        $correlatedAccount = Invoke-RestMethod @splatGetUsersParams
    } catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Information $_.Exception.Message
        } else {
            throw
        }
    }

    if ($null -ne $correlatedAccount) {
        $action = 'DeleteAccount'
    } else {
        $action = 'NotFound'
    }

    # Process
    switch ($action) {
        'DeleteAccount' {
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Deleting Blue-Dolphin account with accountReference: [$($actionContext.References.Account)]"
                $splatDeleteUser = @{
                    Uri     = "$($actionContext.Configuration.BaseUrl)/scim/v2/$($actionContext.Configuration.TenantId)/users/$($actionContext.References.Account)"
                    Method  = 'DELETE'
                    Headers = $headers
                }
                $null = Invoke-RestMethod @splatDeleteUser
            } else {
                Write-Information "[DryRun] Delete Blue-Dolphin account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Blue-Dolphin account: [$($actionContext.References.Account)] Delete account was successful"
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "Blue-Dolphin account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Blue-Dolphin account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
                    IsError = $false
                })
            break
        }
    }
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Blue-DolphinError -ErrorObject $ex
        $auditMessage = "Could not delete Blue-Dolphin account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not delete Blue-Dolphin account. Error: $($_.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}