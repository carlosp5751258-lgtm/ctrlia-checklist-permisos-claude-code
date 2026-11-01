# Antes de darle permisos a Claude Code: checklist de seguridad


- [ ] **1. Sabe en qué modo arrancas.**
  - Por qué: el modo decide qué se aprueba sin preguntarte. Desde la versión 2.1.283, si tu cuenta y tu modelo lo admiten, las sesiones interactivas en la terminal y en VS Code arrancan en **auto**: un clasificador aparte revisa en segundo plano los comandos y las peticiones de red y bloquea lo que considera peligroso. Es cómodo, pero no es «sin riesgo»: el clasificador decide por ti. En modo **Manual** (`default`), Claude Code pide permiso la primera vez que usa cada herramienta, salvo un conjunto fijo de comandos de solo lectura (`ls`, `cat`, `git status`…).
  - Cómo comprobarlo: mira el indicador de modo en la parte inferior de la terminal y cámbialo con `Shift+Tab`. Para fijar otro modo inicial, pon `permissions.defaultMode` en `~/.claude/settings.json`, o arranca con `claude --permission-mode default`. En un proyecto que no conoces, empieza en `plan` o en Manual.
  - El orden: el modo inicial sale de la opción `--permission-mode` (o `--dangerously-skip-permissions`), luego de `defaultMode` en un archivo de ajustes y por último del valor de fábrica. La extensión de VS Code tiene su propio ajuste, `claudeCode.initialPermissionMode`, y nunca lee el modo de los ajustes del proyecto.
- [ ] **2. Conoce los cuatro archivos y quién gana.**
  - Por qué: una misma regla puede estar en cuatro sitios y sumarse. De mayor a menor prioridad: ajustes **administrados** de tu organización (no se pueden anular), opciones de la **línea de comandos**, **local** (`.claude/settings.local.json`, solo tú en este proyecto, fuera de git), **proyecto** (`.claude/settings.json`, todo el equipo) y **usuario** (`~/.claude/settings.json`, tú en todos los proyectos). Las listas allow, ask y deny no se pisan entre archivos: se juntan.
  - La regla de oro: las reglas se evalúan en el orden **deny → ask → allow** y gana la primera que coincide, aunque otra sea más específica. Un deny de cualquier ámbito bloquea aunque otro ámbito lo permita: un deny en tu archivo de usuario gana a un allow del proyecto, y al revés. Un allow no puede abrir una excepción dentro de un deny: con `deny: Bash(aws *)`, el `allow: Bash(aws s3 ls)` no sirve. Y un ask pregunta aunque haya un allow más concreto.
  - Cómo comprobarlo: en la sesión, `/permissions` muestra cada regla con el archivo de donde viene, y `/status` qué archivos de ajustes se cargaron. Pon los deny que quieres en todas partes (tus `~/.ssh`, `~/.aws`) en tu archivo de usuario: así ningún repo puede quitártelos.
- [ ] **3. Antes de confiar en una carpeta, lee su .claude/.**
  - Por qué: al abrir `claude` en una carpeta nueva aparece el diálogo de confianza. Hasta que lo aceptas, las reglas **allow** y los **additionalDirectories** del `.claude/settings.json` del proyecto no se aplican (dan permisos); las deny y ask sí, porque solo restringen. El diálogo lista lo que la carpeta te concedería. Acéptalo solo después de leerlo.
  - Lo que casi nadie sabe: según la tabla oficial «What runs before you trust a folder», con `claude -p` o el SDK, en una carpeta en la que nunca confiaste, Claude Code **sí usa** los hooks de los ajustes del proyecto, el bloque `env`, helpers como `apiKeyHelper` y el `allowed-tools` de las skills del proyecto, y **conecta sin preguntar** los servidores de `.mcp.json`. Lo comprobamos en este PC: un hook SessionStart de un repo de prueba creó un archivo con `claude -p` antes incluso de que la CLI dijera «Not logged in».
  - Cómo comprobarlo: antes de lanzar nada en un repo ajeno, mira `.claude/settings.json`, `.claude/settings.local.json`, `.claude/skills/`, `.claude/agents/` y `.mcp.json` (el script `revisar-repo-ajeno.sh` del repositorio lo hace sin ejecutar nada). Si vas a usar `claude -p` ahí, añade `--setting-sources user` (no lee los ajustes ni el `.mcp.json` del proyecto), `--bare` (no lee hooks, skills, comandos, subagentes, plugins ni servidores del proyecto; el `env` del proyecto sí se aplica) o `--settings '{"disableAllHooks": true}'`. Los tres evitaron el hook en nuestra prueba. Ponerlo solo en tus ajustes de usuario no basta: el proyecto tiene más prioridad.

