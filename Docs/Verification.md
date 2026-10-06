# Ověření funkční aplikace 1.0.0

Datum: 5. října 2026. Prostředí: Apple Silicon, macOS 27.0.1, Xcode 27.0, Swift 6.4. Zadání je v Resources/Brief.txt, funkční požadavky začínají za dokončenou fází 0.

## Automatické testy

`swift test --cache-path .build/cache` prošlo. Celkem 31 testovacích funkcí ve třech sadách. Validace neplatných opakování má navíc 10 parametrizovaných případů a hranice počtů dva případy.

| Požadavky | Důkaz |
| --- | --- |
| První odpočet 60 minut a perzistence termínu | firstLaunchStartsAndPersistsFullInterval |
| Právě jedna přestávka a jedno připomenutí, i po mnoha intervalech | expiryCreatesExactlyOneBreakAndReminder, expirySaveFailureCannotDeliverAnUncommittedReminder |
| Předčasné zahájení bez systémové notifikace | manualStartDoesNotSendReminderAndRetainsExerciseSnapshot |
| Dokončení, přeskočení, částečné dokončení a nový interval od uzavření | completionRecordsEditedCountAndRestartsFromClosingMoment, skippedAndPartialOutcomesPreserveRecordedResults |
| Výchozí a upravený počet, neplatné hodnoty, 1/999, Undo a plus/minus | invalidRepetitionsCannotBeConfirmed, repetitionBoundariesAreAccepted, undoAndPlusMinusAllowCorrectionWithinBounds |
| Ochrana před dvojím potvrzením | duplicateConfirmationCannotCreateDuplicateResult |
| Pauza a pokračování, změny intervalu při pauze a odpočtu | pausePreservesRemainingTimeAcrossSleepAndRestart, intervalChangesRestartFullCountdownAndKeepPause |
| Úpravy cviků a intervalu platí od další sady, historie se nemění | settingsDuringOpenBreakApplyToNextBreakOnly, invalidSettingsAreRejectedWithoutChangingSavedState |
| Změny času zpět i vpřed, žádné duplicity nebo prodloužení nad plný interval | backwardAndForwardClockChangesNeverDuplicateBreaks |
| SQLite obnoví nastavení, historii, potvrzení a rozpracovaný vstup | roundTripRestoresSettingsHistoryAndUnfinishedBreak |
| Restart před a po termínu, započtení času vypnutí nebo simulovaného uspání | restartBeforeAndAfterDeadlineUsesPersistedWallClockDeadline, pausedStateAndNewIntervalSurviveReopening |
| Transakce historie a stavu je atomická i při selhání INSERT | failedHistoryInsertRollsBackStateInTheSameTransaction |
| Chyba skutečného SQLite UPDATE, zachování výsledků a Retry | actualSQLiteWriteFailureKeepsConfirmedResults, confirmationFailureKeepsCommittedResultsAndCanBeRetried |
| Chyba ukládání vyvolá aktualizaci rozhraní | savingFailureUpdatesObservedUIState |
| Chyba načtení či poškozené údaje nepřepíší databázi | corruptPayloadIsReportedAndNeverReplaced, loadFailureNeverResetsSavedData |
| Zamítnuté a vypnuté notifikace neblokují přestávku | deniedOrDisabledNotificationsDoNotBlockTheBreak |
| Notifikační adaptér doručuje bez otevření panelu, kliknutí volá otevření | authorizedDeliveryAndClick |
| Oprávnění se vyžádá pouze při zapnutí a výslovném požadavku | deniedPermissionDoesNotDeliverOrRequestAgain, permissionRequestedOnlyWhenEnabledAndExplicit |
| Zrušení během kontroly oprávnění i během systémového zápisu | cancellationWhileCheckingPermissionPreventsDelivery, cancellationWhileAddingRemovesLateNotification |
| Chyby systémového klienta notifikací | deliveryAndAuthorizationErrorsAreReported |

Časové scénáře používají ovladatelný zdroj času. SQLite scénáře používají skutečné dočasné databáze, unikátní identifikátory a řízené chyby. Notifikační adaptér používá nahraditelný klient, takže testy nevyžadují systémové oprávnění ani skutečný banner.

## Spuštěná aplikace

UI scénáře byly provedeny v Release aplikaci přes macOS accessibility a klávesnici. Testovací kopie má stejný binární soubor jako produkční aplikace, oddělené bundle ID, vlastní databázi a ovladatelný čas. Detailní postup je v UITests.md.

