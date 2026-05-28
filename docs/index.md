# Wazuh Security as a Service

Bienvenido a la documentacion operativa del lab. La idea es que cualquier persona del equipo pueda abrir el repo y responder rapido:

- que tenemos desplegado
- como entrar a cada servicio
- que cambio recientemente
- como correr una demo sin romper nada
- donde documentar lo nuevo

## Por donde empezar

| Necesito | Ir a |
|---|---|
| Levantar o validar el lab | [Puesta en marcha](getting-started.md) |
| Entrar a Wazuh, n8n, RHEL UI o Windows | [Accesos y credenciales](accesos-y-credenciales.md) |
| Saber que cambio recientemente | [Cambios recientes](cambios-recientes.md) |
| Operar el lab durante una demo | [Operacion diaria](operacion-diaria.md) |
| Documentar un cambio nuevo | [Como usar esta documentacion](como-usar-la-documentacion.md) |

## Estado actual

El lab corre principalmente en Google Cloud Platform y mantiene fallback local con Docker cuando conviene ahorrar costo o probar algo rapido.

Los bloques principales son:

- Wazuh Manager, Indexer y Dashboard.
- Endpoints Linux, Windows, Kali, Docker host y RHEL UI.
- n8n para automatizacion SOC.
- Jira para tickets.
- ChatGPT para analisis de alertas.
- Telegram para avisos P1/P2.
- Dashboards, mapas y escenarios controlados para demo.

## Regla del equipo

Si cambias algo que otra persona podria necesitar para operar el lab, deja una pista en la documentacion. No tiene que ser perfecto; tiene que ser encontrable.

El README sigue siendo la portada del repo. Este sitio es el manual vivo.
