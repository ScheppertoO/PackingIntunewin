# 📦 PackingIntunewin - Portable IntuneWin App Packaging Tool

Ein benutzerfreundliches, **vollstaendig portables** PowerShell-Tool zur automatischen Erstellung von Microsoft Intune `.intunewin` Paketen aus EXE-Dateien.

## 🌍 **Language / Sprache**

- 🇩🇪 **Deutsch** (diese Datei)  
- 🇺🇸 **English** → [README.md](README.md)

## 🎯 **Ziel**

Das Verpacken von `.exe`-Dateien in `.intunewin`-Apps so einfach und automatisiert wie moeglich zu gestalten - **ohne manuelle Konfiguration oder feste Pfade**.

## ✨ **Features**

- 🚀 **Vollstaendig portabel** - funktioniert von jedem Speicherort
- 🔄 **Automatischer Download** der Microsoft IntuneWinAppUtil.exe
- 🗑️ **Intelligente Deinstallation** - Registry-Analyse & EXE-Parameter-Tests
- 📝 **Automatische Batch-Erstellung** - install.cmd & uninstall.cmd
- 📊 **App-uebersicht** - zeigt verfuegbare Apps mit Status
- 🔍 **Fehlervalidierung** - prueft EXE-Anzahl und Ordnerstruktur
- 💾 **Vollstaendige Metadaten** - fuer Microsoft Intune optimiert
- 🎨 **Farbige Ausgaben** - uebersichtliche Fortschrittsanzeige

## ⚠️ **Ausfuehrungsrichtlinien-Hinweis**

Dieses Tool enthaelt **unsignierte PowerShell-Skripte**. Aufgrund der Windows-Sicherheitsrichtlinien koennen Ausfuehrungsfehler auftreten. Hier sind die Loesungen:

### **Loesung 1: Batch-Datei verwenden (Am einfachsten)**

- **Doppelklick** auf `START-TOOL.bat` - behandelt automatisch die Ausfuehrungsrichtlinie

### **Loesung 2: PowerShell-Kommandozeile**

```powershell
# Zum Tool-Ordner navigieren
cd "C:\Pfad\Zu\PackingIntunewin"

# Mit umgangener Ausfuehrungsrichtlinie starten
powershell -ExecutionPolicy Bypass -File "Start-IntuneWinTool.ps1"
```

### **Loesung 3: Manuelle Richtlinien-aenderung**

```powershell
# Ausfuehrungsrichtlinie nur fuer aktuelle Sitzung setzen
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\Start-IntuneWinTool.ps1
```

### **Loesung 4: Direkte Skript-Ausfuehrung**

```powershell
# Einzelne Skripte direkt ausfuehren
powershell -ExecutionPolicy Bypass -File "German_GUI_WPF.ps1"
powershell -ExecutionPolicy Bypass -File "ENG_GUI_WPF.ps1"
```

**Hinweis:** Diese aenderungen sind **temporaer** und betreffen nur die aktuelle Sitzung. Ihre System-Sicherheitseinstellungen bleiben unveraendert.

## 📁 **Ordnerstruktur**

```text
PackingIntunewin/
│
├── Create-IntuneWinApp.ps1              # 🚀 Hauptskript (portable)
├── German_GUI_WPF.ps1                   # 🎨 Deutsche GUI
├── ENG_GUI_WPF.ps1                      # 🎨 Englische GUI  
├── Start-IntuneWinTool.ps1              # 🚀 Launcher (Sprachauswahl)
├── START-TOOL.bat                       # 🚀 Batch-Starter (einfachste Option)
├── README.md                            # 📖 Englische Dokumentation
├── README.de.md                         # 📖 Diese Dokumentation (Deutsch)
│
├── apps/                                # 📥 Input-Ordner fuer Ihre Apps
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
    │   ├── chrome-installer.intunewin  # 🎯 Fertiges Paket fuer Intune
    │   └── metadata.json               # Vollstaendige Metadaten
    │
    └── YourApp/                        # 📦 Ihre verpackte App
        ├── install.cmd                 # Automatisch generiert
        ├── uninstall.cmd              # Automatisch generiert  
        ├── yourapp.intunewin           # 🎯 Fertiges Paket fuer Intune
        └── metadata.json               # Vollstaendige Metadaten
```

## 🚀 **Schnellstart**

### **Option 1: Launcher verwenden (Empfohlen)**

```powershell
# 1. Repository klonen oder herunterladen
git clone https://github.com/ScheppertoO/PackingIntunewin.git
cd PackingIntunewin

# 2. Rechtsklick auf Start-IntuneWinTool.ps1 und "Mit PowerShell ausfuehren" waehlen
# Oder in PowerShell ausfuehren:
.\Start-IntuneWinTool.ps1

# 3. ODER: Doppelklick auf START-TOOL.bat (einfachste Option)
```

### **Option 2: Direkte Skript-Ausfuehrung**

