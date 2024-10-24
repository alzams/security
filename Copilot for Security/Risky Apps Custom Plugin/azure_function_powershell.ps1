using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)


# Define the necessary variables
$tenantId = $env:tenantId
$clientId = $env:clientId
$clientSecret = $env:clientSecret
$scope = "https://graph.microsoft.com/.default"
$tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$graphApiEndpoint = "https://graph.microsoft.com/v1.0/applications"

# Function to get the OAuth 2.0 token
function Get-OAuthToken {
    $body = @{
        client_id     = $clientId
        scope         = $scope
        client_secret = $clientSecret
        grant_type    = "client_credentials"
    }

    try {
        $response = Invoke-WebRequest -Uri $tokenEndpoint -Method Post -ContentType "application/x-www-form-urlencoded" -Body $body
        return ($response.Content | ConvertFrom-Json).access_token
    } catch {
        # Return null in case of an error
        return $null
    }
}

# Function to retrieve Azure AD applications
function Get-EntraApps {
    param($token)

    $headers = @{
        Authorization = "Bearer $token"
    }

    try {
        $applicationsResponse = Invoke-WebRequest -Uri $graphApiEndpoint -Headers $headers -Method Get
        return ($applicationsResponse.Content | ConvertFrom-Json).value
    } catch {
        return $null
    }
}

# Function to retrieve permission references from Graph API
function Get-GraphPermissionsReference {
    param($headers)

    $permissionsReferenceEndpoint = "https://graph.microsoft.com/v1.0/servicePrincipals(appId='00000003-0000-0000-c000-000000000000')?`$select=id,appId,displayName,appRoles,oauth2PermissionScopes,resourceSpecificApplicationPermissions"
    try {
        $permissionsReferenceResponse = Invoke-WebRequest -Uri $permissionsReferenceEndpoint -Headers $headers -Method Get
        return ($permissionsReferenceResponse.Content | ConvertFrom-Json)
    } catch {
        return $null
    }
}

# Function to retrieve permissions based on type (Application or Delegated)
function Get-GraphPermissions {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Application", "Delegated")]
        [string]$permissionType,
        [array]$applications,
        [object]$permissionsReference
    )

    $appPermissions = @{}
    foreach ($app in $applications) {
        if ($null -ne $app.requiredResourceAccess) {
            foreach ($requiredResourceAccess in $app.requiredResourceAccess) {
                foreach ($resourceAccess in $requiredResourceAccess.resourceAccess) {
                    $permission = $null
                    if ($permissionType -eq "Application") {
                        $permission = $permissionsReference.appRoles | Where-Object { $_.id -eq $resourceAccess.id }
                    } elseif ($permissionType -eq "Delegated") {
                        $permission = $permissionsReference.oauth2PermissionScopes | Where-Object { $_.id -eq $resourceAccess.id }
                    }
                    if ($permission) {
                        if (-not $appPermissions.ContainsKey($app.displayName)) {
                            $appPermissions[$app.displayName] = @()
                        }
                        $appPermissions[$app.displayName] += $permission.value
                    }
                }
            }
        }
    }
    return $appPermissions
}

# Determine the requested path
$path = $Request.OriginalUrl

# Get OAuth Token
$token = Get-OAuthToken

if (-not $token) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
        StatusCode = [HttpStatusCode]::InternalServerError
        ContentType = "application/json"
        Body = '{"message": "Failed to fetch access token"}'
    })
    return
}

# Retrieve Entra ID applications
$applications = Get-EntraApps -token $token

if (-not $applications) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
        StatusCode = [HttpStatusCode]::InternalServerError
        ContentType = "application/json"
        Body = '{"message": "Failed to query applications from Graph API"}'
    })
    return
}

# Prepare headers for further API calls
$headers = @{
    Authorization = "Bearer $token"
}

# Retrieve permission reference data
$permissionsReference = Get-GraphPermissionsReference -headers $headers

if (-not $permissionsReference) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
        StatusCode = [HttpStatusCode]::InternalServerError
        ContentType = "application/json"
        Body = '{"message": "Failed to query permission references from Graph API"}'
    })
    return
}

# Handle /getApplicationPermissions endpoint
if ($Request.Params.func -eq "getApplicationPermissions") {
    try {
        $appPermissions = Get-GraphPermissions -permissionType "Application" -applications $applications -permissionsReference $permissionsReference
    } catch {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
            StatusCode = [HttpStatusCode]::InternalServerError
            ContentType = "application/json"
            Body = '{"message": "Failed to fetch application permissions."}'
        })
        return
    }

    # Return the application permissions
    $body = $appPermissions | ConvertTo-Json -Depth 4
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
        StatusCode = [HttpStatusCode]::OK
        ContentType = "application/json"
        Body = $body
    })

 # Handle /getDelegatedPermissions endpoint
} elseif ($Request.Params.func -eq "getDelegatedPermissions") {
    try {
        $delegatedPermissions = Get-GraphPermissions -permissionType "Delegated" -applications $applications -permissionsReference $permissionsReference
    } catch {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
            StatusCode = [HttpStatusCode]::InternalServerError
            ContentType = "application/json"
            Body = '{"message": "Failed to fetch delegated permissions."}'
        })
        return
    }

    # Return the delegated permissions
    $body = $delegatedPermissions | ConvertTo-Json -Depth 4
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
        StatusCode = [HttpStatusCode]::OK
        ContentType = "application/json"
        Body = $body
    })

} else {
    # Handle unknown endpoint
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
        StatusCode = [HttpStatusCode]::NotFound
        ContentType = "application/json"
        Body = '{"message": "Endpoint not found"}'
    })
}