```bash
# Prueba real: un repo ajeno ejecuta su hook con claude -p (1-nov-2026, Claude Code 2.1.316)
# Repo de prueba con un hook SessionStart en .claude/settings.json que hace touch de un archivo
$ claude -p "di hola" < /dev/null
Ignoring 2 permissions.allow entries from .claude/settings.json: this workspace has not been trusted. ...
Not logged in · Please run /login
$ ls ../HOOK-EJECUTADO
../HOOK-EJECUTADO          # el hook se ejecutó: sin confianza y sin sesión iniciada

# Las tres formas de evitarlo (el hook NO se ejecutó en ninguna):
$ claude -p "di hola" --setting-sources user
$ claude -p "di hola" --bare
$ claude -p "di hola" --settings '{"disableAllHooks": true}'
```

- [ ] **4. Si tu allow no funciona, mira la confianza.**
  - Por qué: es la causa más común de «Claude me sigue preguntando aunque lo permití en el proyecto». La confianza se guarda por raíz del repositorio git (cubre todo el repo salvo repos anidados, como submódulos, que piden la suya). Si arrancas Claude en tu carpeta personal (home), la confianza dura solo esa sesión y no se guarda. Un `claude -p` nunca muestra el diálogo.
  - Cómo comprobarlo: ejecuta `claude -p "hola"` o `claude doctor` en la carpeta. Si ves en stderr `Ignoring 2 permissions.allow entries from .claude/settings.json: this workspace has not been trusted. Run Claude Code interactively here once and accept the trust dialog, or set projects["…"].hasTrustDialogAccepted: true in …/.claude.json.`, tus reglas allow del proyecto están en pausa.
  - Solución: abre `claude` en modo interactivo una vez y acepta. La alternativa de editar `hasTrustDialogAccepted` a mano en `~/.claude.json` existe y la documentación la menciona, pero úsala solo en carpetas que ya revisaste.
  - Otro detalle: `.claude/settings.local.json` normalmente se aplica sin confianza porque es tuyo; pero si está versionado en git o `.claude` es un enlace simbólico, Claude Code lo trata como del repositorio y retiene sus reglas.
- [ ] **5. No pongas auto ni bypass en los ajustes del proyecto.**
  - Por qué: para que un repo no pueda decidir por ti cuánto se aprueba solo, Claude Code ignora `defaultMode: "auto"` y `"bypassPermissions"` cuando están en `.claude/settings.json` o `.claude/settings.local.json`. Con auto se usa el valor de fábrica (no el `defaultMode` de tu archivo de usuario); con bypass la sesión arranca en Manual. Los otros modos (`default`, `acceptEdits`, `plan`, `dontAsk`) sí se aplican desde el proyecto en la terminal. Las sesiones en la nube tampoco hacen caso de bypass ni de dontAsk desde los archivos.
  - Cómo comprobarlo: si pusiste auto en el proyecto y la sesión arranca en Manual sin error, es esto. Mueve el ajuste a `~/.claude/settings.json` o usa `--permission-mode auto`.
  - Y el modo bypass: `bypassPermissions` (igual que `--dangerously-skip-permissions`) se salta las preguntas, incluidas las escrituras en rutas protegidas como `.git` y `.claude`. La documentación lo limita a contenedores o máquinas virtuales donde no pueda hacer daño, y en Linux recomienda no ejecutarlo como root. Ni siquiera en ese modo se aprueban solas las reglas ask, los borrados de rutas críticas con rm ni `AskUserQuestion`.
