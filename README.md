# PackingIntunewin

Goal is to keep packing .exe in a intunewin app as easy as possible

IntunewinApps/
│
├── tools/
│   └── IntuneWinAppUtil.exe             # Microsoft Packager Tool
│
├── scripts/
│   └── Create-IntuneWinApp.ps1          # Hauptskript zur Paketierung
│
├── apps/
│   └── *YourApp*/                       # App-spezifischer Ordner (Name = AppName)
│       ├── source/                      # Enthält eps.exe + generiertes install.cmd
│       ├── output/                      # Enthält .intunewin-Datei
│       └── meta/                        # Metadaten wie metadata.json, DetectionRules etc.