```powershell
# 1. Repository klonen oder herunterladen
git clone https://github.com/ScheppertoO/PackingIntunewin.git
cd PackingIntunewin

# 2. Spezifisches Skript direkt ausfuehren
.\Create-IntuneWinApp.ps1     # Kommandozeilen-Version
.\German_GUI_WPF.ps1          # Deutsche GUI
.\ENG_GUI_WPF.ps1            # Englische GUI
```

### **App vorbereiten**

```powershell
# Erstellen Sie einen Ordner fuer Ihre App im 'apps' Verzeichnis
mkdir "apps\MeineApp"

# Kopieren Sie Ihre EXE-Datei hinein (genau eine EXE pro Ordner!)
copy "C:\Downloads\meine-app-installer.exe" "apps\MeineApp\"
```

### **Ausfuehren und konfigurieren**

Das Skript fuehrt Sie durch den Prozess:

- 📋 Zeigt verfuegbare Apps an
- ❓ Fragt nach App-Name und Neustart-Anforderungen
- 🔍 Ermittelt automatisch Deinstallations-Informationen
- 📦 Erstellt das fertige `.intunewin` Paket

## 🔧 **Automatische Features**

### **Tool Download-Prozess**

```text
🔧 Pruefe IntuneWinAppUtil.exe...
⚠️ IntuneWinAppUtil.exe nicht gefunden, lade von alternativen Quellen herunter...
🌐 Suche nach der neuesten Version...
📥 Gefunden: IntuneWinAppUtil.zip (Version: v1.8.6)
📋 Tool-Version: Microsoft Intune Win32 Content Prep Tool version 1.8.6.0
✅ Download erfolgreich! Dateigroeße: 0.89 MB
```

### **App-Status uebersicht**

```text
📋 Verfuegbare Apps im 'apps' Ordner:
   ✅ Chrome
   ✅ VLC
   ❌ Broken-App (Keine EXE)
   ⚠️ Multi-EXE-App (Mehrere EXE)
```

### **Intelligente Deinstallations-Erkennung**

```text
🔧 Ermittle Deinstallationsinformationen...
🔍 Suche nach Deinstallationsinformationen fuer 'Chrome'...
✅ Registry-Eintrag gefunden!
✅ Gefunden: Google Chrome
📝 Verwende QuietUninstallString: MsiExec.exe /X{GUID} /quiet
```

## 📊 **Generierte Dateien**

### **Installations-Skript (install.cmd)**

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

### **Deinstallations-Skript (uninstall.cmd)**

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

### **Metadaten-Datei (metadata.json)**

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
  "ScriptVersion": "2.0 GUI",
  "WorkingDirectory": "C:\\Pfad\\Zu\\PackingIntunewin"
}
```

## 🎯 **Microsoft Intune Konfiguration**

Nach der Erstellung erhalten Sie alle erforderlichen Informationen:

```text
📋 Informationen fuer Microsoft Intune:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
App-Name: YourApp
Install-Befehl: install.cmd
Uninstall-Befehl: uninstall.cmd
Rueckgabecodes: 0 (Erfolg), 3010 (Neustart erforderlich)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 🛠️ **Erweiterte Features**

### **Mehrstufige Deinstallations-Erkennung**

Das Skript nutzt **intelligente Erkennungsmechanismen**:

1. **Registry-Analyse** (bevorzugt)
   - Durchsucht `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`
   - Durchsucht `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*`
   - Durchsucht `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`

2. **EXE-Parameter Tests** (Fallback)
   - Testet gaengige Parameter: `/uninstall`, `/remove`, `/u`, `/x`
   - Kombiniert mit Silent-Flags: `/silent`, `/quiet`, `/s`, `/q`

3. **Standard-Fallback**
   - Verwendet `/uninstall /silent` als letzter Ausweg

### **Umfassende Fehlerbehandlung**

- ❌ **Keine EXE**: Klare Fehlermeldung wenn EXE-Datei fehlt
- ❌ **Mehrere EXEs**: Warnung bei mehr als einer EXE-Datei
- ❌ **Ordner nicht gefunden**: Hilfreiche Pfad-Anzeige
- 🌐 **Netzwerk-Fehler**: Graceful Fallback mit manuellen Anweisungen

## 💡 **Tipps & Best Practices**

### **App-Vorbereitung**

- ✅ **Eine EXE pro Ordner**: Genau eine EXE-Datei pro App-Ordner
- ✅ **Aussagekraeftige Namen**: Verwenden Sie klare Ordnernamen (z.B. "Chrome", "VLC")
- ✅ **Silent-Parameter testen**: Pruefen Sie vorab, ob Ihre EXE Silent-Installation unterstuetzt

### **Portabilitaet**

- 📁 **Kompletten Ordner kopieren**: Kopieren Sie den gesamten `PackingIntunewin` Ordner
- 🔄 **Keine Pfad-Anpassungen**: Das Skript funktioniert von jedem Speicherort
- 💾 **USB-Stick kompatibel**: Perfekt fuer mobilen Einsatz

### **Intune-Integration**

- 📝 **Erkennungsregeln**: Konfigurieren Sie Erkennungsregeln manuell in Intune
- 🔍 **Registry-Erkennung**: Nutzen Sie die Metadaten fuer Registry-basierte Erkennung
- 🔄 **Exit-Codes**: Beachten Sie die dokumentierten Rueckgabecodes