- [ ] **6. Cierra la puerta del bypass (y del auto, si quieres).**
  - Por qué: la forma más habitual de acabar en bypass es por costumbre o por copiar un alias. Puedes impedirlo tú mismo: `permissions.disableBypassPermissionsMode: "disable"` funciona desde cualquier ámbito, no solo en los ajustes administrados, y un usuario puede ponerlo en su propio archivo para no poder entrar en bypass. Lo mismo con `permissions.disableAutoMode: "disable"` si prefieres no delegar en el clasificador; con él, `auto` desaparece del ciclo de `Shift+Tab` y una sesión lanzada con `--permission-mode auto` arranca en Manual.
  - Cómo comprobarlo: añade la clave a `~/.claude/settings.json`, valida el JSON con `python3 -m json.tool ~/.claude/settings.json` y arranca `claude --dangerously-skip-permissions`: según la documentación ya no debe entrar en bypass (nosotros no pudimos verlo sin una sesión iniciada). En una organización, ponlo en los ajustes administrados, donde nadie lo puede quitar.

```json
{
  "permissions": {
    "disableBypassPermissionsMode": "disable"
  }
}
```

- [ ] **7. Bloquear curl no es cortar la red.**
  - Por qué: la documentación oficial lo dice claro: `curl` y `wget` no se aprueban automáticamente por defecto (en Manual preguntan como cualquier comando que no es de solo lectura), y puedes ponerlos en `permissions.deny`. Pero una regla deny compara el comando **tal como está escrito**: `deny: Bash(curl *)` frena `curl https://…` y no frena `/usr/bin/curl https://…`, `sh -c 'curl …'` ni un script de Python que abra una conexión. Y permitir solo `WebFetch(domain:github.com)` tampoco basta: si Bash está permitido, Claude puede usar cualquier otra herramienta de red.
  - La barrera real es el sandbox: con `/sandbox` (o `sandbox.enabled: true`), los comandos de Bash y sus procesos hijos corren aislados; en Linux, en otro espacio de red sin salida, y solo llegan a los dominios de `sandbox.network.allowedDomains` a través de un proxy. En Linux y WSL2 necesita `bubblewrap` y `socat` (`sudo apt-get install bubblewrap socat`); en Ubuntu 24.04 o posterior, AppArmor puede impedir que bubblewrap arranque, y `/sandbox` te dice cómo arreglarlo.
  - Cómo comprobarlo: abre `/sandbox`; si solo ves la pestaña Dependencies, falta algo. Ojo: si el sandbox no puede arrancar, por defecto los comandos corren sin él; pon `sandbox.failIfUnavailable: true` si quieres que Claude Code se niegue a arrancar.
