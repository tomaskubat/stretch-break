# UI scénáře funkční verze

Scénáře níže byly provedeny v nativní aplikaci přes macOS accessibility a klávesnici. Nejde o XCTest UI suite. Opakovat je lze ručně nebo nástrojem pro ovládání nativních aplikací. Automatické testy pravidel, SQLite a notifikačního adaptéru spouští `swift test`.

## Příprava

Spusť `./Scripts/build-ui-test-app.sh` a otevři `dist/UITests/StretchBreak UI Tests.app`. Tato kopie používá `.build/ui-test-data/StretchBreak.sqlite` a vlastní bundle ID. Změny nijak neupravují produkční databázi. `Open menu bar panel` volá stejnou metodu jako ikona a otevře skutečný NSPopover ukotvený v menu baru. Posun času je dostupný pouze ve vývojové kopii. Systémové notifikace jsou v této kopii vypnuté.

Pokud opakuješ scénář se starými testovacími daty, počítej s jejich obnovením. Pro nový začátek nejdřív ukonči testovací aplikaci a přejmenuj `.build/ui-test-data` na zálohu.

## Scénáře a očekávané výsledky

1. Otevři panel. Odpočet průběžně klesá. Pause jej zastaví. Zavři panel, posuň čas o 10 minut, ukonči a znovu spusť aplikaci. Resume pokračuje ze stejného zbývajícího času.
2. Enter zahájí přestávku. První Done zaznamená výchozí plán 10. Ve druhém poli zadej 8 a potvrď Enter. Zobrazí se 8 zaznamenaných opakování. Undo vrátí potvrzení, plus změní 8 na 9, minus na 8 a nové Done uloží opravený počet.
3. Ve třetím poli zadej `abc` a stiskni Enter. Done je zakázané, přestávka zůstává otevřená. Zavři panel i aplikaci. Po znovuotevření zůstanou dvě potvrzení i neplatný rozpracovaný vstup zachované.
4. Oprav třetí pole na 15 a potvrď Enter. Přestávka se automaticky dokončí a odpočet začne od plného intervalu. History ukáže Completed, plánované počty 10/12/15 a skutečné 10/8/15.
5. V Settings zadej interval 0. Save changes je zakázané. Oprav jej na 45. Přidej Desk squats, nastav 9 opakování, přesuň cvik nahoru, odstraň Calf raises a ulož ⌘S. Odpočet se restartuje na 45 minut. Nová přestávka použije upravenou sadu; dřívější historie zůstane beze změny.
6. Zavři panel a použij Advance to next break. Panel se samočinně neotevře. Advance 10 minutes nevytvoří další přestávku. Ručně otevřený panel ukáže jednu sadu připravených cviků.
7. ⌘⇧S přeskočí celou sadu bez dialogu. History obsahuje Skipped, všechny skutečné počty chybí. Další přestávku zahaj Enter, potvrď jeden cvik a znovu použij ⌘⇧S. History ukáže Partially completed, potvrzený počet zachová, zbývající cviky jsou Skipped.
8. Přepni Light appearance a Dark appearance. Prohlédni panel, Settings a History. Změna se týká pouze testovací aplikace.
9. Ověř ⌘1, ⌘P, ⌘,, ⌘S, ⌘⇧H, ⌘⇧S, Escape, ⌘W a ⌘Q. Tab přesouvá fokus standardně mezi poli.

## Skutečná chyba zápisu

V oddělené testovací databázi byl vytvořen SQLite trigger, který odmítá UPDATE app_state:

```sh
sqlite3 .build/ui-test-data/StretchBreak.sqlite "CREATE TRIGGER ui_fail_update BEFORE UPDATE ON app_state BEGIN SELECT RAISE(ABORT, 'UI test: simulated write failure'); END;"
```

Při potvrzení posledního cviku panel zobrazil chybu a Retry saving. Další potvrzování i Skip byly zakázané. Dva předchozí výsledky zůstaly v databázi a žádný předčasný záznam historie nevznikl. ⌘Q zobrazilo upozornění na neuloženou změnu. Po odstranění triggeru a Retry saving vznikl právě jeden dokončený záznam.

```sh
sqlite3 .build/ui-test-data/StretchBreak.sqlite 'DROP TRIGGER ui_fail_update;'
```

Tyto příkazy jsou určeny pouze pro izolovanou testovací databázi.
