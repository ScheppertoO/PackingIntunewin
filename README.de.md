# 📦 PackingIntunewin - Portable IntuneWin App Packaging Tool

Ein benutzerfreundliches, **vollständig portables** PowerShell-Tool zur automatischen Erstellung von Microsoft Intune `.intunewin` Paketen aus EXE-Dateien.

## 🎯 **Ziel**

Das Verpacken von `.exe`-Dateien in `.intunewin`-Apps so einfach und automatisiert wie möglich zu gestalten - **ohne manuelle Konfiguration oder feste Pfade**.

## ✨ **Features**

- 🚀 **Vollständig portabel** - funktioniert von jedem Speicherort
- 🔄 **Automatischer Download** der Microsoft IntuneWinAppUtil.exe
- 🗑️ **Intelligente Deinstallation** - Registry-Analyse & EXE-Parameter-Tests
- 📝 **Automatische Batch-Erstellung** - install.cmd & uninstall.cmd
- 📊 **App-Übersicht** - zeigt verfügbare Apps mit Status
- 🔍 **Fehlervalidierung** - prüft EXE-Anzahl und Ordnerstruktur
- 💾 **Vollständige Metadaten** - für Microsoft Intune optimiert
- 🎨 **Farbige Ausgaben** - übersichtliche Fortschrittsanzeige

## 📁 **Ordnerstruktur**

```text
PackingIntunewin/
│
├── Create-IntuneWinApp.ps1              # 🚀 Hauptskript (portable)
├── README.md                            # 📖 Diese Dokumentation
│
├── apps/                                # 📥 Input-Ordner für Ihre Apps
│   ├── Chrome/                          # Beispiel: Chrome-App
│   │   └── chrome-installer.exe         # Ihre EXE-Datei
│   ├── VLC/                            # Beispiel: VLC-App
│   │   └── vlc-installer.exe           # Ihre EXE-Datei
│   └── YourApp/                        # 👈 Ihr App-Ordner
│       └── yourapp.exe                 # 👈 Ihre EXE-Datei (genau eine!)
│
└── IntunewinApps/                      # 📤 Output-Ordner (wird automatisch erstellt)
    ├── tools/                          # 🔧 Microsoft Tools (automatisch heruntergeladen)
    │   └── IntuneWinAppUtil.exe        # Microsoft Intune Win32 Content Prep Tool
    │
    ├── Chrome/                         # 📦 Verpackte Chrome-App
    │   ├── install.cmd                 # Automatisch generiert
    │   ├── uninstall.cmd              # Automatisch generiert
    │   ├── chrome-installer.intunewin  # 🎯 Fertiges Paket für Intune
    │   └── metadata.json               # Vollständige Metadaten
    │
    └── YourApp/                        # 📦 Ihre verpackte App
        ├── install.cmd                 # Automatisch generiert
        ├── uninstall.cmd              # Automatisch generiert  
        ├── yourapp.intunewin           # 🎯 Fertiges Paket für Intune
        └── metadata.json               # Vollständige Metadaten
```

## 🚀 **Schnellstart**

### **Option 1: Launcher verwenden (Empfohlen)**

```powershell
# 1. Repository klonen oder herunterladen
git clone https://github.com/ScheppertoO/PackingIntunewin.git
cd PackingIntunewin

# 2. Rechtsklick auf Start-IntuneWinTool.ps1 und "Mit PowerShell ausführen" wählen
# Oder in PowerShell ausführen:
.\Start-IntuneWinTool.ps1
```

### **Option 2: Direkte Skript-Ausführung**

```powershell
# 1. Repository klonen oder herunterladen
git clone https://github.com/ScheppertoO/PackingIntunewin.git
cd PackingIntunewin

# 2. Spezifisches Skript direkt ausführen
.\Create-IntuneWinApp.ps1     # Kommandozeilen-Version
.\German_GUI_WPF.ps1          # Deutsche GUI
.\ENG_GUI_WPF.ps1            # Englische GUI
```

### **2. App vorbereiten**

```powershell
# Erstellen Sie einen Ordner für Ihre App im 'apps' Verzeichnis
mkdir "apps\MeineApp"

# Kopieren Sie Ihre EXE-Datei hinein (genau eine EXE pro Ordner!)
copy "C:\Downloads\meine-app-installer.exe" "apps\MeineApp\"
```

### **3. Ausführen und konfigurieren**

Das Skript führt Sie durch den Prozess:

- 📋 Zeigt verfügbare Apps an
- ❓ Fragt nach App-Name und Neustart-Anforderungen
- 🔍 Ermittelt automatisch Deinstallations-Informationen
- 📦 Erstellt das fertige `.intunewin` Paket

