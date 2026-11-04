# Lab 00 — Configuración de Azure Databricks Premium (DP-750)

> **Objetivo:** aprovisionar un workspace de **Azure Databricks Premium** para los laboratorios del curso **DP-750**, utilizando **Azure Cloud Shell**, un **repositorio privado de GitHub** y un script de **PowerShell + Azure CLI** reutilizable.
>
> **Alcance:** este README documenta el procedimiento utilizado y cómo comprobar el resultado. La ejecución de los comandos y el estado `Succeeded` deben verificarse en la suscripción correspondiente.

## 1. Contexto y solución adoptada

El laboratorio oficial propone ejecutar un script remoto desde Azure Cloud Shell:

```bash
curl -sL https://raw.githubusercontent.com/MicrosoftLearning/DP-750T00-Implement-Data-Engineering-Solutions-using-Azure-Databricks/refs/heads/main/Instructions/Labs/00-setup.sh | bash
```

En nuestro caso, ese script seleccionó **`westeurope`** y Azure rechazó la creación del workspace `adb-dp750` con el error **`RequestDisallowedByAzure`**. El problema era una **política de regiones permitidas de la suscripción**, no un fallo del grupo de recursos ni de las credenciales.

Se sustituyó el aprovisionamiento original por el script **`deploy-databricks-v3.ps1`**, almacenado en un **repositorio privado de GitHub**, que:

1. Comprueba la sesión y la suscripción activa de Azure.
2. Comprueba e instala, si es necesario, la extensión `databricks` de Azure CLI.
3. Crea o reutiliza el **resource group**.
4. Comprueba con JSON si ya existe el **workspace**.
5. Crea un **Azure Databricks Premium workspace** en una región elegida explícitamente.
6. Consulta el recurso y exige que el estado final sea **`Succeeded`**.

> **Nota:** las primeras versiones del script daban un falso positivo de «workspace existente» y luego devolvían `ResourceNotFound`. La versión **v3** cambió la comprobación de existencia para utilizar el inventario de recursos de Azure en formato JSON.

## 2. Requisitos previos

- Una suscripción de Azure activa; en esta práctica se utilizó **Azure for Students**.
- Permisos para crear **resource groups** y **Microsoft.Databricks/workspaces**.
- Acceso a **Azure Cloud Shell** en modo **PowerShell**.
- Acceso autorizado al repositorio privado de GitHub que contiene el script.
- Una región permitida por la política de la suscripción **y** compatible con Azure Databricks.

**Regiones consideradas en esta práctica:**

| Región identificada por la suscripción | Uso en el script v3 |
| --- | --- |
| `norwayeast` | Región predeterminada. |
| `switzerlandnorth` | Región alternativa configurable. |
| `spaincentral`, `polandcentral`, `belgiumcentral` | También aparecieron entre las regiones permitidas por la suscripción, pero no están habilitadas en el `ValidateSet` del script utilizado. Antes de usarlas, habría que comprobar su compatibilidad con Azure Databricks. |

> Una región permitida por la suscripción **no garantiza** por sí sola la disponibilidad del servicio ni de las cuotas de máquinas virtuales que puedan necesitar los laboratorios posteriores.

## 3. Estructura del repositorio

La estructura utilizada para ejecutar la versión v3 es:

```text
azure-labs/
├── scripts/
│   └── deploy-databricks-v3.ps1
└── README.md
```

> Si decides renombrar el script a `deploy-databricks.ps1`, cambia también su nombre en los comandos de este README.

## 4. Despliegue paso a paso desde GitHub privado

### Paso 1 — Abrir Azure Cloud Shell

