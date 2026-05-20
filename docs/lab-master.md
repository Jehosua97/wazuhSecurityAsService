# Lab master: estado, costo y operacion

El script `scripts/lab-master.ps1` es el panel maestro del laboratorio. Sirve para:

- Ver el estado general de Wazuh en GCP.
- Contar cuantas VMs GCP del lab estan corriendo.
- Contar cuantos contenedores locales Linux/Windows estan corriendo.
- Encender o apagar Wazuh en GCP.
- Crear o destruir la infraestructura GCP con Terraform.
- Encender, apagar o destruir contenedores locales.
- Aplicar reglas/configuracion Wazuh e importar dashboards.

## Modo interactivo

Desde la raiz del repo:

```powershell
.\scripts\lab-master.ps1
```

El menu muestra el resumen y permite elegir acciones.

## Consultar estado

```powershell
.\scripts\lab-master.ps1 -Action status
```

## Ahorro recomendado

Para bajar costo sin destruir el laboratorio:

```powershell
.\scripts\lab-master.ps1 -Action cost-saver
```

Esto detiene los contenedores visibles en el engine Docker actual y apaga `wazuh-server` en GCP.

Nota: quedan costos pequenos de disco persistente e IP estatica. Esto conserva el laboratorio para prenderlo rapido.

## Ahorro maximo

Para borrar la infraestructura GCP administrada por Terraform:

```powershell
.\scripts\lab-master.ps1 -Action destroy-gcp
```

Esto elimina Wazuh, disco e IP estatica. Es el modo de menor costo, pero al recrear el manager puede cambiar la IP y tendras que re-enrolar endpoints.

Para recrear:

```powershell
.\scripts\lab-master.ps1 -Action apply-gcp
.\scripts\lab-master.ps1 -Action configure-wazuh -DashboardPassword "SecretPassword"
```

## Operacion rapida

Encender Wazuh:

```powershell
.\scripts\lab-master.ps1 -Action start-wazuh
```

Apagar Wazuh:

```powershell
.\scripts\lab-master.ps1 -Action stop-wazuh
```

Encender Wazuh y contenedores Linux:

```powershell
.\scripts\lab-master.ps1 -Action full-start
```

Encender solo endpoints Linux:

```powershell
.\scripts\lab-master.ps1 -Action start-linux
```

Apagar endpoints Linux:

```powershell
.\scripts\lab-master.ps1 -Action stop-linux
```

Windows usa otro engine de Docker Desktop. Cambia a Windows containers y ejecuta:

```powershell
.\scripts\lab-master.ps1 -Action start-windows
```

## Acciones no interactivas

Para automatizacion, `-Yes` evita confirmaciones del script y `-AutoApprove` pasa aprobacion a Terraform:

```powershell
.\scripts\lab-master.ps1 -Action apply-gcp -AutoApprove
.\scripts\lab-master.ps1 -Action destroy-gcp -Yes -AutoApprove
```

Usa `destroy-gcp` con cuidado: borra la infraestructura cloud administrada por Terraform.