| Scénář | Výsledek |
| --- | --- |
| Otevření skutečného menu bar popoveru | Prošlo, potvrzeno AX rolí popover a screenshotem ukotveného panelu |
| Běžící odpočet, Pause, posun času a restart procesu | Prošlo, pauza obnovila 59:40 |
| Resume a Enter pro zahájení | Prošlo |
| Done pro plán 10; úprava druhého počtu na 8 a Enter | Prošlo |
| Undo, plus, minus a nové potvrzení | Prošlo |
| Neplatný vstup abc a Enter | Done zakázané, potvrzení nevzniklo |
| Zavření panelu a skutečný restart aplikace | Zachováno 2 ze 3 potvrzení a vstup abc |
| Poslední potvrzení | Automatické dokončení, nový plný interval, historie 10/8/15 |
| Settings, interval 0/45, přidání, pojmenování, počet, pořadí a odstranění cviku | Prošlo, výsledek uložen přes ⌘S a použit v další přestávce |
| Vypršení řízeného intervalu a další posun času | Jedna přestávka; testovací okno zůstalo aktivní, panel se neotevřel |
| Přeskočení celé sady a rozpracované sady | Skipped a Partially completed, potvrzené počty zachovány |
| History, starší i aktuální záznam a původní názvy cviků | Prošlo, pořadí odpovídá vložení i po posunu času zpět |
| Skutečná chyba SQLite při posledním potvrzení | Viditelný banner, dva dříve uložené výsledky zachovány, historie nezměněna |
| Retry po odstranění chyby; ochrana při Quit | Prošlo, jeden dokončený záznam, neuložená změna vyvolala dialog |
| Light a Dark pro panel, Settings a History | Vizuálně ověřeno; opraveno dědění vzhledu popoveru |
| Klávesové zkratky a samostatná okna | Enter, ⌘1, ⌘P, ⌘,, ⌘S, ⌘⇧H, ⌘⇧S, Escape, ⌘W a ⌘Q prošly |
| Produkční .app se skutečným Application Support úložištěm | Spuštěno, živý odpočet a změny nastavení fungují |
| Produkční interval 1 minuta při zamítnutých notifikacích | Přestávka vznikla, Settings zachovalo fokus v poli, panel se sám neotevřel |
| Aplikace spuštěná z rozbaleného přenosného ZIPu | Otevřela skutečný panel, obnovila současnou přestávku a zobrazila prázdnou historii; ukončení prošlo |

Po produkčním testu byl interval vrácen na 60 minut. V produkční databázi nejsou falešné potvrzené výsledky ani historie. ZIP neobsahuje databázi ani testovací nastavení.

## Balíček

Release sestavení, kontrola Info.plist a lokálního podpisu prošly. Binární soubor je Mach-O arm64, minimální cílová verze macOS je 14.0. Dynamické závislosti jsou pouze v /System/Library a /usr/lib; aplikace neodkazuje na adresář projektu nebo Swift toolchain. Balíček nevyžaduje Xcode.

Spustitelná aplikace je v dist/Release/StretchBreak.app. Přenosný ZIP, zdrojový ZIP a SHA-256 součty vytváří Scripts/package-app.sh. Scripts/verify-package.sh prošlo: ověřuje podpis rozbalené aplikace, arm64, shodu binárního souboru, systémové závislosti, nepřítomnost vývojových vyhledávacích cest, databáze a testovacího klíče v Info.plist. Porovnává všechny soubory zdrojového ZIPu s projektem a ověřuje SHA-256 obou archivů. Rozbalená aplikace byla následně spuštěna přes macOS.

## Omezení ověření

Na tomto Macu systém vrací pro StretchBreak zamítnuté oprávnění k notifikacím. Skutečný systémový banner a kliknutí na něj proto nebyly ověřeny. Je ověřeno neblokující chování při zamítnutí; autorizované doručení, klikací callback a souběhy rušení pokrývají testy adaptéru.

Automatické ovládání nezpřístupnilo samostatnou ikonu v systémové liště. Přímé fyzické kliknutí na tuto ikonu není označeno za otestované. Skutečný NSPopover, jeho otevření přes stejnou metodu jako obsluha ikony, zavření a obsah byly otestovány. Integrace ikony a její selector jsou v AppRuntime.

Uspání/probuzení a změny systémového času byly ověřeny s ovladatelným časem a reálnou databází. Fyzické uspání počítače, změna jeho systémových hodin a psaní v jiné aplikaci během vypršení nebyly automatizovány. Produkční běh potvrdil, že při vypršení nedochází k otevření panelu ani změně fokusu v Settings; metoda doručení připomenutí nevolá aktivaci aplikace.

Druhý fyzický Mac, macOS 14 až 26, Intel, VoiceOver, režimy Focus a všechny kombinace nastavení klávesnice nebyly ověřeny. Intel není součástí sestavení. Podpis je ad hoc, nikoli Developer ID, aplikace není notarizovaná. Přenos na druhý Mac může vyžadovat uživatelské povolení prvního spuštění dle postupu Apple v Install.md.