1. Accede a [Azure Portal](https://portal.azure.com).
2. Abre **Cloud Shell** en la barra superior (o entra en [shell.azure.com](https://shell.azure.com)).
3. Selecciona **PowerShell** como entorno de terminal.
4. Si Cloud Shell solicita configuración inicial, sigue las opciones disponibles para tu suscripción.

### Paso 2 — Obtener el repositorio privado

Si el repositorio todavía no está clonado:

```powershell
git clone https://github.com/TU_USUARIO/azure-labs.git
cd azure-labs
```

Sustituye `TU_USUARIO` y `azure-labs` por el propietario y nombre reales. Para un repositorio privado, autentícate mediante un método autorizado por GitHub (por ejemplo, un **fine-grained personal access token** con permiso **Contents: Read** cuando se soliciten credenciales). **No escribas el token dentro del comando, del archivo `.ps1` ni de un commit.**

Si ya lo tienes clonado y quieres recuperar cambios realizados en GitHub:

```powershell
cd ~/azure-labs
git pull origin main
```

> `main` presupone que esta es tu rama principal y que no hay cambios locales incompatibles.

### Paso 3 — Comprobar la sesión de Azure

```powershell
az account show --query "{Subscription:name,Id:id}" --output table
```

La suscripción utilizada en esta práctica fue **Azure for Students**. Comprueba que el resultado corresponde a la suscripción en la que quieres desplegar los recursos.

### Paso 4 — Ejecutar el script

Desde la raíz del repositorio:

```powershell
./scripts/deploy-databricks-v3.ps1
```

Con sus parámetros predeterminados, el script intenta utilizar:

| Parámetro del script | Valor predeterminado |
| --- | --- |
| `-ResourceGroup` | `rg-dp750` |
| `-WorkspaceName` | `adb-dp750` |
| `-Location` | `norwayeast` |
| `-Sku` | `premium` |

La creación del workspace puede durar varios minutos y el terminal puede permanecer sin mostrar nuevos mensajes después de:

```text
El workspace 'adb-dp750' no existe. Creandolo en 'norwayeast' con SKU 'premium'...
```

Esto **no significa por sí solo que haya un fallo**. No ejecutes otra instancia del script mientras el despliegue siga activo. Puedes comprobar el progreso desde **Azure Portal → Resource groups → rg-dp750 → Deployments**.

## 5. Cómo cambiar la región

### Opción A — Cambiarla solo para una ejecución (recomendada)

**No es necesario editar el script**. Pasa la nueva región con el parámetro `-Location`:

```powershell
./scripts/deploy-databricks-v3.ps1 -Location switzerlandnorth
```

También puedes configurar otro grupo y workspace para no reutilizar el existente:

```powershell
./scripts/deploy-databricks-v3.ps1 `
  -ResourceGroup rg-dp750-test `
  -WorkspaceName adb-dp750-test `
  -Location switzerlandnorth `
  -Sku premium
```

### Opción B — Cambiar la región predeterminada permanentemente

Edita el archivo **`scripts/deploy-databricks-v3.ps1`** en tu repositorio. Al principio del script encontrarás:

```powershell
[ValidateSet('norwayeast', 'switzerlandnorth')]
[string]$Location = 'norwayeast',
```

Cambia el valor predeterminado a:

```powershell
[ValidateSet('norwayeast', 'switzerlandnorth')]
[string]$Location = 'switzerlandnorth',
```

Guarda el cambio, haz **Commit** y actualiza la copia en Cloud Shell:

```powershell
git pull origin main
./scripts/deploy-databricks-v3.ps1
```

**Si necesitas añadir otra región:** además de comprobar que Azure Databricks la ofrece y tu suscripción la permite, tendrás que agregar su identificador a `ValidateSet(...)`; de lo contrario, PowerShell rechazará el valor del parámetro.

**Importante sobre los recursos existentes:** cambiar `-Location` **no mueve** un workspace ya creado. Si `adb-dp750` existe, el script lo reutilizará y advertirá si está en otra región. Para desplegar en otra ubicación, utiliza un **nombre nuevo de workspace** (o gestiona por separado la eliminación y recreación del antiguo, si corresponde). El resource group también puede estar ubicado en una región distinta de la del workspace.

## 6. Verificar el resultado (Task 3 del Lab 0)

La comprobación final del laboratorio original consiste en abrir el workspace:

1. En [Azure Portal](https://portal.azure.com), busca **Azure Databricks**.
2. Selecciona el workspace **`adb-dp750`**.
3. En **Overview**, verifica los datos principales y que el estado de aprovisionamiento sea **`Succeeded`**.
4. Comprueba el **Pricing Tier: Premium**.
5. Selecciona **Launch workspace**.
6. Verifica que se abre la página de inicio de Azure Databricks.

**Comprobación adicional desde Cloud Shell:**

```powershell
az resource show `
  --resource-group rg-dp750 `
  --name adb-dp750 `
  --resource-type Microsoft.Databricks/workspaces `
  --query "properties.provisioningState" `
  --output tsv
```

Resultado esperado:

```text
Succeeded
```

Para inspeccionar todos los datos del workspace:

```powershell
az databricks workspace show `
  --resource-group rg-dp750 `
  --name adb-dp750 `
  --output json
```

**Checklist de cierre:**

- [ ] Existe `rg-dp750`.
- [ ] Existe `adb-dp750` en la suscripción correcta.
- [ ] La región del workspace es la prevista.
- [ ] El **Pricing Tier** es `Premium`.
- [ ] El estado de aprovisionamiento es `Succeeded`.
- [ ] **Launch workspace** abre correctamente Azure Databricks.

> El Lab 0 **no exige crear un cluster ni ejecutar notebooks**. Estas tareas corresponden a otros laboratorios y pueden verse afectadas por cuotas adicionales de Azure.

## 7. Errores encontrados y solución

| Mensaje | Causa identificada | Solución aplicada o recomendada |
| --- | --- | --- |
| `RequestDisallowedByAzure` | El script oficial eligió `westeurope`, bloqueada por una política de la suscripción. | Seleccionar explícitamente una región permitida (`norwayeast` o `switzerlandnorth`, en esta práctica). |
| Avisos sobre instalación dinámica de extensiones | Azure CLI intentaba administrar la extensión `databricks`. | La v3 comprueba e instala explícitamente la extensión cuando falta. |
| «El workspace ya existe» seguido de `ResourceNotFound` | La comprobación de existencia de una versión anterior trató incorrectamente una respuesta vacía como si el recurso existiera. | La v3 comprueba los recursos mediante JSON antes de crear o reutilizar el workspace. |
| El terminal no muestra mensajes durante la creación | El comando de creación puede ejecutarse varios minutos sin salida adicional. | Consultar **Deployments** en Azure Portal; comprobar si finaliza con éxito o error. |
| `QuotaExceeded` en un laboratorio posterior | Cuota insuficiente de una familia de máquinas virtuales en la región elegida. | Revisar **Quotas** y los requisitos de compute del laboratorio; no se resuelve solo creando el workspace. |

## 8. Limpieza de recursos y costes

Cuando termines el curso, revisa los recursos que siguen existiendo y sus posibles costes en Azure Portal. Si creaste `rg-dp750` exclusivamente para estas prácticas y ya no lo necesitas, puedes eliminarlo desde el portal.

> **Atención:** eliminar un resource group elimina **todos los recursos incluidos en él**. Comprueba su contenido antes de confirmar una eliminación.

## 9. Referencias

- [Lab 00 — script original de Microsoft Learn](https://github.com/MicrosoftLearning/DP-750T00-Implement-Data-Engineering-Solutions-using-Azure-Databricks/blob/main/Instructions/Labs/00-setup.sh)
- [Azure Portal](https://portal.azure.com)
- [Azure CLI — `az databricks workspace`](https://learn.microsoft.com/cli/azure/databricks/workspace)
- [Azure Databricks — regiones de Azure compatibles](https://learn.microsoft.com/azure/databricks/resources/supported-regions)

---

**Resultado esperado:** un **Azure Databricks Premium workspace** (`adb-dp750`) aprovisionado y accesible, con un despliegue **reutilizable y configurable** desde un repositorio privado de GitHub.
