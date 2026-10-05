# StretchBreak, UI prototyp pro macOS

Fáze 0 podle [zadání](Resources/Brief.txt). Nativní SwiftUI aplikace s anglickým rozhraním, ukázkovou historií a stavem pouze v paměti. Fáze funkční implementace zatím nezačala.

## Spuštění

Otevřete `dist/StretchBreak.app`. První okno je **Prototype controls**. Produkční návrh rozhraní najdete pod ikonou stojící postavy v systémové liště. **Open panel preview** zobrazí stejný panel v běžném okně.

V ovládání prototypu zvolte ukázkový stav a přepněte **System / Light / Dark**. Změna stavu obnoví ukázkové cviky a historii. **Reset samples** obnoví i přepínač notifikací. Po opětovném spuštění se všechna data vrátí na ukázkové hodnoty.

Odpočet je statický. Přepínač notifikací pouze mění vzhled nastavení. Aplikace neplánuje připomenutí, nežádá oprávnění k notifikacím a neukládá nastavení ani výsledky na disk. Snímky obrazovek zapisuje pouze explicitní vývojový příkaz pro export náhledů.

## Ovládání

- **Start break** nebo Enter při odpočtu zahájí sadu cviků.
- **Done** zaznamená zobrazený počet. Lze jej změnit zápisem nebo pomocí plus/minus. Enter v poli cviku počet potvrdí.
- **Undo** vrátí potvrzení, dokud je sada otevřená.
- Poslední potvrzení zobrazí výsledek a nový plný statický interval.
- **Skip & restart** zachová potvrzené cviky a ostatní označí jako přeskočené.
- Zavření panelu zachová otevřenou sadu v paměti aplikace.
- Nastavení se uplatní na další sadu. Přesun cviků umožňují tlačítka se šipkami.
- Historie ukazuje plánované a zaznamenané počty vedle sebe. Výběr záznamu lze měnit šipkami nahoru/dolů.

| Zkratka | Akce |
| --- | --- |
| ⌘0 | Prototype controls |
| ⌘1 | Panel preview |
| ⌘, | Nastavení |
| ⌘⇧H | Historie |
| ⌘P | Pause / Resume při odpočtu |
| ⌘⇧S | Skip & restart v otevřené sadě |
| ⌘W | Zavřít aktuální okno |
| ⌘Q | Ukončit aplikaci |

Tab přechází mezi poli. Zapojení standardních tlačítek do tabulátorového pořadí se řídí nastavením ovládání klávesnicí v macOS.

## Náhledy

[Galerie všech 20 náhledů](Previews/index.html) obsahuje odpočet, pauzu, připravenou přestávku, rozpracovanou sadu, dokončení, oba způsoby přeskočení, nastavení, historii a ovládání prototypu ve světlém a tmavém režimu. Jde o snímky skutečných SwiftUI obrazovek včetně systémových prvků, bez rámu okna. Vývojový export zachycuje vzhled neaktivního okna, proto jsou některá tlačítka šedá. V aktivním panelu mají primární tlačítka systémovou akcentní barvu.

| Obrazovka | Světlý režim | Tmavý režim |
| --- | --- | --- |
| Odpočet | [PNG](Previews/countdown-light.png) | [PNG](Previews/countdown-dark.png) |
| Přestávka | [PNG](Previews/break-light.png) | [PNG](Previews/break-dark.png) |
| Nastavení | [PNG](Previews/settings-light.png) | [PNG](Previews/settings-dark.png) |
| Historie | [PNG](Previews/history-light.png) | [PNG](Previews/history-dark.png) |

## Sestavení a testy

Projekt je Swift Package bez externích závislostí. V Xcode otevřete `Package.swift`, nebo ve složce projektu spusťte:

```sh
./Scripts/build-app.sh
swift test --cache-path .build/cache
./Scripts/export-previews.sh
```

Sestavovací skript vytvoří `.app`, ikonu a lokální podpis. Export náhledů spustí samostatnou instanci aplikace, vyrenderuje obrazovky a ukončí ji.

Ověřeno na Apple Silicon s macOS 27.0.1 a Xcode 27.0, Swift 6.4. Výstup obsahuje pouze `arm64`. Intel nebyl sestaven ani testován. Deklarovaná minimální verze je macOS 14, na starších verzích macOS než 27 tento výstup nebyl spuštěn. Podpis je lokální, aplikace není notarizovaná.

Podrobné výsledky a omezení jsou v [záznamu ověření](Docs/Verification.md).

## Návrhová rozhodnutí k posouzení

- Panel má šířku 380 bodů. Každý cvik ukazuje plán a vstup společně, aby výchozí počet šel potvrdit jediným kliknutím. Stojí za posouzení, zda tato hustota vyhovuje při práci v menu baru.
- Po uzavření sady zůstává nad novým odpočtem krátké potvrzení do zahájení další sady. Případné automatické skrytí potvrzení je rozhodnutí pro další fázi.
- Pořadí cviků mění tlačítka nahoru/dolů. Přetažení může být doplněno až po posouzení tohoto jednoduššího ovládání.

Zdrojový kód je na větvi `codex/ui-prototype`. Stav prototypu je oddělený v `PrototypeCore`; rozhraní a vývojový export jsou v `StretchBreakPrototype`. Tento model slouží pro posouzení interakcí a není implementací budoucího časovače nebo ukládání.