## Příprava GitHub Releases

Dne 5. října 2026 po přidání workflow znovu prošlo všech 31 testovacích funkcí. `actionlint` 1.7.12 ověřil `.github/workflows/release.yml`. Validace verze přijala pět platných vstupů a odmítla třináct neplatných, včetně suffixu, počátečních nul a nadbytečného argumentu.

Místní sestavení, balení a rozbalení zkušební verze `v1.2.3` prošlo. Tag se promítl do obou verzí v Info.plist, názvů archivů a instalačního návodu; zdrojová šablona zůstala na 1.0.0. Kontrola podpisu, arm64, závislostí, shody zdrojů včetně workflow a SHA-256 prošla. Balení jako `v1.2.4` správně odmítlo sestavenou aplikaci 1.2.3.

Publikační krok byl spuštěn místně s náhradou GitHub CLI, která pouze zaznamenala argumenty. Ověřeny byly přesně tři assety, existující soubory, tag, titul, poznámky a volby `--verify-tag` a `--generate-notes`. Žádný release se při tomto ověření nezveřejnil. Skutečný běh na GitHubu a Xcode 26.6 zatím nejsou ověřené; repo při přípravě nemá nastavený GitHub remote.

## Sparkle updates, 2026-10-05

Sparkle 2.10.0 is pinned in `Package.swift` and `Package.resolved`. All 34 existing automated tests passed after integration. The local 1.0.2 release build, portable ZIP, source ZIP, app-only update ZIP, appcast metadata, Ed25519 signature, bundled license, nested ad hoc signatures, and checksums passed verification.

A separate copy of the application was compiled with the production updater and interface. Its UI-test guard was changed only in the temporary test sources to enable the updater. The test bundles used a separate bundle identifier, their own SQLite database, and a feed served over localhost. Neither the normal database nor the published GitHub releases were changed.

Verified in the running test application:

- Manual checks from Settings and the panel menu found a signed 1.0.2 update from a 1.0.1 installation.
- Download, verification, installation, and relaunch completed with ad hoc signatures.
- A changed interval, renamed exercise, completed break in history, and paused countdown survived the update. All rows of the SQLite database matched the snapshot taken before installation.
- An archive offered with an invalid Ed25519 signature was rejected before extraction. The installed version was unchanged.
- Automatic checks and downloads remained enabled after quitting and reopening when using the same standard preferences storage as the distribution app.
- On relaunch, the app checked and downloaded a signed 1.0.3 update in the background. Quitting installed it automatically, with the SQLite rows again unchanged.
- Update settings fit within the existing Settings scroll view.

`Scripts/test-update-verification.py` also exercises the release verifier with a changed version, download URL, archive length, and signature. It requires each alteration to fail for the expected reason, restores the original feed, and verifies it again. The release workflow runs these checks before publishing.

The actual GitHub-hosted download and GitHub Actions runner require the next published release for full production verification. This change does not publish a release. First installation and behavior on other physical Macs retain the limitations described above.

## Průběžné CI a kontrola publikovaných souborů

Dne 5. října 2026 prošly kontroly konfigurace pomocí `Scripts/check-config.sh`, včetně stažení actionlint 1.7.12, ověření připnutého SHA-256, kontroly obou workflow, syntaxe shellových skriptů a Info.plist. Prošlo všech 34 automatických testů, release sestavení 1.1.0 a ověření všech tří distribučních archivů. Místní ověření používalo Xcode 27.0; workflow zachovávají Xcode 26.6 na `macos-26`.

Nová kontrola publikování stáhla soubory skutečného GitHub releasu 1.1.0 a feed přes produkční adresu `latest/download/appcast.xml`. Prošly kontrolní součty, verze a platforma feedu, Ed25519 podpis update ZIPu, podpisy rozbalené aplikace a shoda jejího Info.plist s očekávanou aplikací. Porovnání publikovaného manifestu používá manifest původního releasu, nikoli nově sestavených archivů s nepublikovanými změnami.

Oddělené místní scénáře se skutečně podepsaným update ZIPem ověřily platný průchod a odmítnutí poškozeného archivu, nahrazeného manifestu, neplatného podpisu, pozměněného archivu s přepočítanými kontrolními součty, jiné verze v latest feedu a neočekávaného názvu souboru v manifestu. Všech šest chybných scénářů skončilo před rozbalením archivu. Znovu prošly také čtyři stávající testy změněné verze, URL, délky a podpisu pro výchozí cestu ověřovacího skriptu.

