<#
.SYNOPSIS
  Crea o reutiliza un Azure Databricks Premium workspace para los laboratorios DP-750.
.DESCRIPTION
  Azure Cloud Shell (PowerShell 7) / PowerShell con Azure CLI.
  Comprueba recursos con JSON, instala la extension de Databricks si falta
  y no confunde valores null/None con workspaces existentes.
.EXAMPLE
  ./scripts/deploy-databricks.ps1
.EXAMPLE
  ./scripts/deploy-databricks.ps1 -ResourceGroup rg-lab02 -WorkspaceName adb-lab02 -Location switzerlandnorth
#>
param(
    [string]$ResourceGroup = 'rg-dp750',
    [string]$WorkspaceName = 'adb-dp750',
    [ValidateSet('norwayeast', 'switzerlandnorth')]
    [string]$Location = 'norwayeast',
    [ValidateSet('premium', 'standard', 'trial')]
    [string]$Sku = 'premium'
)

$ErrorActionPreference = 'Stop'
# Los codigos de salida se comprueban expresamente en las funciones siguientes.
# Evita que un aviso de stderr de una CLI nativa se confunda con una excepcion de PowerShell.
$PSNativeCommandUseErrorActionPreference = $false

function Invoke-AzJson {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Action
    )

    $lines = & az @Arguments --only-show-errors --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI ha fallado durante: $Action (exit code: $LASTEXITCODE)."
    }
    $json = $lines -join "`n"
    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "Azure CLI no ha devuelto JSON durante: $Action."
    }
    try {
        return (ConvertFrom-Json -InputObject $json -ErrorAction Stop)
    } catch {
        throw "No se ha podido interpretar el JSON de Azure CLI durante: $Action. $($_.Exception.Message)"
    }
}

function Invoke-AzCommand {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Action
    )

    & az @Arguments --only-show-errors --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI ha fallado durante: $Action (exit code: $LASTEXITCODE)."
    }
}

Write-Host 'Comprobando la sesion de Azure...'
$account = Invoke-AzJson -Arguments @('account', 'show') -Action 'comprobar la sesion de Azure'
Write-Host "Suscripcion activa: $($account.name)"

Write-Host 'Comprobando la extension databricks...'
$extensions = Invoke-AzJson -Arguments @('extension', 'list') -Action 'listar extensiones'
$hasDatabricks = @($extensions | Where-Object { $_ -and $_.name -eq 'databricks' }).Count -gt 0
if (-not $hasDatabricks) {
    Write-Host 'Instalando la extension databricks...'
    Invoke-AzCommand -Arguments @('extension', 'add', '--name', 'databricks', '--yes', '--allow-preview', 'true') -Action 'instalar extension databricks'
} else {
    Write-Host 'Extension databricks instalada.'
}

Write-Host "Comprobando el resource group: $ResourceGroup"
$groupExists = Invoke-AzJson -Arguments @('group', 'exists', '--name', $ResourceGroup) -Action 'consultar el resource group'
if ($groupExists -eq $false) {
    Write-Host "Creando resource group '$ResourceGroup' en '$Location'..."
    Invoke-AzCommand -Arguments @('group', 'create', '--name', $ResourceGroup, '--location', $Location) -Action 'crear el resource group'
} elseif ($groupExists -eq $true) {
    Write-Host "El resource group '$ResourceGroup' ya existe. Se reutilizara."
} else {
    throw "Azure CLI ha devuelto un valor inesperado al comprobar el resource group: $groupExists"
}

# Usamos el inventario ARM y JSON, no una consulta TSV que pueda devolver 'None'.
Write-Host "Comprobando el workspace: $WorkspaceName"
$resources = Invoke-AzJson -Arguments @(
    'resource', 'list', '--resource-group', $ResourceGroup,
    '--resource-type', 'Microsoft.Databricks/workspaces'
) -Action 'listar los workspaces del resource group'

$existingWorkspace = @($resources | Where-Object { $_ -and $_.name -eq $WorkspaceName } | Select-Object -First 1)
if ($existingWorkspace.Count -eq 0) {
    Write-Host "El workspace '$WorkspaceName' no existe. Creandolo en '$Location' con SKU '$Sku'..."
    Invoke-AzCommand -Arguments @(
        'databricks', 'workspace', 'create',
        '--resource-group', $ResourceGroup,
        '--name', $WorkspaceName,
        '--location', $Location,
        '--sku', $Sku,
        '--compute-mode', 'Hybrid'
    ) -Action 'crear el workspace de Azure Databricks'
} else {
    Write-Host "El workspace '$WorkspaceName' ya existe. No se creara otro."
    if ($existingWorkspace[0].location -and $existingWorkspace[0].location -ne $Location) {
        Write-Warning "El workspace existente esta en '$($existingWorkspace[0].location)', no en '$Location'. No se modificara."
    }
}

$workspace = Invoke-AzJson -Arguments @(
    'databricks', 'workspace', 'show',
    '--resource-group', $ResourceGroup, '--name', $WorkspaceName
) -Action 'verificar el workspace'

# El estado puede aparecer bajo properties en la API o plano en algunas respuestas CLI.
$status = $workspace.properties.provisioningState
if (-not $status) { $status = $workspace.provisioningState }
$url = $workspace.properties.workspaceUrl
if (-not $url) { $url = $workspace.workspaceUrl }

Write-Host ''
Write-Host "Workspace: $($workspace.name)"
Write-Host "Resource group: $ResourceGroup"
Write-Host "Region: $($workspace.location)"
Write-Host "SKU: $($workspace.sku.name)"
Write-Host "Estado: $status"
if ($url) { Write-Host "URL: https://$url" }

if ($status -ne 'Succeeded') {
    throw "El workspace no esta listo. Estado: $status. Revisa el despliegue en Azure Portal."
}
Write-Host 'Despliegue completado correctamente.'
