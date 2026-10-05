# StretchBreak

Nativní aplikace pro macOS s anglickým rozhraním. Běží v menu baru, připomíná přestávky, zaznamenává skutečné počty opakování a uchovává historii lokálně. Podporuje Apple Silicon a macOS 14 nebo novější.

## Spuštění a přenos na další Mac

1. Přenes `dist/StretchBreak-1.0.0-arm64.zip` na druhý Mac a rozbal jej.
2. Přesuň `StretchBreak.app` do Applications a otevři ji. Xcode ani další knihovny nejsou potřeba.
3. Panel otevřeš ikonou postavy v menu baru. Když je přestávka připravená, ikona se změní na vykřičník.

Balíček má lokální podpis, ale není podepsán certifikátem Developer ID ani notarizován. V tomto prostředí není dostupná žádná podpisová identita. Pokud macOS první spuštění zablokuje, pro tuto vlastní aplikaci lze po pokusu o otevření použít System Settings → Privacy & Security → Open Anyway. Postup popisuje [Apple Support](https://support.apple.com/en-us/102445). Spravovaný Mac může tento postup omezit.

## Ovládání

Výchozí interval je 60 minut. `Start break` zahájí přestávku ihned. U cviku lze zadat počet, použít plus/minus nebo rovnou stisknout `Done` pro plánovaný počet. Povolené hodnoty jsou celá čísla 1 až 999. `Undo` vrátí potvrzení, dokud je přestávka otevřená. Poslední potvrzení dokončí přestávku a zahájí nový interval.

Zavření panelu zachová rozpracovanou přestávku. `Skip & restart` zaznamená potvrzené cviky, ostatní označí jako přeskočené a spustí nový interval. Pauza zachová zbývající čas i po restartu.

V Settings lze změnit interval 1 až 240 minut, systémové notifikace a seznam cviků. Změny uloží `Save changes`. Změna intervalu restartuje odpočet, při pauze zachová pauzu. U otevřené přestávky se nový interval a nová sada cviků použijí až po jejím uzavření. Historie zachovává původní názvy, plány a zaznamenané výsledky.

| Klávesy | Akce |
| --- | --- |
| ⌘1 | Otevřít panel, když je aplikace aktivní |
| Enter | Zahájit přestávku nebo potvrdit platné pole opakování |
| ⌘P | Pause / Resume v panelu |
| ⌘⇧S | Skip & restart v panelu |
| ⌘, | Settings |
| ⌘S | Uložit Settings |
| ⌘⇧H | History |
| Escape | Zavřít panel |
| ⌘W | Zavřít samostatné okno |
| ⌘Q | Ukončit aplikaci |

Časovač vychází z uloženého termínu. Čas strávený uspáním Macu nebo vypnutou aplikací se započítává. Po návratu vznikne nejvýše jedna aktuální přestávka. Připomenutí samo neotevírá panel. Notifikace závisejí na oprávnění macOS; jejich odmítnutí neblokuje ostatní funkce. Aplikace se sama nepřidává do položek po přihlášení.

## Data

Vše se ukládá do `~/Library/Application Support/StretchBreak/StretchBreak.sqlite`. Databáze obsahuje nastavení, uložený termín nebo pauzu, rozpracovanou přestávku včetně vstupů a historii. Aplikace nevyžaduje účet ani internet a data nesynchronizuje.

Data jsou oddělená od `.app`. Aktualizace aplikace je zachová. Pro přenos dat ukonči aplikaci na obou Macích, zálohuj případná data v cíli a zkopíruj celou složku `StretchBreak` do stejného umístění. Složku najdeš i přes About StretchBreak → Show data in Finder. Přenesení samotné `.app` vytvoří na druhém Macu nové místní údaje.

Zápis změny stavu a případného záznamu historie proběhne v jedné SQLite transakci. Rozhraní potvrdí úspěch až po zápisu. Při chybě zachová dosavadní uložený stav, zablokuje další změny a nabídne `Retry saving`. Při ukončení upozorní na neuloženou změnu. Neplatnou databázi nepřepíše novými údaji.

## Zdrojový projekt a sestavení

Zdrojový projekt je v tomto adresáři a v `dist/StretchBreak-1.0.0-source.zip`. Potřebuje Swift 6 a macOS SDK. Závisí pouze na systémových knihovnách.

```sh
swift test --cache-path .build/cache
./Scripts/build-app.sh
./Scripts/package-app.sh
./Scripts/verify-package.sh
```

Sestavení vytvoří `dist/Release/StretchBreak.app`. Balicí skript vytvoří ZIP pro přenos, zdrojový ZIP a kontrolní součty SHA-256. Sestavuje pouze `arm64`.

## GitHub Releases

Odeslání nového tagu, například `v1.0.0`, spustí testy, sestavení a kontrolu balíčků. Po úspěchu workflow zveřejní GitHub release s aplikací pro Apple Silicon, zdrojovým archivem a kontrolními součty. Verze aplikace a názvy souborů vycházejí z tagu. Postup nastavení, vydání a místního ověření popisuje [Docs/Releasing.md](Docs/Releasing.md).

## Struktura aplikace

`StretchBreakCore` obsahuje pravidla přestávek, model, zdroj času a SQLite úložiště. `StretchBreakMac` zajišťuje systémové notifikace. `StretchBreak` obsahuje SwiftUI rozhraní a integraci menu baru, panelu, oken a probuzení přes AppKit. Čas, úložiště a doručování připomenutí lze v testech nahradit.

## Ověření

Prošlo 31 automatických testů. Testy zahrnují řízený čas, skutečné SQLite transakce a chyby zápisu, obnovu po restartu i integraci notifikací s nahraditelným systémovým klientem. Hlavní kroky byly ověřeny ve skutečně spuštěné aplikaci, včetně skutečného ukotveného panelu a obnovy po ukončení procesu.

Podrobnosti a omezení jsou v [Docs/Verification.md](Docs/Verification.md). Ověřeno na Apple Silicon s macOS 27.0.1, Xcode 27.0 a Swift 6.4. Jiný fyzický Mac a starší podporované macOS nebyly dostupné. Na tomto Macu jsou systémové notifikace zamítnuté, proto doručení banneru a kliknutí na skutečný banner nejsou označené za ověřené.

Pro opakování UI testů spusť `./Scripts/build-ui-test-app.sh` a otevři `dist/UITests/StretchBreak UI Tests.app`. Kopie používá vlastní databázi `.build/ui-test-data`, ovladatelný čas a neodesílá systémové notifikace. Tlačítko `Open menu bar panel` otevře skutečný produkční popover. Tento vývojový balíček není součástí ZIPu pro přenos. [UI scénáře](Docs/UITests.md) uvádějí kroky a očekávané výsledky.

Původní prototyp je zachován na větvi `codex/ui-prototype`. Náhledy v `Previews` patří k této schválené fázi 0; neprokazují funkčnost současné aplikace.
