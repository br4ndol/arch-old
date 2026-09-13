#!/bin/bash
set -e

# =====================================================================
# Módulo: 09-gaming.sh
# Descripción: Instala utilidades de rendimiento CPU, herramientas Asus,
#              GameMode, MangoHud, Flatpaks (ProtonPlus, Cartridges) y Steam.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./09-gaming.sh'."
    exit 1
fi

# --- Detectar Usuario Objetivo ---
TARGET_USER="${SUDO_USER}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)
fi

if [ -z "$TARGET_USER" ]; then
    error "No se pudo determinar el usuario normal del sistema."
    exit 1
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
CONFIG_SRC="${SCRIPT_DIR}/../configs/gamemode.ini"

# --- Lista de Paquetes Pacman ---
PACKAGES=(
    # CPU & Energía
    "power-profiles-daemon" "upower" "cpupower"
    # ASUS ROG Tools
    "asusctl" "rog-control-center"
    # Game Utils
    "gamemode" "lib32-gamemode" "mangohud" "lib32-mangohud" "goverlay"
    "vkbasalt" "lib32-vkbasalt" "cabextract" "ttf-liberation" "umu-launcher"
    "protontricks" "lib32-gtk3" "lib32-ocl-icd" "winetricks"
    # Steam & Gamescope
    "steam" "steam-devices" "gamescope" "lib32-gamescope" "noto-fonts"
)

# --- Lista de Flatpaks ---
FLATPAKS=(
    "com.vysp3r.ProtonPlus"
    "page.kramo.Cartridges"
)

# --- 1. Instalación de Paquetes ---
msg "Verificando e instalando herramientas de rendimiento y juegos..."
MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    instalar_paquete "${MISSING_PKGS[@]}"
else
    msg "Todos los paquetes pacman de juegos y rendimiento ya están instalados."
fi

# --- 2. Habilitar Servicios de Sistema ---
msg "Asegurando servicio power-profiles-daemon..."
if ! systemctl is-enabled power-profiles-daemon.service &>/dev/null; then
    systemctl enable --now power-profiles-daemon.service
    success "power-profiles-daemon habilitado e iniciado."
else
    msg "El servicio power-profiles-daemon ya está activo."
fi

# --- 3. Agregar usuario al grupo Gamemode ---
msg "Verificando grupo 'gamemode' para el usuario $TARGET_USER..."
if getent group gamemode &>/dev/null; then
    if ! id -nG "$TARGET_USER" | grep -qw "gamemode"; then
        usermod -aG gamemode "$TARGET_USER"
        success "Usuario $TARGET_USER añadido al grupo gamemode."
    else
        msg "El usuario $TARGET_USER ya pertenece al grupo gamemode."
    fi
fi

# --- 4. Configurar GameMode (Scripts y gamemode.ini) ---
msg "Configurando scripts y archivo de configuración para GameMode..."
GAMEMODE_SCRIPTS_DIR="$TARGET_HOME/.config/gamemode"
GAMEMODE_INI_FILE="$TARGET_HOME/.config/gamemode.ini"
GAMEMODE_SRC_DIR="${SCRIPT_DIR}/../configs/gamemode"

# Crear directorio para almacenar los scripts auxiliaries
mkdir -p "$GAMEMODE_SCRIPTS_DIR"

# Copiar scripts de inicio y fin
if [ -f "$GAMEMODE_SRC_DIR/gamemode-start.sh" ] && [ -f "$GAMEMODE_SRC_DIR/gamemode-end.sh" ]; then
    cp -f "$GAMEMODE_SRC_DIR/gamemode-start.sh" "$GAMEMODE_SCRIPTS_DIR/gamemode-start.sh"
    cp -f "$GAMEMODE_SRC_DIR/gamemode-end.sh" "$GAMEMODE_SCRIPTS_DIR/gamemode-end.sh"
    
    # Asignar permisos de ejecución a los scripts
    chmod +x "$GAMEMODE_SCRIPTS_DIR/gamemode-start.sh" "$GAMEMODE_SCRIPTS_DIR/gamemode-end.sh"
    success "Scripts gamemode-start.sh y gamemode-end.sh desplegados con permisos de ejecución."
else
    error "No se encontraron los scripts de GameMode en $GAMEMODE_SRC_DIR"
    exit 1
fi

# Generar ~/.config/gamemode.ini apuntando a la ubicación de los scripts
cat > "$GAMEMODE_INI_FILE" <<EOF
[custom]
start=$GAMEMODE_SCRIPTS_DIR/gamemode-start.sh
end=$GAMEMODE_SCRIPTS_DIR/gamemode-end.sh
EOF

# Asignar permisos y propietario correcto
chmod 644 "$GAMEMODE_INI_FILE"
chown -R "$TARGET_USER:$TARGET_USER" "$GAMEMODE_SCRIPTS_DIR" "$GAMEMODE_INI_FILE"
success "Archivo gamemode.ini configurado correctamente en $GAMEMODE_INI_FILE."

# --- 5. Instalación de Flatpaks ---
msg "Verificando e instalando Flatpaks para juegos..."
instalar_flatpak "${FLATPAKS[@]}"

success "🎉 ¡Módulo de Juegos y Rendimiento completado con éxito!"