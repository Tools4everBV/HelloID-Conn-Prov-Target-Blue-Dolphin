#################################################
# HelloID-Conn-Prov-Target-Blue-Dolphin-Update
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
            isEmailPrimary   = "$($AccountObject.emails.primary)"
        }
        Write-Output $helloidAcountObject
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
        $convertedTargetAccount = ConvertTo-HelloIDAccountObject -AccountObject $correlatedAccount
        $outputContext.PreviousData = $convertedTargetAccount

        $splatCompareProperties = @{
            ReferenceObject  = @($convertedTargetAccount.PSObject.Properties)
            DifferenceObject = @($actionContext.Data.PSObject.Properties)
        }
        $propertiesChanged = Compare-Object @splatCompareProperties -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
        if ($propertiesChanged) {
            $action = 'UpdateAccount'
        } else {
            $action = 'NoChanges'
        }
    } else {
        $action = 'NotFound'
    }

    # Process
    switch ($action) {
        'UpdateAccount' {
            Write-Information "Account property(s) required to update: $($propertiesChanged.Name -join ', ')"

            [System.Collections.Generic.List[object]]$operations = @()
            $propertyPathMap = @{
                'Username'         = 'userName'
                'GivenName'        = 'name.givenName'
                'FamilyName'       = 'name.familyName'
                'EmailAddress'     = 'emails.value'
                'IsEmailPrimary'   = 'emails.primary'
                'EmailAddressType' = 'emails.type'
            }

            [System.Collections.Generic.List[object]]$operations = @()
            foreach ($property in $propertiesChanged) {
                if ($propertyPathMap.ContainsKey($property.Name)) {
                    $operations.Add(
                        [PSCustomObject]@{
                            op    = 'Replace'
                            path  = $propertyPathMap[$property.Name]
                            value = $property.Value
                        }
                    )
                }
            }

            $body = [ordered]@{
                schemas    = @(
                    'urn:ietf:params:scim:schemas:core:2.0:User',
                    'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User'
                )
                Operations = $operations
            } | ConvertTo-Json

            $splatUpdateUser = @{
                Uri     = "$($actionContext.Configuration.BaseUrl)/scim/v2/$($actionContext.Configuration.TenantId)/Users/$($actionContext.References.Account)"
                Headers = $headers
                Body    = $body
                Method  = 'Patch'
            }

            # Make sure to test with special characters and if needed; add utf8 encoding.
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Updating Blue-Dolphin account with accountReference: [$($actionContext.References.Account)]"
                $null = Invoke-RestMethod @splatUpdateUser
            } else {
                Write-Information "[DryRun] Update Blue-Dolphin account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            # Make sure to filter out arrays from $outputContext.Data (If this is not mapped to type Array in the fieldmapping). This is not supported by HelloID.
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Update account was successful, Account property(s) updated: [$($propertiesChanged.name -join ',')]"
                    IsError = $false
                })
            break
        }

        'NoChanges' {
            Write-Information "No changes to Blue-Dolphin account with accountReference: [$($actionContext.References.Account)]"

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = 'No changes will be made to the account during enforcement'
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "Blue-Dolphin account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Blue-Dolphin account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
                    IsError = $true
                })
            break
        }
    }
} catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Blue-DolphinError -ErrorObject $ex
        $auditMessage = "Could not update Blue-Dolphin account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not update Blue-Dolphin account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
