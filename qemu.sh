#!/bin/sh

QEMU_COMMAND="qemu-system-x86_64"
ENABLE_USB=false

# PCIE_BUS_INDEX
PBI=1

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Display Options:
  --headless              No viewer, serial only (for servers)
  --gtk                   GTK viewer with VirtIO VGA (for Linux)
  --spice                 SPICE display with QXL (for Windows)

System Configuration:
  --memory SIZE           Amount of memory (e.g., 4G, 8192M)
  --cores NUM             Number of CPU cores
  --firmware FILE         UEFI firmware file (read-only)
  --firmware-vars FILE    UEFI variables file (writable)

Storage:
  --cdrom FILE            Attach CD-ROM image
  --drive FILE            VirtIO drive
  --drive-classic FILE    Non-VirtIO drive

Network:
  --nic-virtio MAC        VirtIO NIC with specified MAC address
  --nic-classic MAC       Non-VirtIO NIC with specified MAC address

Input Devices:
  --tablet                Add USB tablet (absolute pointing device)

USB Passthrough:
  --usb-host VID:PID      Pass host USB device (vendor ID and product ID in hex)

Audio:
  --audio-virtio          VirtIO audio (for Linux)
  --audio-hda             HDA audio (for Windows)

PCI Passthrough:
  --passthrough ADDR      Pass through PCI device at address (e.g., 0000:01:00.0)
  --passthrough-romfile ADDR FILE
                          Pass through PCI device with custom ROM file

Other:
  -h, --help              Show this help message
  *                       Any unrecognized options are passed to QEMU

Examples:
  $0 --gtk -m 4G --cores 4 -d disk.qcow2
  $0 --spice -m 8G --cores 8 --firmware /usr/share/edk2/ovmf/OVMF_CODE.fd \\
     --firmware-vars vars.fd -d windows.qcow2 --nic-virtio 52:54:00:12:34:56
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    # No viewer. Just serial. Good for servers.
    --headless)
        CMDLINE="$CMDLINE -nographic"
        shift
        ;;
    # GTK viewer. Mainly used for Linux. Great performance.
    --gtk)
        CMDLINE="$CMDLINE --display gtk,grab-on-hover=on"
        CMDLINE="$CMDLINE -vga virtio"
        shift
        ;;
    # Enables SPICE stuff. Mainly used for Windows.
    --spice)
        # Use virt-viewer
        CMDLINE="$CMDLINE --display spice-app"

        # Create communication channel for SPICE
        CMDLINE="$CMDLINE -device virtio-serial-pci,id=virtio-serial0"
        CMDLINE="$CMDLINE -chardev spicevmc,id=charchannel1,name=vdagent"
        CMDLINE="$CMDLINE -device virtserialport,bus=virtio-serial0.0,nr=2,chardev=charchannel1,id=channel1,name=com.redhat.spice.0"

        # To make it able to use high resolutions
        CMDLINE="$CMDLINE -device qxl-vga,vgamem_mb=128"
        shift
        ;;
    # --firmware and --firmware-vars are used for UEFI
    # Usually --firmware OVMF_CODE.fd or OVMF_CODE.secboot.fd and
    # --firmware-vars OVMF_VARS.fd or OVMF_VARS.secboot.fd
    --firmware*)
        CMDLINE="$CMDLINE -drive if=pflash,format=raw,file=$2"
        if [ "$1" != "--firmware-vars" ]; then
            CMDLINE="$CMDLINE,readonly=true"
        fi
        shift 2
        ;;
    # Amount of memory
    --memory)
        CMDLINE="$CMDLINE -m $2"
        shift 2
        ;;
    # Number of cores
    --cores)
        CMDLINE="$CMDLINE -smp $2"
        shift 2
        ;;
    # Classic CD-ROM
    --cdrom)
        CMDLINE="$CMDLINE -drive file=$2,format=raw,media=cdrom"
        shift 2
        ;;
    # VirtIO drive
    --drive)
        CMDLINE="$CMDLINE -drive file=$2,if=virtio"
        shift 2
        ;;
    # Non VirtIO drive
    --drive-classic)
        CMDLINE="$CMDLINE -drive file=$2"
        shift 2
        ;;
    # VirtIO IPv4 NIC
    --nic-virtio)
        CMDLINE="$CMDLINE -nic user,ipv6=off,model=virtio,mac=$2"
        shift 2
        ;;
    # Non VirtIO IPv4 NIC
    --nic-classic)
        CMDLINE="$CMDLINE -nic user,ipv6=off,mac=$2"
        shift 2
        ;;
    # Create an absolute pointing device.
    --tablet)
        CMDLINE="$CMDLINE -device usb-tablet"
        ENABLE_USB=true
        shift
        ;;
    # Pass host USB to the VM.
    --usb-host)
        VID=$(echo "$2" | cut -d: -f1)
        PID=$(echo "$2" | cut -d: -f2)
        CMDLINE="$CMDLINE -device usb-host,vendorid=0x$VID,productid=0x$PID"
        ENABLE_USB=true
        shift 2
    ;;
    # VirtIO Audio. Mainly used for Linux.
    --audio-virtio)
        CMDLINE="$CMDLINE -audio pipewire,model=virtio"
        shift
        ;;
    # HDA Audio. Mainly used for Windows.
    --audio-hda)
        CMDLINE="$CMDLINE -audio pipewire,model=hda"
        shift
        ;;
    # Passthrough PCI devices
    --passthrough*)
        # Create PCI-e port
        CMDLINE="$CMDLINE -device pcie-root-port,id=rp$PBI,chassis=$PBI,slot=$PBI"
        # Assign the vfio device to that port
        CMDLINE="$CMDLINE -device vfio-pci,host=$2,bus=rp$PBI"

        if [ "$1" = "--passthrough-romfile" ]; then
            CMDLINE="$CMDLINE,romfile=$3"
            shift
        fi
        PBI=$((PBI + 1))
        shift 2
        ;;
    # Pass all the remaining commands directly to QEMU
    *)
        CMDLINE="$CMDLINE $1"
        shift
        ;;
    esac
done

# Putting it before as QEMU enrages if we put it after the devices
if [ "$ENABLE_USB" = true ]; then
    CMDLINE="-device qemu-xhci $CMDLINE"
fi

CMDLINE="$QEMU_COMMAND -machine pc-q35-8.2,acpi=on -accel kvm $CMDLINE"
echo "Full QEMU command line: $CMDLINE"
$CMDLINE
