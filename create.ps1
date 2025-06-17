#################################################
# HelloID-Conn-Prov-Target-Blue-Dolphin-Create
# PowerShell V2
#################################################

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

function ConvertTo-HelloIDAccountObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $AccountObject
    )
    process {
        $helloidAcountObject = [PSCustomObject]@{
            emailAddressType = $AccountObject.emails.type
            emailAddress     = $AccountObject.emails.value
            familyName       = $AccountObject.name.familyName
            givenName        = $AccountObject.name.givenName
            userName         = $AccountObject.userName
            isEmailPrimary   = $AccountObject.emails.primary
        }
        Write-Output $helloidAcountObject
    }
}
#endregion

try {
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.AccountField
        $correlationValue = $actionContext.CorrelationConfiguration.PersonFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }

        $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
        $headers.Add('Authorization', "Bearer $($actionContext.Configuration.AccessToken)")
        $headers.Add('Content-Type', 'application/scim+json')

        $splatGetUsersParams = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/scim/v2/$($actionContext.Configuration.TenantId)/users"
            Method  = 'GET'
            Headers = $headers
        }

        $allAccounts = (Invoke-RestMethod @splatGetUsersParams).resources
        $correlatedAccount = @($allAccounts | Where-Object { $_.emails.value -eq $correlationValue })
    }

    if ($correlatedAccount.Count -eq 0) {
        $action = 'CreateAccount'
    } elseif ($correlatedAccount.Count -eq 1) {
        $action = 'CorrelateAccount'
    } elseif ($correlatedAccount.Count -gt 1) {
        throw "Multiple accounts found for person where $correlationField is: [$correlationValue]"
    }

    # Process
    switch ($action) {
        'CreateAccount' {
            [System.Collections.Generic.List[object]]$emailList = @()
            $emailList.Add(
                [PSCustomObject]@{
                    value   = $actionContext.Data.emailAddress
                    display = $actionContext.Data.emailAddress
                    type    = $actionContext.Data.emailAddressType
                    primary = [bool]$actionContext.Data.isEmailPrimary
                }
            )
            $body = [ordered]@{
                schemas  = @(
                    'urn:ietf:params:scim:schemas:core:2.0:User',
                    'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User'
                )
                active   = $true
                emails   = $emailList
                userName = $actionContext.Data.userName
                name     = [ordered]@{
                    givenName  = $actionContext.Data.givenName
                    familyName = $actionContext.Data.familyName
                }
                meta     = @{
                    resourceType = 'User'
                }
            } | ConvertTo-Json -Depth 10

            $splatCreateParams = @{
                Uri     = "$($actionContext.Configuration.BaseUrl)/scim/v2/$($actionContext.Configuration.TenantId)/users"
                Method  = 'POST'
                Headers = $headers
                Body    = $body
            }

            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information 'Creating and correlating Blue-Dolphin account'
                $createdAccount = Invoke-RestMethod @splatCreateParams
                $outputContext.Data = $createdAccount
                $outputContext.AccountReference = $createdAccount.Id
            } else {
                Write-Information '[DryRun] Create and correlate Blue-Dolphin account, will be executed during enforcement'
            }
            $auditLogMessage = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)]"
            break
        }

        'CorrelateAccount' {
            Write-Information 'Correlating Blue-Dolphin account'

            $outputContext.Data = ConvertTo-HelloIDAccountObject -AccountObject $correlatedAccount
            $outputContext.AccountReference = $correlatedAccount.Id
            $outputContext.AccountCorrelated = $true
            $auditLogMessage = "Correlated account: [$($outputContext.AccountReference)] on field: [$($correlationField)] with value: [$($correlationValue)]"
            break
        }
    }

    $outputContext.success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $action
            Message = $auditLogMessage
            IsError = $false
        })
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Blue-DolphinError -ErrorObject $ex
        $auditMessage = "Could not create or correlate Blue-Dolphin account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not create or correlate Blue-Dolphin account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}