#################################################
# HelloID-Conn-Prov-Target-Blue-Dolphin-Permissions-Groups-Revoke
# revoke group to account
# PowerShell V2
#################################################
# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($actionContext.Configuration.isDebug) {
    $true { $VerbosePreference = "Continue" }
    $false { $VerbosePreference = "SilentlyContinue" }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

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
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
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
        }
        catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
        }
        Write-Output $httpErrorObj
    }
}
#endregion functions

try {

    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        if ($actioncontext.dryrun -eq $false) {
            throw 'The account reference could not be found'
        }
        else {
            write-warning "[DryRun]: The account reference could not be found"
        }
    }
    #endregion Verify account reference

    #region Create authorization headers
    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Authorization', "Bearer $($actionContext.Configuration.AccessToken)")
    $headers.Add('Content-Type', 'application/scim+json')
    #endregion Create authorization headers

    #region revoke permission to account
    # Microsoft docs: https://learn.microsoft.com/en-us/graph/api/group-post-members?view=graph-rest-1.0&tabs=http
    write-warning "revoking group [$($actionContext.References.Permission.Name)] with id [$($actionContext.References.Permission.id)] from account"

    $scimPatch = [ordered]@{
                schemas    = @('urn:ietf:params:scim:api:messages:2.0:PatchOp')
                Operations = @(
                    @{
                        op    = 'Remove'
                        path = 'members'        
                        value = @(
                            @{
                                value = $actionContext.References.Account
                            }
                        )
                        
                    }
                )
            }
            $revokeFromGroupParam = @{
                Uri     = "$($actionContext.Configuration.BaseUrl)/scim/v2/$($actionContext.Configuration.TenantId)/groups/$($actionContext.References.Permission.id)"
                Method  = 'PATCH'
                Headers = $headers
                Body    = ($scimPatch | ConvertTo-Json -Depth 10)
            }
    
    if (-Not($actionContext.DryRun -eq $true)) {
        $null = Invoke-RestMethod @revokeFromGroupParam
    }else {
        Write-Warning "[DryRun]: Would revoke group [$($actionContext.References.Permission.Name)] with id [$($actionContext.References.Permission.id)] from account with AccountReference: $($actionContext.References.Account | ConvertTo-Json)."
        write-warning "[DryRun]: body: $($revokeFromGroupParam.body)"
    }

            
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            # Action  = "" # Optional
            Message = "Revoked group [$($actionContext.References.Permission.Name)] with id [$($actionContext.References.Permission.id)] from account with AccountReference: $($actionContext.References.Account)."
            IsError = $false
        })
    #endregion revoke permission to account
}
catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Blue-DolphinError -ErrorObject $ex
        $auditMessage = "Could not update Blue-Dolphin account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not update Blue-Dolphin account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if ($outputContext.AuditLogs.IsError -contains $true) {
        $outputContext.Success = $false
    }
    else {
        $outputContext.Success = $true
    }
}