### ⚠️ **Ausführungsrichtlinien-Hinweis**

Dieses Tool enthält **unsignierte PowerShell-Skripte**. Aufgrund der Windows-Sicherheitsrichtlinien können Ausführungsfehler auftreten. Hier sind die Lösungen:

#### **Lösung 1: Batch-Datei verwenden (Am einfachsten)**
- **Doppelklick** auf `START-TOOL.bat` - behandelt automatisch die Ausführungsrichtlinie

#### **Lösung 2: PowerShell-Kommandozeile**
```powershell
# Zum Tool-Ordner navigieren
cd "C:\Pfad\Zu\PackingIntunewin"

# Mit umgangener Ausführungsrichtlinie starten
powershell -ExecutionPolicy Bypass -File "Start-IntuneWinTool.ps1"
```

#### **Lösung 3: Manuelle Richtlinien-Änderung**
```powershell
# Ausführungsrichtlinie nur für aktuelle Sitzung setzen
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\Start-IntuneWinTool.ps1
```

#### **Lösung 4: Direkte Skript-Ausführung**
```powershell
# Einzelne Skripte direkt ausführen
powershell -ExecutionPolicy Bypass -File "German_GUI_WPF.ps1"
powershell -ExecutionPolicy Bypass -File "ENG_GUI_WPF.ps1"
```

**Hinweis:** Diese Änderungen sind **temporär** und betreffen nur die aktuelle Sitzung. Ihre System-Sicherheitseinstellungen bleiben unverändert.

Das Skript führt Sie durch den Prozess:

- 📋 Zeigt verfügbare Apps an
- ❓ Fragt nach App-Name und Neustart-Anforderung
- 🔍 Ermittelt automatisch Deinstallationsinformationen
- 📦 Erstellt das fertige `.intunewin` Paket

## 🔧 **Automatische Features**

### **Tool Download Process**

```text
🔧 Prüfe IntuneWinAppUtil.exe...
⚠️ IntuneWinAppUtil.exe nicht gefunden, lade von GitHub herunter...
🌐 Suche nach der neuesten Version...
📥 Gefunden: IntuneWinAppUtil.zip (Version: v1.8.6)
📋 Tool-Version: Microsoft Intune Win32 Content Prep Tool version 1.8.6.0
✅ Download erfolgreich! Dateigröße: 0.89 MB
```

### **App-Status-Übersicht**

```text
📋 Verfügbare Apps im 'apps' Ordner:
   ✅ Chrome
   ✅ VLC
   ❌ Broken-App (Keine EXE)
   ⚠️ Multi-EXE-App (Mehrere EXE)
```

### **Intelligente Deinstallation**

```text
🔧 Ermittle Deinstallationsinformationen...
🔍 Suche nach Deinstallationsinformationen für 'Chrome'...
✅ Registry-Eintrag gefunden!
✅ Gefunden: Google Chrome
📝 Verwende QuietUninstallString: MsiExec.exe /X{GUID} /quiet
```

## 📊 **Generierte Dateien**

### **install.cmd**

```batch
@echo off
echo Installing YourApp...
yourapp.exe /silent
if %errorlevel% neq 0 (
    echo Installation failed with exit code %errorlevel%
    exit /b %errorlevel%
)
echo Installation completed successfully
exit /b 0
```

### **uninstall.cmd**

```batch
@echo off
echo Uninstalling YourApp...
MsiExec.exe /X{12345678-1234-1234-1234-123456789012} /quiet
if %errorlevel% neq 0 (
    echo Uninstallation failed with exit code %errorlevel%
    exit /b %errorlevel%
)
echo Uninstallation completed successfully
exit /b 0
```

### **metadata.json**

```json
{
  "AppName": "YourApp",
  "Installer": "yourapp.exe",
  "InstallCommand": "install.cmd",
  "UninstallCommand": "uninstall.cmd",
  "UninstallMethod": "Registry",
  "UninstallString": "MsiExec.exe /X{GUID} /quiet",
  "ExitCode": 0,
  "RebootRequired": false,
  "DetectionType": "Registry (manuell konfigurieren)",
  "CreatedOn": "2025-07-03 14:30",
  "CreatedBy": "username",
  "ScriptVersion": "2.0",
  "WorkingDirectory": "C:\\Path\\To\\PackingIntunewin"
}
```

## 🎯 **Microsoft Intune Konfiguration**

Nach der Erstellung erhalten Sie alle benötigten Informationen:

