#!/bin/sh

ENABLE_USB=false

while [ $# -gt 0 ]; do
    case $1 in
    -h | --help)
        echo "Usage: $0"
        shift
        ;;
    --gtk)
        CMDLINE="$CMDLINE --display gtk,grab-on-hover=on"
        CMDLINE="$CMDLINE -vga virtio"
        shift
        ;;
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
    -m | --memory)
        CMDLINE="$CMDLINE -m $2"
        shift 2
        ;;
    --cores)
        CMDLINE="$CMDLINE -smp $2"
        shift 2
        ;;
    -c | --cdrom)
        CMDLINE="$CMDLINE -drive file=$2,format=raw,media=cdrom"
        shift 2
        ;;
    -d | --drive)
        CMDLINE="$CMDLINE -drive file=$2,if=virtio"
        shift 2
        ;;
    --drive-classic)
        CMDLINE="$CMDLINE -drive file=$2"
        shift 2
        ;;
    -n | --nic-user)
        CMDLINE="$CMDLINE -nic user,ipv6=off,model=virtio,mac=$2"
        shift 2
        ;;
    --tablet)
        CMDLINE="$CMDLINE -device usb-tablet"
        ENABLE_USB=true
        shift
        ;;
    --usb-host)
        CMDLINE="$CMDLINE -device usb-host,vendorid=0x$2,productid=0x$3"
        ENABLE_USB=true
        shift 3
        ;;
    --audio-virtio)
        CMDLINE="$CMDLINE -audio pipewire,model=virtio"
        shift
        ;;
    --audio-hda)
        CMDLINE="$CMDLINE -audio pipewire,model=hda"
        shift
        ;;
    *)
        CMDLINE="$CMDLINE $1"
        shift
        ;;
    esac
done

if [ "$ENABLE_USB" = true ]; then
    CMDLINE="$CMDLINE -device qemu-xhci"
fi

CMDLINE="qemu-system-x86_64 -nodefaults -monitor stdio -machine pc-q35-8.2,acpi=on -accel kvm $CMDLINE"
echo "$CMDLINE"
$CMDLINE
