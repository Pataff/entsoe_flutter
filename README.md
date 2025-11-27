# ENTSO-E Energy Price Monitor

Applicazione Flutter per il monitoraggio e l'ottimizzazione dei costi energetici basata sui prezzi Day-Ahead della piattaforma ENTSO-E (European Network of Transmission System Operators for Electricity).

## Descrizione

L'applicazione recupera i prezzi dell'energia elettrica dalla Transparency Platform di ENTSO-E e calcola automaticamente le fasce di potenza ottimali per la gestione dei carichi energetici. I dati vengono poi inviati via TCP a sistemi di controllo esterni (es. dView) per l'ottimizzazione dinamica dei consumi.

## Funzionalità

### Monitoraggio Prezzi
- Recupero automatico dei prezzi Day-Ahead dall'API ENTSO-E
- Visualizzazione prezzi per **ieri**, **oggi** e **domani** (quando disponibili)
- Grafico multi-giorno con andamento dei prezzi
- Tabelle dettagliate con prezzi orari

### Algoritmo di Ottimizzazione
L'applicazione implementa un algoritmo di classificazione basato sulla deviazione standard:

1. **Calcolo Percentuale di Scostamento**
   ```
   %i = ((Ci - Cmin) / (Cmax - Cmin)) × 100
   ```
   Dove `Ci` è il prezzo dell'ora i, `Cmin` il prezzo minimo e `Cmax` il prezzo massimo del giorno.

2. **Calcolo Deviazione Standard (σ)**
   La deviazione standard delle percentuali definisce le soglie dinamiche.

3. **Classificazione in Fasce di Potenza**
   - **Fascia 3 (Basso costo)**: `%i < σ/2` → 100% potenza
   - **Fascia 2 (Medio costo)**: `σ/2 ≤ %i ≤ σ` → 50% potenza
   - **Fascia 1 (Alto costo)**: `%i > σ` → 20% potenza

### Comunicazione TCP
- Invio automatico comandi al server dView (protocollo MES interface)
- Formato comando: `{"impr":"all","heat":XX,"fan":XX}\n` (NDJSON)
- Intervallo di invio configurabile (30-600 secondi)
- Monitoraggio stato connessione in tempo reale

### Altre Funzionalità
- Auto-refresh configurabile (1-60 minuti)
- Supporto tema chiaro/scuro (segue impostazioni di sistema)
- Layout responsive (mobile e desktop)
- Persistenza impostazioni locali

## Prerequisiti

- Flutter SDK ^3.7.0
- Dart SDK ^3.7.0
- Security Token ENTSO-E (gratuito, richiede registrazione)

### Ottenere il Security Token ENTSO-E

1. Registrarsi su [ENTSO-E Transparency Platform](https://transparency.entsoe.eu/)
2. Accedere al proprio profilo
3. Generare un Security Token nella sezione API

## Installazione

```bash
# Clona la repository
git clone https://github.com/[username]/entsoe_flutter.git
cd entsoe_flutter

# Installa le dipendenze
flutter pub get

# Esegui l'applicazione
flutter run
```

## Configurazione

Al primo avvio, accedere alle **Impostazioni** per configurare:

| Parametro | Descrizione | Default |
|-----------|-------------|---------|
| Security Token | Token API ENTSO-E | - |
| Dominio | Codice area di mercato (es. `10IT-GRTN-----B` per Italia) | IT |
| Intervallo Refresh | Minuti tra ogni aggiornamento dati | 15 |
| IP Server TCP | Indirizzo server dView | - |
| Porta TCP | Porta server dView | 5000 |
| Invio TCP Auto | Abilita invio automatico comandi | Off |
| Intervallo TCP | Secondi tra ogni invio TCP | 60 |

### Codici Dominio ENTSO-E

| Paese | Codice |
|-------|--------|
| Italia | `10IT-GRTN-----B` |
| Germania | `10Y1001A1001A83F` |
| Francia | `10YFR-RTE------C` |
| Spagna | `10YES-REE------0` |
| Austria | `10YAT-APG------L` |

## Architettura

```
lib/
├── main.dart                 # Entry point e configurazione tema
├── models/
│   ├── app_settings.dart     # Modello impostazioni
│   ├── connection_status.dart # Stato connessioni
│   └── price_data.dart       # Modelli dati prezzi
├── providers/
│   └── app_provider.dart     # State management (Provider)
├── screens/
│   ├── dashboard_screen.dart # Schermata principale
│   └── settings_screen.dart  # Schermata impostazioni
├── services/
│   ├── entsoe_service.dart   # Client API ENTSO-E
│   ├── price_calculator.dart # Algoritmo ottimizzazione
│   ├── storage_service.dart  # Persistenza locale
│   └── tcp_service.dart      # Client TCP per dView
└── widgets/
    ├── compact_price_table.dart    # Tabella prezzi compatta
    ├── connection_status_widget.dart # Indicatore connessioni
    ├── current_hour_card.dart      # Card ora corrente
    ├── multi_day_chart.dart        # Grafico multi-giorno
    └── price_chart.dart            # Grafico prezzi singolo
```

## Dipendenze

| Package | Versione | Utilizzo |
|---------|----------|----------|
| http | ^1.2.0 | Chiamate HTTP API ENTSO-E |
| xml | ^6.5.0 | Parsing risposte XML |
| provider | ^6.1.1 | State management |
| shared_preferences | ^2.2.2 | Storage locale |
| fl_chart | ^0.68.0 | Grafici |
| intl | ^0.19.0 | Formattazione date (locale italiano) |

## Piattaforme Supportate

- Windows
- macOS
- Linux
- Android
- iOS
- Web

## Protocollo MES Interface

L'applicazione comunica con il server dView utilizzando il protocollo MES interface:

### Comando Impr (Energy Reduction)
```json
{"impr":"all","heat":XX,"fan":XX}
```
- `impr`: Identificatore comando ("all" per tutti i dispositivi)
- `heat`: Percentuale potenza riscaldamento (20, 50, 100)
- `fan`: Percentuale potenza ventilazione (20, 50, 100)

Ogni messaggio è in formato **NDJSON** (Newline Delimited JSON), terminato con `\n`.

## Screenshot

L'applicazione presenta una dashboard con:
- Card informativa dell'ora corrente con prezzo e fascia di potenza
- Grafico andamento prezzi su 3 giorni
- Tabelle dettagliate per ieri, oggi e domani
- Indicatori stato connessione ENTSO-E e TCP

## Licenza

MIT License

## Autore

Progetto sviluppato per l'ottimizzazione dinamica dei costi energetici basata sui prezzi del mercato Day-Ahead.
