#!/bin/sh

QEMU_COMMAND="qemu-system-x86_64"
ENABLE_USB=false

# PCIE_BUS_INDEX
PBI=1

while [ $# -gt 0 ]; do
    case $1 in
    -h | --help)
        echo "Usage: $0"
        shift
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
    ## --firmware and --firmware-vars are used for UEFI
    --firmware*)
        CMDLINE="$CMDLINE -drive if=pflash,format=raw,file=$2"
        if [ "$1" != "--firmware-vars" ]; then
            CMDLINE="$CMDLINE,readonly=true"
        fi
        shift 2
        ;;
    # Amount of memory
    -m | --memory)
        CMDLINE="$CMDLINE -m $2"
        shift 2
        ;;
    # Number of cores
    --cores)
        CMDLINE="$CMDLINE -smp $2"
        shift 2
        ;;
    # Classic CD-ROM
    -c | --cdrom)
        CMDLINE="$CMDLINE -drive file=$2,format=raw,media=cdrom"
        shift 2
        ;;
    # VirtIO drive
    -d | --drive)
        CMDLINE="$CMDLINE -drive file=$2,if=virtio"
        shift 2
        ;;
    # Non VirtIO drive
    --drive-classic)
        CMDLINE="$CMDLINE -drive file=$2"
        shift 2
        ;;
    # IPv4 NIC virtio
    --nic-virtio)
        CMDLINE="$CMDLINE -nic user,ipv6=off,model=virtio,mac=$2"
        shift 2
        ;;
    # IPv4 NIC non-virtio
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
        CMDLINE="$CMDLINE -device usb-host,vendorid=0x$2,productid=0x$3"
        ENABLE_USB=true
        shift 3
        ;;
    # Virtio Audio. Mainly used for Linux.
    --audio-virtio)
        CMDLINE="$CMDLINE -audio pipewire,model=virtio"
        shift
        ;;
    # HDA Audio. Mainly used for Windows.
    --audio-hda)
        CMDLINE="$CMDLINE -audio pipewire,model=hda"
        shift
        ;;
    --passthrough*)
        # Create PCI-e port
        CMDLINE="$CMDLINE -device pcie-root-port,id=rp$PBI,chassis=$PBI,slot=$PBI"
        # Assign the vfio device to that port
        CMDLINE="$CMDLINE -device vfio-pci,host=$2,bus=rp$PBI"

        if [ "$1" = "--passthrough-romfile" ]; then
            CMDLINE="$CMDLINE,romfile=$3"
            shift
        fi

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