## 🆘 **Haeufige Probleme & Loesungen**

### **"IntuneWinAppUtil.exe konnte nicht heruntergeladen werden"**

- 🌐 Internetverbindung pruefen
- 🔒 Firewall/Proxy-Einstellungen pruefen
- 📥 Das Skript versucht automatisch mehrere Download-Methoden:
  - Alternative Mirror-Sites
  - GitHub Release-Archive
  - Direkte Download-URLs
- 🛠️ **Manueller Download**: Von [Microsoft Download Center](https://aka.ms/win32contentpreptool) herunterladen und als `IntunewinApps\tools\IntuneWinAppUtil.exe` speichern

### **"Keine EXE-Dateien gefunden"**

- 📁 App-Ordner unter `apps\YourApp\` pruefen
- ✅ Stellen Sie sicher, dass genau eine `.exe` Datei vorhanden ist
- 📋 Nutzen Sie die App-uebersicht zur Diagnose

### **"Deinstallation nicht gefunden"**

- 🔍 Das Skript testet automatisch verschiedene Parameter
- ✏️ Sie koennen die `uninstall.cmd` manuell anpassen
- 📖 Konsultieren Sie die Dokumentation Ihrer Software

## 🔧 **Fehlerbehebung**

Falls der Ausgabe-Ordner leer bleibt oder die .intunewin-Erstellung fehlschlaegt, befolgen Sie diese Schritte:

### **1. Automatische Diagnose verwenden**

Fuehren Sie das Diagnose-Tool aus, um haeufige Probleme zu identifizieren:

```powershell
# Zum Tool-Ordner navigieren
cd "C:\Pfad\Zu\PackingIntunewin"

# Diagnose fuer eine bestimmte App ausfuehren
powershell -ExecutionPolicy Bypass -File "Diagnose-IntuneWinTool.ps1" -AppFolderName "MeineApp"

# Oder fuer Standard-App "test"
powershell -ExecutionPolicy Bypass -File "Diagnose-IntuneWinTool.ps1"
```

Das Diagnose-Tool ueberprueft:
- ✅ Ordnerstruktur und Dateien
- ✅ IntuneWinAppUtil.exe Verfuegbarkeit und Funktionalitaet
- ✅ Berechtigungen und Administrator-Status
- ✅ Vollstaendige Simulation der Paket-Erstellung
- ✅ Detaillierte Fehleranalyse und Loesungsvorschlaege

### **2. Haeufige Ursachen und Loesungen**

| Problem | Ursache | Loesung |
|---------|---------|---------|
| **Leerer Ausgabe-Ordner** | Tool laeuft, aber erstellt keine Datei | Als Administrator ausfuehren |
| **"Tool-Ausgabe: leer"** | Stille Tool-Fehler oder Berechtigungen | Antivirus-Ausnahme hinzufuegen |
| **"EXE nicht gefunden"** | Keine .exe im apps-Ordner | .exe-Datei in den App-Ordner kopieren |
| **Tool funktioniert nicht** | IntuneWinAppUtil.exe beschaedigt | Tool neu herunterladen |
| **Zugriff verweigert** | Schreibrechte fehlen | Als Administrator oder Ordner-Berechtigungen pruefen |

### **3. Manueller Test**

Falls das GUI fehlschlaegt, testen Sie das Tool manuell:

```cmd
# Kommandozeile als Administrator oeffnen
cd /d "C:\Pfad\Zu\PackingIntunewin"

# Tool direkt aufrufen
"IntunewinApps\tools\IntuneWinAppUtil.exe" -c "apps\MeineApp" -s "install.cmd" -o "IntunewinApps\MeineApp"
```

### **4. Erweiterte Problemloesung**

- **Windows Defender**: Ordner zu Ausnahmen hinzufuegen
- **Antivirus**: Temporaer deaktivieren oder Ausnahme erstellen
- **Pfade**: Keine Sonderzeichen oder Leerzeichen in Ordnernamen
- **Dateisystem**: Lokalen Ordner statt Netzwerk-Pfad verwenden
- **UAC**: User Account Control pruefen

## 🤝 **Mitwirken**

Verbesserungsvorschlaege und Pull Requests sind willkommen!

1. Repository forken
2. Feature-Branch erstellen
3. aenderungen committen
4. Pull Request erstellen

## 📄 **Lizenz**

Dieses Projekt steht unter der MIT-Lizenz.

## 🔗 **Nuetzliche Links**

- [Microsoft Intune Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
- [Microsoft Intune Dokumentation](https://docs.microsoft.com/de-de/mem/intune/)
- [PowerShell Dokumentation](https://docs.microsoft.com/de-de/powershell/)

---

💡 **Das Tool ist vollstaendig portabel und kann ueberall verwendet werden!** 🚀

## 🤖 **KI-Unterstuetzung**

Dieses Projekt wurde mit Unterstuetzung von KI (GitHub Copilot) entwickelt, um Code-Qualitaet, Dokumentation und Benutzererfahrung zu verbessern.
