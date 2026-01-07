# Creating a Cloud-init Template in Proxmox

This guide walks you through creating a Ubuntu 22.04 cloud-init template in Proxmox for use with Terraform.

## Step 1: Choose and Download the Image

**Ubuntu Cloud Images:** https://cloud-images.ubuntu.com/

**Use this image:** `noble-server-cloudimg-amd64.img`

**Why this one:**
- UEFI/GPT bootable
- Cloud-init ready
- Smaller than generic images

**Log In**
```bash
# If you are on a machine that is already logged in as sdconrox
ssh pve.sdconrox.com

# If not
ssh sdconrox@pve.sdconrox.com
```

**Make a downloads folder**
```bash
mkdir downloads
cd downloads
```

**Download:**
```bash
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```
### Via Proxmox Web UI:

1. Go to **Datacenter → Storage**
2. Select your storage (e.g., `sdx-vm-0`, `local`, `local-zfs`)
3. Click the **Import** tab
4. Click **Upload** and select the `.img` file
5. Wait for upload to complete

**Note:** The Import tab only uploads the file. It does NOT create a disk. You'll import it as a disk in the next step.

**Note:** I was unable to get the image to work via the UI. Further testing required.

## Step 3: Create VM (Without Disk)

### In the Create VM Wizard:

1. **General:**
   - VM ID: `9000` (or any available ID)
   - Name: `ubuntu-24.04-cloudinit`
   - OS: **Linux, 6.x kernel** (or any Linux option)

2. **System:**
   - Machine: `q35` (or default)
   - BIOS: **OVMF (UEFI)** ✓ (required for cloud images)
   - Add EFI Disk: **Checked** ✓ (required for UEFI)
   - EFI Storage: Select your storage
   - SCSI Controller: `VirtIO SCSI single` (or default)

3. **Disks:**
   - **Do NOT create a disk here** - set size to minimum (1GB) or skip if possible
   - We'll import the image as a disk after VM creation

4. **CPU:**
   - Sockets: `2`
   - Cores: `4`
   - Type: `host` (or default)

5. **Memory:**
   - RAM: `4096` MB (minimum for template)

6. **Network:**
   - Bridge: `vmbr0`
   - Model: `VirtIO`

7. **Finish the wizard** (don't start the VM yet)

**Important:** Do NOT select any ISO or installation media. The cloud image already contains a bootable OS.

## Step 4: Import the Disk Image

The Import tab only uploads files. You must use the command line to convert the uploaded image into a VM disk.

### Find the Uploaded File:

SSH into your Proxmox node and locate the file:

```bash
# Check common locations (adjust storage name as needed)
ls -lh /mnt/pve/sdx-vm-0/template/iso/
ls -lh /mnt/pve/sdx-vm-0/images/

# Or search for it
find /mnt/pve -name "*jammy*" -o -name "*cloudimg*" 2>/dev/null
```

### Import as Disk:

```bash
# Replace these values:
# - 9000 = your VM ID
# - /path/to/image.img = actual path from above
# - sdx-vm-0 = your storage name (where you want the disk created)

qm importdisk 9000 noble-server-cloudimg-amd64.img sdx-vm-0
```

**Note:** The disk will be created as `.raw` format. This is fine - raw works perfectly. If you prefer qcow2, you can convert it later, but it's not necessary.

### Attach the Imported Disk:

1. Go to your VM → **Hardware**
2. You should see a new unused disk listed
3. Click it → **Edit**
4. Set **Bus/Device** (e.g., SCSI 0)
5. **Save**

## Step 5: Add Cloud-init Drive

1. VM → **Hardware** → **Add** → **CloudInit Drive**

2. Configure:
   - **Bus/Device:** **IDE 2** (default is fine)
   - **Storage:** Your storage (NFS or local - doesn't matter, it's tiny)
   - **Format:** **raw** (default)

3. Click **Add**

**Note:** The cloud-init drive is small (few MB) and only read at boot time. Storage speed doesn't matter - NFS is fine.

## Step 6: Configure Cloud-init

1. VM → **Hardware** → Click on **CloudInit Drive**

2. Configure:
   - **User:** `sdconrox`
   - **Password:** Leave empty (use SSH keys instead)
   - **SSH Public Keys:** Paste your public key
   - **DNS:** `8.8.8.8`
   - **IP Config:** DHCP or static (your choice)

3. **Save**

## Step 7: Set Boot Order

1. VM → **Options**
2. **Boot Order:** Ensure the imported OS disk is first

## Step 8: Start and Verify VM

1. **Start** the VM
2. Wait 1-2 minutes for cloud-init to complete
3. Check console for boot completion
4. Test SSH:
   ```bash
   ssh sdconrox@<vm-ip-address>
   ```

5. Verify cloud-init worked:
   ```bash
   # Check cloud-init logs
   sudo cat /var/log/cloud-init-output.log

   # Check if your SSH key is present
   cat ~/.ssh/authorized_keys
   ```

## Step 9: Convert to Template

1. **Stop** the VM
2. Right-click VM → **Convert to Template**
3. Confirm

## Step 10: Note the Template Name

The template name must match exactly in Terraform. Check:
- **Datacenter → VM Templates**
- Note the exact name (e.g., `ubuntu-22.04-cloudinit`)

Update `terraform/terraform.tfvars`:
```hcl
vm_template_name = "ubuntu-22.04-cloudinit"  # Match exactly!
```

## Quick Reference

- **Image:** `jammy-server-cloudimg-amd64.img`
- **Format:** QCow2 (KVM-optimized)
- **Size:** ~629MB
- **Default user:** `sdconrox`
- **BIOS:** OVMF (UEFI) - EFI disk required
- **Cloud-init:** IDE 2, any storage
- **Disk format:** Raw is fine (qcow2 optional)

## Troubleshooting

### Image won't boot
- Ensure UEFI is selected (OVMF)
- Verify EFI disk is added
- Check boot order has OS disk first

### Cloud-init not working
- Verify Cloud-init Drive is added (IDE 2)
- Check cloud-init configuration (user, SSH keys)
- Review cloud-init logs in VM

### SSH key not working
- Verify key format (should be one line)
- Check cloud-init logs: `sudo cat /var/log/cloud-init-output.log`
- Ensure key is in `~/.ssh/authorized_keys` in VM

### Can't find uploaded image
- Check: `/mnt/pve/<storage-name>/template/iso/`
- Or: `/mnt/pve/<storage-name>/images/`
- Use `find /mnt/pve -name "*jammy*"` to search

### Import creates raw instead of qcow2
- **This is fine!** Raw format works perfectly
- Conversion to qcow2 is optional and not necessary

## Command Line Alternative

If the UI is confusing, you can do everything via CLI:

```bash
# Create VM
qm create 9000 --name ubuntu-22.04-cloudinit --memory 2048 --net0 virtio,bridge=vmbr0

# Import disk
qm importdisk 9000 /path/to/jammy-server-cloudimg-amd64.img sdx-vm-0

# Attach disk
qm set 9000 --scsihw virtio-scsi-pci --scsi0 sdx-vm-0:vm-9000-disk-0

# Set boot order
qm set 9000 --boot c --bootdisk scsi0

# Add cloud-init drive
qm set 9000 --ide2 sdx-vm-0:cloudinit

# Configure cloud-init
qm set 9000 --ciuser ubuntu
qm set 9000 --sshkeys ~/.ssh/id_rsa.pub
qm set 9000 --ipconfig0 ip=dhcp

# Enable agent
qm set 9000 --agent enabled=1

# Start to test
qm start 9000

# After verification, stop and convert
qm stop 9000
qm template 9000
```

