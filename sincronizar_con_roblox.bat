@echo off
chcp 65001 >nul
title Actualizador y Sincronizador de Proyecto (ADA UNSA - FNAF 5D)

echo.
echo ==============================================================================
echo  🕹️  ACTUALIZADOR Y SINCRONIZADOR DEL PROYECTO (Git -^> Roblox)
echo  Proyecto ADA UNSA — 5D Multiverse FNAF Engine
echo ==============================================================================
echo.

echo [1/2] Descargando últimos cambios de GitHub (git pull origin main)...
git pull origin main
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] No se pudo descargar los cambios de Git.
    echo Verifica tu conexión a internet o si tienes cambios locales en conflicto.
    echo.
    pause
    exit /b 1
)

echo.
echo ==============================================================================
echo [2/2] Archivos actualizados en tu copia local:
echo ==============================================================================
git diff --name-only HEAD@{1} HEAD 2>nul
if %ERRORLEVEL% neq 0 (
    echo (Repositorio actualizado al último commit de main)
)

echo.
echo ------------------------------------------------------------------------------
echo  💡 ¿CÓMO REFLEJAR ESTOS CAMBIOS EN TU ROBLOX STUDIO?
echo ------------------------------------------------------------------------------
echo  1. Si usas un Agente IA (Antigravity / Gemini / Claude con MCP):
echo     Solo pídele en tu chat: "Sincroniza los cambios de local a Roblox Studio".
echo     El agente inyectará en vivo todos los scripts al instante vía MCP.
echo.
echo  2. Si se modificaron Modelos 3D (archivos .rbxm en assets/):
echo     En Roblox Studio arrastra el archivo .rbxm directo a la ventana del juego
echo     o usa: Modelo (Model) -^> Insertar desde archivo... (Insert from File...)
echo ------------------------------------------------------------------------------
echo.
pause
