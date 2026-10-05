# Ověření fáze 0

Datum: 5. října 2026. Prostředí: Apple Silicon, macOS 27.0.1, Xcode 27.0, Swift 6.4.

## Automatické kontroly

- Debug i Release sestavení prošlo.
- `swift test` prošlo: 13 testů, z toho validace vstupu má 8 parametrizovaných případů.
- Ověření lokálního podpisu `.app` prošlo.
- Kontrola `Info.plist` prošla.
- Binární soubor byl ověřen jako Mach-O `arm64`.
- Aplikace vyexportovala 20 PNG náhledů, deset obrazovek/stavů v každém barevném režimu.

Testy pokrývají potvrzení plánu, upravený počet, vrácení potvrzení, neplatné vstupy, hranice plus/minus, dokončení sady, ochranu před opakovaným potvrzením, oba způsoby přeskočení, zachování otevřené sady při změně nastavení, pauzu/pokračování v lokálním stavu, úpravy seznamu cviků, prázdnou sadu a přepnutí všech ukázkových stavů. Test nové instance ověřuje návrat k ukázkovým datům, nikoli ukládání nebo obnovu skutečné aplikace.

## Ověření spuštěného rozhraní

Ovládání proběhlo ve skutečně spuštěné aplikaci pomocí macOS accessibility a klávesnice.

| Scénář | Výsledek |
| --- | --- |
| Spuštění `.app` a okno Prototype controls | Prošlo |
| Otevření panelu zkratkou ⌘1 | Prošlo |
| Zahájení přestávky klávesou Enter | Prošlo |
| Done pro výchozích 10 opakování | Zobrazeno 10 zaznamenaných opakování |
| Přímý zápis 8 a potvrzení Enter | Zobrazeno 8 zaznamenaných opakování |
| Undo, oprava počtu a nové potvrzení | Prošlo |
| Zápis `abc` | Done zakázáno a zobrazena instrukce |
| Plus a minus | Viditelná hodnota se správně změnila |
| Zavření a opětovné otevření panelu | Zachováno 2 ze 3 potvrzení |
| Poslední Done | Zobrazeno potvrzení dokončení a 60:00 |
| Pause / Resume přes ⌘P | Prošlo |
| Změna intervalu na 45 minut | Zobrazen nový statický odpočet 45:00 |
| Přidání, přejmenování, úprava počtu, přesun a odstranění cviku | Prošlo |
| Přepnutí notifikací | Přepínač změnil lokální stav bez požadavku na oprávnění |
| Přeskočení celé sady přes ⌘⇧S | Skipped a nový interval |
| Přeskočení s jedním potvrzením | Partially completed, zachován počet 10, ostatní Skipped |
| Historie přes ⌘⇧H a výběr šipkami | Prošlo |
| Detail historie | Zobrazen plán, skutečný počet a přeskočené cviky |
| Nastavení přes ⌘, | Prošlo |
| Tab v poli opakování | Ověřen standardní přesun fokusu mezi poli |
| ⌘W, ⌘0 a ⌘Q | Zavření, znovuotevření ovládání a ukončení prošlo |
| Finální sestavení, stav In progress a přepnutí Dark / System | Prošlo; ověřeny aktivní ovládací prvky a obnova ukázkových dat |

## Omezení ověření

Automatické ovládání nezpřístupnilo samotnou ikonu v systémové liště. Pokusy o čtení systémové lišty skončily časovým limitem. Kliknutí na ikonu a chování ukotveného menu bar panelu proto nejsou označeny za otestované. Obsah panelu používá stejný `BreakPanelView` jako plně proklikané okno Panel preview. Menu bar je implementován standardním SwiftUI `MenuBarExtra` se stylem `.window`.

Náhledy obou režimů byly kontrolovány vizuálně. Starší macOS, Intel, VoiceOver a všechny kombinace systémového nastavení ovládání klávesnicí nebyly ověřeny.

Plánování připomenutí, skutečný běh časovače, systémové notifikace, diskové ukládání, restart s obnovou, uspání/probuzení a změna systémového času do fáze 0 nepatří a nebyly implementovány ani testovány.

Funkční fáze vyžaduje nové zadání po posouzení prototypu.
