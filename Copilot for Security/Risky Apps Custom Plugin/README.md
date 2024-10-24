## Demo files for "Copilot for Security custom API plugins" session

Copilot for Security plugin is used to get information about Entra ID applications (app registrations) and their Graph API permissions. PowerShell plugin code to be hosted as Azure Function PowerShell app.

Prerequisites: 

- Entra ID Application registered with permissions to read Applications data in Entra ID and its credentials added to Azure Function environment variables:
    ```
    $tenantId = $env:tenantId
    $clientId = $env:clientId
    $clientSecret = $env:clientSecret
    ```
- Azure Function / function.json file updated with routes to suppory multiple functions (api endpoints):

  ```json
    {
      "bindings": [
        {
          "authLevel": "function",
          "type": "httpTrigger",
          "direction": "in",
          "name": "Request",
          "methods": [
            "get"
          ],
          "route": "entra/{func:alpha}"
        },
        {
          "type": "http",
          "direction": "out",
          "name": "Response"
        }
      ]
    }
  
  ```
- Azure Function app URL updated in OpenAPI specification
- To test your Azure Function app run the following in PowerShell:
  ```powershell
  $headers = @{
    "x-functions-key" = "<AZURE_FUNCTION_KEY"
    }

  Invoke-WebRequest -Uri "https://<AZURE_FUNCTION_APP_NAME.azurewebsites.net/api/entra/getApplicationPermissions" -Method GET -Headers $headers -Verbose
  ```
### Plugin in action

<img width="756" alt="image" src="https://github.com/user-attachments/assets/c190bcd6-742e-402e-8738-20644830534b">


### Disclaimer

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