- [ ] **8. Sabe qué queda fuera del sandbox.**
  - Por qué: el sandbox envuelve los comandos de shell, no todo lo demás. Según la [documentación del sandbox](https://code.claude.com/docs/es/sandboxing), quedan fuera: las herramientas Read, Edit, Write, WebFetch y WebSearch (siguen tus reglas de permisos: un `denyRead` del sandbox no frena Read, y `allowedDomains` no limita WebFetch), los **hooks**, los **servidores MCP locales**, los monitores de plugins, la statusline y `apiKeyHelper` (corren con todos tus permisos), lo que escribes tú con `!`, los comandos de `excludedCommands` y los reintentos sin sandbox que Claude pida tras un fallo.
  - Además: por defecto el sandbox **puede leer casi toda la máquina**, incluidos `~/.ssh` y `~/.aws/credentials`, y hereda tus variables de entorno, secretos incluidos.
  - Cómo comprobarlo y cerrarlo: añade `sandbox.filesystem.denyRead` para tus credenciales y `permissions.deny` con `Read(~/.ssh/**)` y `Read(~/.aws/**)` para las herramientas de archivos. Para que Claude no pueda pedir ejecutar fuera, `sandbox.allowUnsandboxedCommands: false` (el «Strict sandbox mode» de la pestaña Overrides). Para meter todo detrás de una sola barrera, ejecuta Claude Code dentro de un contenedor, una máquina virtual o un dev container.

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false,
    "network": {
      "allowedDomains": ["github.com", "*.github.com", "registry.npmjs.org"]
    },
    "filesystem": {
      "denyRead": ["~/.ssh", "~/.aws"]
    }
  }
}
```

- [ ] **9. Limita dónde puede escribir.**
  - Por qué: en Manual, Claude Code pregunta antes de que sus herramientas de archivos lean o escriban fuera de la carpeta donde lo abriste, pero un comando de Bash que apruebes puede escribir en cualquier sitio al que llegue tu usuario. Desde la versión 2.1.314 existe `permissions.blockWritesOutsideWorkingDirectories`: Write, Edit y NotebookEdit se niegan a escribir fuera de las carpetas de trabajo **en todos los modos** (lo contamos en [esta novedad](https://ctrlia.dev/novedades/2026-10-30-bloquear-escrituras-fuera.html)). También existe `permissions.blockReadsOutsideWorkingDirectories` (desde la 2.1.257) para las lecturas, que hace preguntar incluso en auto y bypass.
  - Cómo comprobarlo: añádelo a `~/.claude/settings.json` y pide a Claude que edite un archivo de otra carpeta: según la documentación debe negarse. Si necesitas que lea otro repo, añádelo con `/add-dir` o `--add-dir` en vez de abrir la mano. Recuerda que las reglas allow no aprueban escrituras en rutas protegidas (`.git`, `.claude`…): en Manual y acceptEdits siempre preguntan.
  - Para Bash: la barrera es otra vez el sandbox, que por defecto solo deja escribir en la carpeta de trabajo, un temporal y las carpetas que añadas.
- [ ] **10. Revisa lo que aprobaste y no confíes en CLAUDE.md para la seguridad.**
  - Por qué: cada «Sí, y no volver a preguntar» se guarda como regla allow en `.claude/settings.local.json`. Con el tiempo acumulas permisos amplios sin darte cuenta, y algunos equivalen a ejecutar cualquier cosa: `Bash(python3 *)`, `Bash(node *)`, `Bash(bash *)`, `Bash(npx *)` o `Bash(git *)` (este último incluye `git -c core.fsmonitor=…`).
  - Cómo comprobarlo: una vez al mes abre `/permissions`, revisa la pestaña de reglas y la de bloqueos recientes del modo auto, y borra lo que sobre. Cambia los comodines por comandos exactos (`Bash(python3 -m pytest *)` en lugar de `Bash(python3 *)`).
  - Y recuerda quién manda: las reglas las aplica Claude Code, no el modelo. Lo que escribes en CLAUDE.md o en el prompt orienta lo que Claude intenta, pero no cambia lo que se permite. Si algo tiene que cumplirse siempre, va en una regla deny, en un [hook PreToolUse](https://ctrlia.dev/recetas/hooks-seguridad.html) (un hook que sale con código 2 bloquea incluso con un allow; y un allow del hook no anula un deny) o en ajustes administrados. Ojo con los **mods** que instales: sin ajustes administrados ni sesión de Team o Enterprise, un mod puede aprobar una llamada que una regla deny rechaza.

Tus candados personales, en un solo archivo que vale en todos tus proyectos (`~/.claude/settings.json`):

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "blockWritesOutsideWorkingDirectories": true,
    "deny": [
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)",
      "Read(~/.config/gh/**)"
    ]
  }
}
```

Y la revisión de un repo ajeno antes de abrir Claude en él:

```bash
# ¿Qué configuración de Claude trae?
ls -la .claude/ .mcp.json CLAUDE.md AGENTS.md 2>/dev/null
# Hooks, env y helpers que se ejecutarían
python3 -m json.tool .claude/settings.json 2>/dev/null | grep -nE '"(hooks|env|apiKeyHelper|allow|additionalDirectories|enableAllProjectMcpServers)"'
# Skills con allowed-tools (no dependen de la confianza)
grep -rn 'allowed-tools' .claude/skills 2>/dev/null
# Servidores MCP que pediría conectar
claude mcp list   # los de .mcp.json salen «⏸ Pending approval» hasta que los apruebes
```

El repositorio trae esta revisión como `revisar-repo-ajeno.sh` (solo lee archivos: en lugar de `claude mcp list` muestra el `.mcp.json`) y los dos JSON de ejemplo. Si empiezas un proyecto desde cero, la [plantilla de proyecto](https://ctrlia.dev/recetas/plantilla-claude-code.html) ya trae estos permisos puestos.

---
Versión completa, con errores típicos y preguntas frecuentes: https://ctrlia.dev/recetas/checklist-permisos-claude-code.html · Probado con Claude Code 2.1.316 · MIT