```text
📋 Informationen für Microsoft Intune:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
App-Name: YourApp
Install-Befehl: install.cmd
Uninstall-Befehl: uninstall.cmd
Rückgabecodes: 0 (Erfolg), 3010 (Neustart erforderlich)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 🛠️ **Erweiterte Funktionen**

### **Deinstallations-Erkennung**

Das Skript verwendet eine **intelligente Mehrstufen-Erkennung**:

1. **Registry-Analyse** (bevorzugt)
   - Durchsucht `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`
   - Durchsucht `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*`
   - Durchsucht `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`

2. **EXE-Parameter-Tests** (Fallback)
   - Testet häufige Parameter: `/uninstall`, `/remove`, `/u`, `/x`
   - Kombiniert mit Silent-Flags: `/silent`, `/quiet`, `/s`, `/q`

3. **Standard-Fallback**
   - Verwendet `/uninstall /silent` als letzte Option

### **Fehlerbehandlung**

- ❌ **Keine EXE**: Klare Fehlermeldung bei fehlender EXE-Datei
- ❌ **Mehrere EXEs**: Warnung bei mehr als einer EXE-Datei
- ❌ **Ordner nicht gefunden**: Hilfreiche Pfad-Anzeige
- 🌐 **Netzwerkfehler**: Graceful Fallback mit manuellen Anweisungen

## 💡 **Tipps & Best Practices**

### **App-Vorbereitung**

- ✅ **Eine EXE pro Ordner**: Genau eine EXE-Datei pro App-Ordner
- ✅ **Aussagekräftige Namen**: Verwenden Sie klare Ordner-Namen (z.B. "Chrome", "VLC")
- ✅ **Silent-Parameter testen**: Prüfen Sie vorab, ob Ihre EXE Silent-Installation unterstützt

### **Portabilität**

- 📁 **Gesamten Ordner kopieren**: Kopieren Sie den kompletten `PackingIntunewin` Ordner
- 🔄 **Keine Pfad-Anpassungen**: Das Skript funktioniert von jedem Speicherort
- 💾 **USB-Stick tauglich**: Perfekt für mobile Nutzung

### **Intune-Integration**

- 📝 **Detection Rules**: Konfigurieren Sie manuell die Erkennungsregeln in Intune
- 🔍 **Registry-Erkennung**: Nutzen Sie die Metadaten für Registry-basierte Erkennung
- 🔄 **Exit-Codes**: Berücksichtigen Sie die dokumentierten Rückgabecodes

## 🆘 **Häufige Probleme & Lösungen**

### **"IntuneWinAppUtil.exe konnte nicht heruntergeladen werden"**

- 🌐 Internetverbindung prüfen
- 🔒 Firewall/Proxy-Einstellungen überprüfen  
- 📥 Das Skript versucht automatisch mehrere Download-Methoden:
  - GitHub Release ZIP-Dateien (bevorzugt)
  - Direkte Download-URLs
  - Repository Raw-Links
- 🛠️ **Manueller Download**: Laden Sie von [Microsoft GitHub](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest) herunter und speichern Sie als `IntunewinApps\tools\IntuneWinAppUtil.exe`

### **"Keine EXE-Dateien gefunden"**

- 📁 Prüfen Sie den App-Ordner unter `apps\YourApp\`
- ✅ Stellen Sie sicher, dass genau eine `.exe` Datei vorhanden ist
- 📋 Verwenden Sie die App-Übersicht zur Diagnose

### **"Deinstallation nicht gefunden"**

- 🔍 Das Skript testet automatisch verschiedene Parameter
- ✏️ Sie können die `uninstall.cmd` manuell anpassen
- 📖 Konsultieren Sie die Dokumentation Ihrer Software

## 🤝 **Beitragen**

Verbesserungsvorschläge und Pull Requests sind willkommen!

1. Fork des Repositories
2. Feature Branch erstellen
3. Änderungen committen
4. Pull Request erstellen

## 📄 **Lizenz**

Dieses Projekt steht unter der MIT-Lizenz.

## 🔗 **Links**

- [Microsoft Intune Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
- [Microsoft Intune Dokumentation](https://docs.microsoft.com/en-us/mem/intune/)
- [PowerShell Dokumentation](https://docs.microsoft.com/en-us/powershell/)

---

💡 **Das Tool ist vollständig portabel und kann überall verwendet werden!** 🚀

## 🤖 **KI-Unterstützung**

Dieses Projekt wurde mit Unterstützung von KI (GitHub Copilot) entwickelt, um die Codequalität, Dokumentation und Benutzererfahrung zu verbessern.
