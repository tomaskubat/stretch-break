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
