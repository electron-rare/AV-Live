# Hantek 6022BL — setup macOS Apple Silicon

Le Hantek 6022BL est un oscilloscope USB 2 voies, 8-bit, basé sur le microcontrôleur Cypress FX2LP (CY7C68013A). Le FX2 n'a pas de mémoire flash : à chaque branchement USB, un firmware doit être uploadé en RAM. Tant que ce n'est pas fait, le device énumère avec un descripteur générique (PID `0x6022`) et n'a pas d'endpoint bulk fonctionnel.

Le firmware open-source de référence est celui du projet [OpenHantek6022](https://github.com/OpenHantek/OpenHantek6022) (GPL-3.0). Une fois chargé, le device réénumère en `0x04B5:0x602A` avec un endpoint bulk IN sur `0x86`.

## 1. Installer libusb et fxload

```bash
brew install libusb fxload
```

Vérifier que `fxload` est bien sous `/opt/homebrew/bin/fxload` (Apple Silicon) ou `/usr/local/bin/fxload` (Intel).

## 2. Récupérer ou builder le firmware

### Option A — pré-built depuis OpenHantek6022

Le repo upstream fournit des `.hex` pré-buildés dans `openhantek/res/firmware/` :

```bash
git clone https://github.com/OpenHantek/OpenHantek6022.git
ls OpenHantek6022/openhantek/res/firmware/
# Hantek6022BE.hex  Hantek6022BL.hex  ...
```

Pour le 6022BL spécifiquement, utiliser `Hantek6022BL.hex`.

### Option B — build from source

Le firmware est en C8051, buildable avec `sdcc` :

```bash
brew install sdcc
cd OpenHantek6022/openhantek/res/firmware/build
make
# produit .hex et .iic
```

## 3. Identifier le bus/device USB

Brancher le scope, puis :

```bash
system_profiler SPUSBDataType | grep -A 6 "Hantek\|6022\|04b5"
```

Vous devriez voir une entrée avec `Vendor ID: 0x04b5` et `Product ID: 0x6022` (avant firmware).

Pour avoir bus/device au format requis par fxload, sur macOS la convention `/dev/bus/usb/` n'existe pas — il faut utiliser libusb directement. Une option simple :

```bash
# Lister les devices avec libusb (depuis brew)
ioreg -p IOUSB -l -w 0 | grep -i hantek
```

## 4. Charger le firmware

### Méthode A — fxload (Linux-style, peut nécessiter adaptation)

Sur Linux : `fxload -t fx2lp -I Hantek6022BL.hex -D /dev/bus/usb/001/005`.

Sur macOS, `fxload` Homebrew accepte `-D` au format `vid:pid` ou via libusb device path. Tester :

```bash
sudo fxload -t fx2lp -I Hantek6022BL.hex
# (sans -D, scanne tous les FX2 et upload sur le premier)
```

### Méthode B — utilitaire Python avec libusb

Plus fiable sur macOS, le repo OpenHantek6022 fournit un script ou vous pouvez utiliser `pyusb` :

```python
# upload_firmware.py
import usb.core, time
from intelhex import IntelHex

dev = usb.core.find(idVendor=0x04B5, idProduct=0x6022)
ih = IntelHex("Hantek6022BL.hex")

# Stop CPU
dev.ctrl_transfer(0x40, 0xA0, 0xE600, 0, [0x01])
# Upload
for start, end in ih.segments():
    chunk = ih.tobinarray(start=start, size=end-start)
    dev.ctrl_transfer(0x40, 0xA0, start, 0, chunk.tobytes())
# Start CPU
dev.ctrl_transfer(0x40, 0xA0, 0xE600, 0, [0x00])
time.sleep(1)
print("Firmware uploaded.")
```

```bash
pip install pyusb intelhex
sudo python upload_firmware.py
```

### Méthode C — passer par OpenHantek6022 lui-même

Si vous installez OpenHantek6022 en .app sur macOS, son lancement charge automatiquement le firmware. Vous pouvez le lancer une fois (qui charge le firmware), le quitter, puis lancer `oscope-of` qui trouvera le device en mode firmware.

## 5. Vérifier le succès du chargement

Après upload, le device doit réénumérer en quelques secondes :

```bash
system_profiler SPUSBDataType | grep -A 6 "04b5"
# Product ID: 0x602a    <-- firmware chargé
```

## 6. Permissions USB sur macOS

macOS Sequoia/Sonoma demande une autorisation explicite pour qu'une application non signée Apple accède aux devices USB.

- **Réglages Système → Confidentialité et sécurité → Périphériques USB / Surveillance des entrées** : ajouter le binaire `oscope-of` à la liste autorisée.
- En cas d'échec persistant : `sudo /Users/<vous>/.../oscope-of.app/Contents/MacOS/oscope-of` pour test (lancer en root contourne les ACL).

## 7. Diagnostic

Le binaire `oscope-of` log les statuts au démarrage :

- `Hantek 6022BL trouvé MAIS firmware non chargé` → revenir à l'étape 4
- `claim_interface failed` → permissions USB ou device claimé par une autre app
- `bulk_transfer: LIBUSB_ERROR_TIMEOUT` répétés → le firmware est chargé mais ne stream pas ; vérifier sample rate et gain

## 8. Re-uploader à chaque branchement

Le firmware vit en RAM : débrancher = perdre le firmware. Pour automatiser, créer un service launchd ou un script `usb_arrived.sh` qui détecte le PID `0x6022` et lance l'upload.

## Liens

- [OpenHantek6022 firmware source](https://github.com/OpenHantek/OpenHantek6022/tree/main/openhantek/res/firmware)
- [Cypress FX2LP datasheet](https://www.infineon.com/dgdl/Infineon-CY7C68013A_CY7C68014A_CY7C68015A_CY7C68016A_EZ-USB_FX2LP_USB_Microcontroller_High_Speed_USB_Peripheral_Controller-DataSheet-v17_00-EN.pdf)
- [libusb-1.0 API doc](https://libusb.sourceforge.io/api-1.0/)
