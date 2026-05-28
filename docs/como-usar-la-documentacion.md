# Como usar esta documentacion

Esta documentacion esta pensada para no abrumar. Cada pagina debe resolver una pregunta concreta y apuntar a otra pagina cuando haga falta mas detalle.

## Flujo recomendado

Cuando hagas un cambio:

1. Actualiza el archivo tecnico que cambiaste.
2. Agrega una nota breve en `CHANGELOG.md`.
3. Si cambia una forma de operar, actualiza un runbook en `docs/runbooks/`.
4. Si cambia una credencial, no la escribas en el repo; documenta como recuperarla.

## Donde documentar

| Tipo de cambio | Donde va |
|---|---|
| Algo nuevo o importante | `CHANGELOG.md` |
| Como entrar a una maquina o servicio | `docs/accesos-y-credenciales.md` |
| Pasos repetibles de operacion | `docs/runbooks/` |
| Escenarios de demo | `docs/` o `docs/runbooks/` |
| Variables y secretos | documentar nombres, no valores reales |

## Ver la documentacion como sitio

Desde la raiz del repo:

```powershell
python -m pip install -r requirements-docs.txt
mkdocs serve
```

Luego abre:

```text
http://127.0.0.1:8000
```

Para solo validar que compila:

```powershell
mkdocs build
```

El directorio generado `site/` no se debe commitear.
