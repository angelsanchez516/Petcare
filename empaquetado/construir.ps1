# Genera entrega\PetCare.exe. Se ejecuta en este computador, que tiene Node y PostgreSQL 16.
# Solo LEE la base petcare (pg_dump) y compila en una carpeta temporal, asi que no toca
# web\.next, tu servidor ni los datos reales.
#
#   powershell -ExecutionPolicy Bypass -File empaquetado\construir.ps1

$ErrorActionPreference = "Stop"

$aqui    = $PSScriptRoot
$raiz    = Split-Path $aqui -Parent
$web     = Join-Path $raiz "web"
$salida  = Join-Path $raiz "entrega"
$temp    = Join-Path $env:TEMP "petcare-empaquetado"
$fuente  = Join-Path $temp "fuente"
$paquete = Join-Path $temp "PetCare"
$pg      = "C:\Program Files\PostgreSQL\16"
$sistema = "C:\Windows\System32"
$csc     = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

function Paso($texto) { Write-Output "--- $texto" }
function Revisar($que) { if ($LASTEXITCODE -ne 0) { throw "Fallo: $que (codigo $LASTEXITCODE)" } }

function Compilar($exe, $extra) {
    $opciones = @("/nologo", "/target:winexe", "/platform:x64", "/optimize+", "/codepage:65001",
        "/win32icon:$aqui\petcare.ico", "/out:$exe",
        "/r:System.Windows.Forms.dll", "/r:System.Drawing.dll", "/r:System.Core.dll", "/r:Microsoft.CSharp.dll",
        "/r:System.IO.Compression.dll", "/r:System.IO.Compression.FileSystem.dll") + $extra + @("$aqui\PetCare.cs")
    & $csc $opciones
    Revisar "compilar $exe"
}

Paso "Copiando el codigo a una carpeta temporal"
if (Test-Path $paquete) { Remove-Item $paquete -Recurse -Force }
& robocopy $web $fuente /MIR /NFL /NDL /NJH /NJS /NP /XD node_modules .next uploads /XF .env.local tsconfig.tsbuildinfo | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Fallo: copiar el codigo" }

# Solo esta copia se compila como "standalone": un servidor que no necesita node_modules aparte.
$config = Join-Path $fuente "next.config.ts"
(Get-Content $config -Raw -Encoding UTF8).Replace("reactStrictMode: true,", "reactStrictMode: true,`n  output: `"standalone`",") |
    Set-Content $config -Encoding UTF8

Paso "Compilando la pagina"
Push-Location $fuente
# npm escribe avisos normales por stderr: aqui lo que cuenta es su codigo de salida.
$ErrorActionPreference = "Continue"
& npm.cmd ci --no-audit --no-fund
Revisar "npm ci"
$env:AUTH_SECRET = "solo-para-compilar"
& npm.cmd run build
Revisar "npm run build"
$ErrorActionPreference = "Stop"
Pop-Location

Paso "Armando el paquete"
$app = Join-Path $paquete "app"
New-Item -ItemType Directory -Force "$app\.next", "$paquete\postgres\bin" | Out-Null
Copy-Item "$fuente\.next\standalone\*" $app -Recurse -Force
Copy-Item "$fuente\.next\static" "$app\.next\static" -Recurse -Force
Copy-Item "$fuente\public" "$app\public" -Recurse -Force
Copy-Item (Get-Command node.exe).Source "$app\node.exe"

# PostgreSQL: solo lo necesario para arrancar la base. wx* es de otras herramientas de PostgreSQL.
foreach ($exe in "postgres", "initdb", "pg_ctl", "psql") { Copy-Item "$pg\bin\$exe.exe" "$paquete\postgres\bin" }
Get-ChildItem "$pg\bin\*.dll" | Where-Object { $_.Name -notlike "wx*" } | Copy-Item -Destination "$paquete\postgres\bin"
Copy-Item "$pg\lib" "$paquete\postgres\lib" -Recurse
Copy-Item "$pg\share" "$paquete\postgres\share" -Recurse
Remove-Item "$paquete\postgres\lib\pgxs", "$paquete\postgres\share\doc" -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem "$paquete\postgres\lib" -File | Where-Object { $_.Extension -eq ".lib" -or $_.Name -match "plperl|plpython|pltcl|system_stats" } | Remove-Item

# Sin estas tres, PostgreSQL no abre en un PC sin Visual C++ instalado.
foreach ($dll in "vcruntime140.dll", "vcruntime140_1.dll", "msvcp140.dll") { Copy-Item "$sistema\$dll" "$paquete\postgres\bin" }

Paso "Copiando los datos de demostracion (solo lectura de la base)"
$env:PGCLIENTENCODING = "UTF8"
& "$pg\bin\pg_dump.exe" -w -U postgres -h localhost --no-owner --no-privileges --encoding=UTF8 -f "$paquete\petcare.sql" petcare
Revisar "pg_dump"

$readme = Get-Content "$raiz\README.md" -Raw -Encoding UTF8
if ($readme -notmatch "La contrase.a de todos es ``([^``]+)``") { throw "No encontre la clave de demostracion en el README" }
[IO.File]::WriteAllText("$paquete\clave-demo.txt", $Matches[1])
[IO.File]::WriteAllText("$paquete\version.txt", (Get-Date -Format "yyyyMMdd-HHmmss"))

Paso "Compilando el programa instalado"
Compilar "$paquete\PetCare.exe" @()

Paso "Comprimiendo"
$zip = Join-Path $temp "PetCare.zip"
if (Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($paquete, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)

Paso "Compilando el instalador"
New-Item -ItemType Directory -Force $salida | Out-Null
Compilar "$salida\PetCare.exe" @("/resource:$zip,PetCare.zip")

$mb = [math]::Round((Get-Item "$salida\PetCare.exe").Length / 1MB)
Paso "Listo: $salida\PetCare.exe ($mb MB)"
