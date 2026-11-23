# Guida: compilare e installare CardioPaceRun GRATIS su iPhone da Windows

Questa guida spiega come ottenere il file `.ipa` dell'app usando il cloud gratuito di **GitHub Actions** (senza avere un Mac aggiornato) e come installarlo gratis sull'iPhone del tuo amico con **Sideloadly**.

---

## Parte 1 — Compilare il file `.ipa` gratis (da Windows)

1. Crea un account gratuito su [GitHub](https://github.com) (se non ce l'hai già).
2. Crea un nuovo repository (anche **Privato** o Pubblico), es. `CardioPaceRun`.
3. Carica tutti i file di questa cartella nel repository (inclusa la cartella nascosta `.github/workflows/build-ipa.yml` e `project.yml`).
   - Se usi Git da PowerShell dentro questa cartella:
     ```powershell
     git init
     git add .
     git commit -m "Prima versione CardioPaceRun"
     git branch -M main
     git remote add origin https://github.com/TUO_UTENTE/CardioPaceRun.git
     git push -u origin main
     ```
4. Vai su GitHub nel tuo repository → scheda **Actions** → seleziona **Build iOS IPA (Unsigned)**.
5. Attendi circa 2–3 minuti che la compilazione su macOS nel cloud termini con la spunta verde ✅.
6. Apri il run completato, scorri fino a **Artifacts** e scarica **`CardioPaceRun-IPA`** (è un file `.zip` che contiene **`CardioPaceRun.ipa`**).

---

## Parte 2 — Inviare l'app al tuo amico e installarla gratis su iPhone

> **Nota iOS:** su iPhone non si può aprire un `.ipa` direttamente da WhatsApp. Devi inviare il file `CardioPaceRun.ipa` al tuo amico (via WhatsApp / Telegram / Google Drive), e lui dovrà installarlo collegando il suo iPhone al proprio PC (Windows o Mac) con **Sideloadly**.

### Passaggi sul PC del tuo amico:
1. Scarica e installa **Sideloadly** da [sideloadly.io](https://sideloadly.io/) (gratis, disponibile per Windows e macOS).
   - Su Windows serve anche iTunes (versione Apple diretta, non Microsoft Store) + iCloud se richiesto da Sideloadly.
2. Collega l'iPhone al PC con il cavo USB e tocca **"Autorizza"** sull'iPhone.
3. Apri **Sideloadly**:
   - Trascina dentro il file **`CardioPaceRun.ipa`**.
   - Inserisci il proprio **Apple ID** gratuito (viene usato da Apple per firmare l'app localmente sul suo telefono).
   - Premi **Start**.
4. Al termine, sull'iPhone comparirà l'icona **CardioPaceRun**.

### Prima apertura sull'iPhone del tuo amico:
1. Vai in **Impostazioni → Generali → VPN e gestione dispositivi** → tocca l'Apple ID e premi **Autorizza**.
2. Se richiesto su iOS 16+, attiva **Impostazioni → Privacy e sicurezza → Modalità sviluppatore** (riavvia l'iPhone).
3. Apri **CardioPaceRun** e concedi i permessi:
   - **Bluetooth**: Consenti (per la fascia **iGPSPORT HR50**).
   - **Posizione**: scegli **Sempre** (necessario per tracciare GPS e avvisi vocali anche a **schermo bloccato**).

---

## Nota sul rinnovo ogni 7 giorni (account gratuito)
Con un Apple ID gratuito, le app installate via Sideloadly durano **7 giorni**: poi basta aprire Sideloadly (anche via Wi-Fi se si attiva l'opzione di auto-refresh in Sideloadly) per rinnovare l'app senza perdere le corse salvate.

## Uso con la fascia iGPSPORT HR50
1. Inumidisci leggermente gli elettrodi sul retro della fascia e indossala sul petto (la HR50 si accende automaticamente quando rileva il battito).
2. In **CardioPaceRun**, tocca la barra in alto **Fascia non collegata** → seleziona **HR50 / iGPSPORT**.
3. Vai in **Impostazioni** per inserire età / FC max e scegliere **Corsa leggera**, **Aerobica**, **Soglia** oppure l'intervallo **Manuale**.
4. Collega le cuffie, premi **Avvia corsa** e blocca pure lo schermo: la voce in italiano ti guiderà in tempo reale e ad ogni chilometro.
