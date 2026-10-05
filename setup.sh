#!/bin/bash
set -e

# --- Directorios ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
VALIDATE_SCRIPT="${SCRIPT_DIR}/utils/validate.sh"

# --- Importar utilidades ---
source "${SCRIPT_DIR}/utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este script debe ejecutarse como root. Usa 'sudo ./setup.sh'."
    exit 1
fi

# --- Validar repositorios del sistema ---
msg "Validando repositorios..."
chmod +x "$VALIDATE_SCRIPT"
"$VALIDATE_SCRIPT"

# --- Selección de Entorno de Escritorio ---
if [ -z "$DESKTOP_ENV" ]; then
    echo "============================================="
    echo "Selecciona el Entorno de Escritorio a instalar:"
    echo "1) GNOME"
    echo "2) KDE Plasma"
    echo "============================================="
    read -rp "Ingresa tu opción [1-2]: " env_choice
    case "$env_choice" in
        2) DESKTOP_ENV="kde" ;;
        *) DESKTOP_ENV="gnome" ;;
    esac
fi

msg "🚀 Iniciando configuración del sistema (Entorno seleccionado: ${DESKTOP_ENV^^})..."

# --- Asegurar permisos de ejecución en los módulos ---
msg "Asegurando permisos de ejecución para los módulos..."
if [ -d "$MODULES_DIR" ]; then
    chmod +x "${MODULES_DIR}"/*.sh
else
    error "No se encontró el directorio de módulos en: $MODULES_DIR"
    exit 1
fi

# --- Módulos Base (Comunes para todos los entornos) ---
BASE_MODULES=(
    "00-tools.sh"
    "01-kernel.sh"
#    "02-drivers.sh"
    "03-plymouth.sh"
    "04-auth.sh"
    "05-zsh.sh"
    "06-networkmanager.sh"
    "07-audio.sh"
    "08-zram.sh"
    "09-gaming.sh"
#    "10-appimage.sh"
)

# --- Módulos según el Entorno Seleccionado ---
if [ "$DESKTOP_ENV" = "kde" ]; then
    ENV_MODULES=("11-kde.sh")
else
    ENV_MODULES=("11-gnome.sh" "12-gnome-extras.sh")
fi

FINAL_MODULES=("13-finalize.sh")

# Unir listas de módulos
MODULES=("${BASE_MODULES[@]}" "${ENV_MODULES[@]}" "${FINAL_MODULES[@]}")

# --- Ejecutar módulos ---
for module in "${MODULES[@]}"; do
    module_path="${MODULES_DIR}/${module}"
    if [ -f "$module_path" ]; then
        msg "Ejecutando: ${module}..."
        if ! "$module_path"; then
            error "El módulo ${module} falló. Deteniendo setup."
            exit 1
        fi
    else
        error "Módulo no encontrado: ${module_path}"
        exit 1
    fi
done

success "🎉 ¡Proceso de setup completado con éxito para ${DESKTOP_ENV^^}!"
