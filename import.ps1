#################################################
# HelloID-Conn-Prov-Target-FreshService-Requesters-Import
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-FreshService-RequestersError {
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
            # Make sure to inspect the error result object and add only the error message as a FriendlyMessage.
            # $httpErrorObj.FriendlyMessage = $errorDetailsObject.message
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails # Temporarily assignment
        } catch {
            $httpErrorObj.FriendlyMessage = "Error: [$($httpErrorObj.ErrorDetails)]"
            Write-Warning $_.Exception.Message
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    Write-Information 'Starting FreshService-Requesters account entitlement import'
    $importedAccounts = @(
        @{
            Id         = '1001'
            NickName   = 'John'
            FamilyName = 'Doe'
            UserName   = 'j.doe'
            Status     = 'Active'
        },
        @{
            Id         = '1002'
            NickName   = 'Jane'
            FamilyName = 'Smith'
            UserName   = 'j.smith'
            Status     = 'Inactive'
        }
    )

    # # Example of replacing the placeholder with actual code:
    # $pageSize = 50
    # $pageNumber = 1
    # do {
    #     $splatImportAccountParams = @{
    #         Uri     = "$($actionContext.Configuration.BaseUrl)/api/users/list?pageNumber=$($pageNumber)&pageSize=$($pageSize)"
    #         Method  = 'GET'
    #         Headers = $headers
    #     }
    #     $response = Invoke-RestMethod @splatImportAccountParams
    #     if ($response.data) {
    #         foreach ($importedAccount in $response.data) {
    #             $data = $importedAccount | Select-Object -Property $actionContext.ImportFields
    #             # Enabled has a -not filter because the API uses an isDisabled property, which is the exact opposite of the enabled state used by HelloID.
    #             Write-Output @{
    #                 AccountReference = $importedAccount.Id
    #                 displayName      = $displayName
    #                 UserName         = $importedAccount.UserName
    #                 Enabled          = $isEnabled
    #                 Data             = $data
    #             }
    #         }
    #     }
    #     $pageNumber++
    # } while ($pageNumber -le $response.totalPages)


    foreach ($importedAccount in $importedAccounts) {
        # Making sure only fieldMapping fields are imported
        $data = @{}
        foreach ($field in $actionContext.ImportFields) {
            $data[$field] = $importedAccount.$field
        }

        # Set Enabled based on importedAccount status
        $isEnabled = $false
        if ($importedAccount.Status -eq 'Active') {
            $isEnabled = $true
        }

        # Make sure the displayName has a value
        $displayName = "$($importedAccount.NickName) $($importedAccount.FamilyName)".trim()
        if ([string]::IsNullOrEmpty($displayName)) {
            $displayName = $importedAccount.Id
        }

        # Make sure the userName has a value
        if ([string]::IsNullOrWhiteSpace($importedAccount.UserName)) {
            $importedAccount.UserName = $importedAccount.Id
        }

        # Return the result
        Write-Output @{
            AccountReference = $importedAccount.Id
            displayName      = $displayName
            UserName         = $importedAccount.UserName
            Enabled          = $isEnabled
            Data             = $data
        }
    }
    Write-Information 'FreshService-Requesters account entitlement import completed'
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-FreshService-RequestersError -ErrorObject $ex
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import FreshService-Requesters account entitlements. Error: $($errorObj.FriendlyMessage)"
    } else {
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import FreshService-Requesters account entitlements. Error: $($ex.Exception.Message)"
    }
}