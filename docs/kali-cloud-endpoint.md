# Kali cloud endpoint

Este endpoint crea una VM `kali-attacker` en GCP, la enrola como agente Wazuh y ejecuta un contenedor oficial `kalilinux/kali-rolling` para pruebas controladas dentro de la VPC del laboratorio.

La VM host usa Ubuntu para mantener compatibilidad estable con GCP y el agente Wazuh. Kali corre dentro del contenedor `kali-rolling` con `--network host`, de modo que los escaneos salen desde la IP privada de la VM `kali-attacker`.

## Que monitorea Wazuh

- Logs controlados: `/var/log/kali-lab.log`
- Evidencia de pruebas: `/opt/kali-lab/evidence`
- Alcance de la demo: `/opt/kali-lab/config/scope.txt`
- Agente esperado en Wazuh: `kali-attacker`

## Reglas

- `100210`: evento base del endpoint Kali.
- `100211`: contenedor Kali listo.
- `100212`: escaneo Nmap controlado, MITRE `T1595`.
- `100213`: prueba HTTP controlada.
- `100214`: evidencia escrita en disco.
- `100215`: actividad repetida de reconocimiento desde Kali.

## Como entrar

```powershell
gcloud compute ssh kali-attacker --project=wazuh-iac-on-gcp --zone=us-central1-a
```

Para abrir shell dentro del contenedor Kali:

```powershell
gcloud compute ssh kali-attacker --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/kali-lab-shell"
```

## Como generar eventos

Ejecuta la prueba controlada por defecto. El target default es `linux-ui-workstation` por IP privada.

```powershell
gcloud compute ssh kali-attacker --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/kali-demo-generate-events.sh"
```

Para indicar target manual:

```powershell
gcloud compute ssh kali-attacker --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/kali-demo-generate-events.sh 10.0.1.25 http://10.0.1.22"
```

## Como verlo en Wazuh

```text
agent.name: "kali-attacker" and rule.groups: kali_endpoint
```

Escaneos:

```text
agent.name: "kali-attacker" and rule.id: 100212
```

Correlacion de port scan en el endpoint Linux UI:

```text
rule.id: 100030 or rule.mitre.id: T1595
```

Dashboard:

```text
SOC Operativo - PYME Mexico
```