Commit `e4afe3e` prošel také [skutečným během CI na GitHubu](https://github.com/tomaskubat/stretch-break/actions/runs/37362259483). Runner použil Xcode 26.6 a Swift 6.3.3; prošly kontroly konfigurace, všech 34 testů ve čtyřech sadách, release sestavení a ověření distribučních archivů. Workflow se spustilo událostí `push` do `main`.

Ochrana `main` vyžaduje kontrolu `Tests and distribution` od GitHub Actions a aktuální větev před sloučením. Nastavení bylo následně přečtené z GitHub API a potvrzené. Pravidlo se nevynucuje pro správce repozitáře.

## Oprava smyčky ikony a vysokého CPU, 2026-10-05

`AppRuntime` si nyní před přiřazením obrázku pamatuje rozlišení světlého nebo tmavého vzhledu použitého pro ikonu. Observer tlačítka aktualizuje ikonu pouze při změně tohoto rozlišení. Časovač a změny aplikačního stavu stále volají celou aktualizaci obrázku, tooltipu a accessibility labelu. Obrázek i uložené rozlišení používají tentýž zachycený `NSAppearance`.

Nová sada `Tests/StretchBreakAppTests/StatusItemTests.swift` spouští skutečný `AppRuntime` se skutečným `NSStatusBarButton`, vlastní dočasnou SQLite databází a náhradou systémových notifikací. Regresní test přehrává oznámení nezměněného `effectiveAppearance` po přiřazení obrázku. Přehrávání má horní mez, aby chybná verze nemohla zablokovat testy. Před opravou deset výchozích oznámení vyvolalo 109 přiřazení obrázku a test selhal. Po opravě test prošel s limitem dvou přiřazení, který dovoluje případný tick časovače.

Další integrační testy ověřují změnu skutečného obrázku tlačítka při přepnutí `.aqua` na `.darkAqua` a zpět, aktualizaci odpočtu časovačem, Pause a Resume, vznik a přeskočení přestávky a chybovou ikonu po skutečném odmítnutí SQLite UPDATE. `swift test --cache-path .build/cache` prošlo se všemi 37 testovacími funkcemi v pěti sadách. Release sestavení pro arm64 a kontrola ad hoc podpisu aplikace také prošly.

Samostatná kopie opravené Release aplikace s vlastním bundle ID a databází v `.build/status-item-cpu-data` byla spuštěna v grafické relaci macOS. Skutečný ukotvený panel se otevřel a odpočet průběžně klesal. Testovací ovládání přepnulo rozhraní do světlého i tmavého vzhledu.

| Stav opravené aplikace | Průměr CPU | Vyhodnocené vzorky |
| --- | ---: | --- |
| Klid, zavřený panel | 0,33 % | 0,4 %, 0,3 %, 0,3 % |
| Otevřený panel | 0,8 % | 1,0 %, 0,7 %, 0,7 % |

Měření používá pět sekundových vzorků `ps`; první dva zahazuje. Původní běžící aplikace během tohoto ověření také vykazovala nízké CPU. Tato čísla tedy nejsou přímým měřením poklesu oproti dříve reportovaným 98,2 %. Regresní test nezávisí na tom, zda AppKit na daném Macu sám opakovaná oznámení vyvolá, protože je cíleně přehrává přes skutečný observer a frontu hlavního aktoru.

Vzhled systémového menu baru nebyl globálně přepínán. Změnu barev ikony při změně vzhledu jejího skutečného tlačítka ověřuje integrační test. Opravené lokální sestavení je v `dist/CPUFix/StretchBreak.app`; testovací kopie byla po měření ukončena. Publikování nového releasu a instalace opravy do původní běžící aplikace nejsou součástí tohoto ověření.

## Shared release verification, 2026-10-05

`Scripts/verify-release.swift` now owns distribution, signed-release and published-asset verification. Original build evidence and candidate files are explicit inputs. Downloading and publishing remain in the existing commands, which keep their arguments. Published verification checks the original manifest, all checksums and the update signature before extracting any archive, then applies the full application and source checks.

Local verification used Apple Silicon, macOS 27.0.1 and Xcode 27.0. The release build and packaging for 1.2.0 passed, along with all 37 existing Swift tests, all 18 release-verification tests, workflow validation with the pinned actionlint 1.7.12, shell syntax and the real distribution check.

`Scripts/test-update-verification.py` covers valid signed and published assets, the no-feed CI case, four altered feed fields, six published-asset failures, authenticated malformed archive contents, invalid app codesign, incorrect architecture and changed source contents. It also runs the real Sparkle appcast generator and existing package command with a disposable key, and checks source snapshots that predate the glossary. The suite checks afterward that the original archives, feed, manifest and public-key property lists are unchanged.

Fixtures use temporary copies of the real packaged app and source, real Ed25519 signatures, real ad hoc codesign and macOS tools. No production private key, Keychain operation or GitHub access is needed. Ordinary CI now runs the same suite as the release workflow. GitHub Actions execution and downloading a newly published release were not exercised for this change.
