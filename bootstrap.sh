#!/bin/bash
set -e

# =====================================================================
# Script de Bootstrap para Arch Linux + CachyOS v3
# Ejecutar en el entorno Live de la ISO de Arch Linux.
# =====================================================================

# --- Colores para mensajes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

msg() { echo -e "${YELLOW}[BOOTSTRAP]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# --- Preguntas interactivas al usuario ---
msg "============================================="
msg "Configuración inicial del sistema"
msg "============================================="

# Preguntar por las particiones
read -rp "Partición para /efi (Ingrese el nombre como vda1 o nvme0n1p1): " PART_EFI
read -rp "Partición para / (raíz, ej: nvme0n1p2): " PART_ROOT

# Preguntar por la contraseña (para root y usuario)
read -rsp "Contraseña para root y usuario (no se mostrará): " PASSWORD
echo  # Salto de línea después de la contraseña

# Preguntar por el usuario y hostname (opcional, con valores por defecto)
read -rp "Nombre de usuario [br4ndol]: " TARGET_USER
TARGET_USER="${TARGET_USER:-br4ndol}"  # Valor por defecto: br4ndol

read -rp "Hostname [arx-ArchLinux]: " HOST_NAME
HOST_NAME="${HOST_NAME:-arx-ArchLinux}"  # Valor por defecto: arx-ArchLinux

# Zona horaria (opcional, con valor por defecto)
read -rp "Zona horaria [America/Santo_Domingo]: " TIME_ZONE
TIME_ZONE="${TIME_ZONE:-America/Santo_Domingo}"

# URL del repositorio (opcional, con valor por defecto)
read -rp "URL del repositorio [https://github.com/br4ndol/arch-old.git]: " REPO_URL
REPO_URL="${REPO_URL:-https://github.com/br4ndol/arch-old.git}"

# --- Variables de Configuración (ahora dinámicas) ---
export LOCALE="en_US.UTF-8 UTF-8"  # Inglés (fijo, como pediste)

msg "============================================="
msg "Configuración aplicada:"
msg "Partición EFI: /dev/$PART_EFI"
msg "Partición Raíz: /dev/$PART_ROOT"
msg "Usuario: $TARGET_USER"
msg "Hostname: $HOST_NAME"
msg "Zona horaria: $TIME_ZONE"
msg "Repositorio: $REPO_URL"
msg "============================================="

#
#   Paso 2
#

# --- 1. Verificaciones Iniciales ---
msg "Verificando entorno de instalación..."

# Verificar conexión a internet (usando curl en lugar de ping)
if ! curl -s --connect-timeout 5 -I https://archlinux.org &>/dev/null; then
    error "No hay conexión a internet. Conéctate vía Ethernet o iwctl antes de continuar."
    exit 1
fi
success "Conexión a internet activa."

# Verificar modo UEFI
if [ ! -d "/sys/firmware/efi" ]; then
    error "El sistema no inició en modo UEFI. Este script requiere arranque UEFI."
    exit 1
fi
success "Sistema iniciado en modo UEFI."

# Desmontar limpiamente cualquier montaje previo en /mnt antes de formatear
umount -R /mnt 2>/dev/null || true

# Formatear la partición raíz (ext4) de manera forzada para eliminar el sistema anterior
msg "Formateando /dev/$PART_ROOT como ext4..."
if mkfs.ext4 -F "/dev/$PART_ROOT"; then
    success "Partición /dev/$PART_ROOT formateada como ext4 (limpieza completa)."
else
    error "Error al formatear la partición raíz."
    exit 1
fi

# Formatear la partición EFI (FAT32) de manera forzada para limpiar bootloaders antiguos
msg "Formateando /dev/$PART_EFI como FAT32..."
if mkfs.fat -F32 "/dev/$PART_EFI"; then
    success "Partición /dev/$PART_EFI formateada como FAT32."
else
    error "Error al formatear la partición EFI."
    exit 1
fi

# --- 2. Montar Particiones ---
msg "Preparando y montando particiones..."

# Montar partición Raíz (ext4)
if [ -b "/dev/$PART_ROOT" ]; then
    mount "/dev/$PART_ROOT" /mnt
    success "Partición raíz (/dev/$PART_ROOT) montada en /mnt."
else
    error "No se encontró el dispositivo de la partición raíz: /dev/$PART_ROOT"
    exit 1
fi

# Crear directorio efi y montar partición EFI (FAT32)
if [ -b "/dev/$PART_EFI" ]; then
    mkdir -p /mnt/efi
    mount "/dev/$PART_EFI" /mnt/efi
    success "Partición EFI (/dev/$PART_EFI) montada en /mnt/efi."
else
    error "No se encontró el dispositivo de la partición EFI: /dev/$PART_EFI"
    exit 1
fi

#
#   Paso 3
#

# --- 3. Inyección de CachyOS v3 en la ISO ---
msg "Configurando llaves y repositorios de CachyOS v3 en la ISO..."

# Importar y firmar llaves GPG de CachyOS
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47

# Descargar e instalar paquetes de llaves y mirrorlists oficiales
msg "Descargar e instalar paquetes de llaves y mirrorlists de CachyOS..."
pacman -U --noconfirm \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-27-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-27-1-any.pkg.tar.zst'

# Configurar soporte para arquitectura x86_64_v3
msg "Configurar soporte para arquitectura x86_64_v3..."
sed -i 's/^Architecture = .*/Architecture = x86_64 x86_64_v3/' /etc/pacman.conf

# Insertar repositorios de CachyOS v3 justo ARRIBA de [core] para darles máxima prioridad
msg "Insertar repositorios de CachyOS v3 justo ARRIBA de [core] para darles máxima prioridad..."
if ! grep -q "cachyos-v3" /etc/pacman.conf; then
    sed -i '/^\[core\]/i \
# CachyOS optimized repos - x86-64-v3\n[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n[cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n' /etc/pacman.conf
fi

# Sincronizar bases de datos de pacman
msg "Sincronizando bases de datos de pacman..."
pacman -Syy
success "Repositorios de CachyOS v3 inyectados arriba de los repositorios oficiales."

#
#   Paso 4
#

# --- 4. Instalación Base con pacstrap ---
msg "Ejecutando pacstrap con el Kernel CachyOS-bore y paquetes base..."

pacstrap -K /mnt \
    base base-devel \
    linux-firmware-intel linux-firmware-nvidia linux-firmware-realtek linux-firmware-cirrus linux-firmware-other \
    cachyos-v3/linux-cachyos-bore \
    cachyos-v3/linux-cachyos-bore-headers \
    git networkmanager sudo efibootmgr nano

success "Sistema base instalado mediante pacstrap."

#
#   Paso 5
#

# --- 5. Generar fstab ---
msg "Generando archivo /etc/fstab para el nuevo sistema..."
genfstab -U /mnt >> /mnt/etc/fstab

# Verificar que el archivo fstab se generó correctamente
if [ -f "/mnt/etc/fstab" ]; then
    success "Archivo /etc/fstab generado correctamente."
    msg "Contenido de /etc/fstab:"
    cat /mnt/etc/fstab
else
    error "No se pudo generar /etc/fstab. Verifica que las particiones estén montadas correctamente."
    exit 1
fi

#
#   Paso 6
#

# --- 6. Configuración dentro de chroot ---
msg "Iniciando configuración en chroot (/mnt)..."

# EXPORTAR variables necesarias para que el entorno chroot las reconozca
export TARGET_USER HOST_NAME TIME_ZONE REPO_URL PASSWORD PART_EFI PART_ROOT

arch-chroot /mnt /bin/bash <<'EOF'
set -e

# --- Redefinir funciones y colores para el entorno chroot ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

msg() { echo -e "${YELLOW}[BOOTSTRAP]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# --- Configurar Zona Horaria ---
msg "Configurando zona horaria a $TIME_ZONE..."
ln -sf /usr/share/zoneinfo/"$TIME_ZONE" /etc/localtime
hwclock --systohc
success "Zona horaria configurada."

# --- Configurar Locales (Inglés) ---
msg "Configurando locales en_US.UTF-8..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
success "Locales configurados."

# --- Configurar Hostname ---
msg "Configurando hostname a $HOST_NAME..."
echo "$HOST_NAME" > /etc/hostname
success "Hostname configurado."

# --- Instalar paquetes de CachyOS v3 en el nuevo sistema ---
msg "Instalando paquetes de CachyOS v3 (keyring y mirrorlists)..."
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47

pacman -U --noconfirm \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-27-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-27-1-any.pkg.tar.zst'

# --- Configurar pacman.conf en el nuevo sistema ---
msg "Configurando repositorios de CachyOS v3 en el nuevo sistema..."
sed -i 's/^Architecture = .*/Architecture = x86_64 x86_64_v3/' /etc/pacman.conf

# Insertar repositorios de CachyOS v3 ARRIBA de [core]
if ! grep -q "cachyos-v3" /etc/pacman.conf; then
    sed -i '/^\[core\]/i \
# CachyOS optimized repos - x86-64-v3\n[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n[cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n' /etc/pacman.conf
fi

success "Repositorios de CachyOS v3 configurados en el nuevo sistema."

# Habilitar repositorio [multilib]
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf

# --- Configurar llaves y repositorios de Chaotic-AUR y CachyOS Base (Al Final) ---
msg "Configurando llaves de Chaotic-AUR..."
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB

msg "Instalando llaveros y mirrorlists de Chaotic-AUR..."
pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

# Agregar al final del pacman.conf si no existen
if ! grep -q "chaotic-aur" /etc/pacman.conf; then
    msg "Añadiendo repositorios chaotic-aur y cachyos al final de pacman.conf..."
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n\n[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist" >> /etc/pacman.conf
fi

# Sincronizar bases de datos de pacman definitivas
pacman -Syy
success "Todos los repositorios (CachyOS v3, Multilib, Chaotic-AUR y CachyOS base) configurados con éxito."

# --- Crear Usuario Principal ---
msg "Creando usuario $TARGET_USER..."
if ! id "$TARGET_USER" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash "$TARGET_USER"
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
    chmod 0440 /etc/sudoers.d/wheel
    echo "$TARGET_USER:$PASSWORD" | chpasswd
    echo "root:$PASSWORD" | chpasswd
    success "Usuario $TARGET_USER creado con permisos sudo."
else
    msg "El usuario $TARGET_USER ya existe."
fi

# --- Habilitar NetworkManager ---
msg "Habilitando NetworkManager..."
systemctl enable NetworkManager.service
success "NetworkManager habilitado."

# --- Configurar cmdline de arranque para la UKI ---
msg "Generando archivo /etc/kernel/cmdline..."
ROOT_UUID=$(blkid -s UUID -o value "/dev/$PART_ROOT")
echo "root=UUID=$ROOT_UUID rw quiet loglevel=3" > /etc/kernel/cmdline
success "Archivo /etc/kernel/cmdline configurado con UUID=$ROOT_UUID."

# --- Configurar archivo preset para UKI (EFISTUB) ---
PRESET_FILE="/etc/mkinitcpio.d/linux-cachyos-bore.preset"
UKI_PATH="/efi/EFI/Linux/arch-linux-cachyos-bore.efi"

msg "Configurando preset de mkinitcpio para UKI..."
if [ -f "$PRESET_FILE" ]; then
    sed -i "s/^PRESETS=.*/PRESETS=('default')/" "$PRESET_FILE"
    
    if grep -q "default_uki" "$PRESET_FILE"; then
        sed -i "s|^#*default_uki=.*|default_uki=\"$UKI_PATH\"|" "$PRESET_FILE"
    else
        echo "default_uki=\"$UKI_PATH\"" >> "$PRESET_FILE"
    fi
    
    if grep -q "default_options" "$PRESET_FILE"; then
        sed -i "s|^#*default_options=.*|default_options=\"\"|" "$PRESET_FILE"
    else
        echo 'default_options=""' >> "$PRESET_FILE"
    fi
    success "Preset configurado."
else
    error "No se encontró el preset de mkinitcpio."
    exit 1
fi

# --- Generar la imagen de arranque unificada (UKI) ---
msg "Generando Unified Kernel Image (UKI)..."
mkdir -p /efi/EFI/Linux
mkinitcpio -p linux-cachyos-bore

# --- Copiar UKI como ejecutable de respaldo por defecto (Soluciona pérdidas de NVRAM en QEMU) ---
msg "Configurando ejecutable de arranque de respaldo UEFI..."
mkdir -p /efi/EFI/BOOT
cp -f "$UKI_PATH" /efi/EFI/BOOT/BOOTX64.EFI
success "Ejecutable de respaldo UEFI configurado correctamente."

# --- Registrar entrada UEFI en la placa madre ---
msg "Limpiando entradas UEFI previas (de reinstalaciones/pruebas anteriores)..."
ESP_DEV=$(findmnt -no SOURCE /efi)
if [ -n "$ESP_DEV" ]; then
    DISK="/dev/$(lsblk -no PKNAME "$ESP_DEV")"
    PART="$(lsblk -no PARTN "$ESP_DEV")"

    # Elimina cualquier entrada previa con nuestro label o la genérica
    # "UEFI OS" que el firmware crea al detectar el fallback BOOTX64.EFI.
    # grep -F (cadena literal) evita que los paréntesis del label rompan el regex.
    mapfile -t boot_nums < <(efibootmgr | grep -F -e "Arch Linux (cachyos-bore)" -e "UEFI OS" | grep -oP '^Boot\K[0-9A-Fa-f]{4}')
    if [ "${#boot_nums[@]}" -gt 0 ]; then
        for num in "${boot_nums[@]}"; do
            efibootmgr -b "$num" -B >/dev/null
            msg "Entrada UEFI previa eliminada: Boot$num"
        done
    fi

    msg "Creando entrada de arranque UEFI en la NVRAM..."
    # Crear la entrada utilizando efibootmgr
    efibootmgr --create --disk "$DISK" --part "$PART" --label "Arch Linux (cachyos-bore)" --loader '\EFI\Linux\arch-linux-cachyos-bore.efi'
    success "Entrada UEFI registrada con efibootmgr (sin duplicados)."
else
    error "No se pudo detectar el disco de /efi para efibootmgr."
fi

# --- Clonar repositorio arch-setup ---
msg "Clonando repositorio $REPO_URL..."
HOME_DIR="/home/$TARGET_USER"
if [ ! -d "$HOME_DIR/arch" ]; then
    git clone "$REPO_URL" "$HOME_DIR/arch"
    chown -R "$TARGET_USER:$TARGET_USER" "$HOME_DIR/arch"
    success "Repositorio clonado en $HOME_DIR/arch."
else
    msg "El repositorio ya existe en $HOME_DIR/arch."
fi

EOF

success "🎉 Configuración en chroot completada con éxito."

#
#   Paso 7
#

# --- 7. Finalización y desmontaje ---
msg "Desmontando particiones..."
umount -R /mnt 2>/dev/null || true
success "Particiones desmontadas correctamente."

msg "============================================="
msg "¡Bootstrap completado con éxito!"
msg "============================================="
msg "Pasos siguientes:"
msg "1. Reinicia el sistema: 'reboot'"
msg "2. Inicia sesión con el usuario: $TARGET_USER (contraseña: $PASSWORD)"
msg "3. Ejecuta el script de configuración:"
msg "   cd ~/arch && sudo ./setup.sh"
msg "============================================="
