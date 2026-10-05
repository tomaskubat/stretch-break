# Vydávání na GitHubu

Workflow v `.github/workflows/release.yml` vytvoří release po odeslání nového tagu ve tvaru `vX.Y.Z`, například `v1.1.0`. Čísla nesmějí mít počáteční nuly. Sufixy jako `-beta` nejsou podporované.

## Průběžné kontroly

Workflow `.github/workflows/ci.yml` běží při otevření a aktualizaci pull requestu do `main`, při pushnutí do `main` a při ručním spuštění v Actions → CI. Používá stejný Apple Silicon runner a Xcode jako release workflow. Novější běh stejného PR nebo stejné větve nahradí starší nedokončený běh stejné události.

CI kontroluje syntaxi shellových skriptů, `Resources/Info.plist` a obě workflow pomocí actionlint 1.7.12. Stažený nástroj ověřuje připnutým SHA-256 součtem. Potom spustí všechny automatické testy, vytvoří release sestavení a ověří distribuční archivy včetně ad hoc podpisů, verzí, architektury, závislostí, obsahu a kontrolních součtů. CI má pouze oprávnění `contents: read`, nepoužívá produkční podpisový klíč a nic nepublikuje.

V repozitáři `tomaskubat/stretch-break` je `Tests and distribution` nastavená jako povinná kontrola větve `main` a musí pocházet z GitHub Actions. Před sloučením musí být větev PR aktuální vůči `main`. Správce repozitáře může pravidlo obejít. Samotný soubor workflow pravidla ochrany větve nenastavuje; v jiné kopii repozitáře je nastav samostatně.

Místní ekvivalent CI:

```sh
./Scripts/check-config.sh
swift test --cache-path .build/cache
./Scripts/build-app.sh
./Scripts/package-app.sh
./Scripts/verify-package.sh
```

Skutečné ovládání aplikace a instalaci aktualizace mezi dvěma verzemi ověř před vydáním podle `Docs/UITests.md`. Tyto scénáře nejsou součástí automatického CI.

## Nastavení podpisu aktualizací

GitHub Actions musí být povolené. Workflow používá automatický `GITHUB_TOKEN` s oprávněním `contents: write` pro publikování releasu a repository secret `SPARKLE_PRIVATE_KEY` pro podpis aktualizačních archivů. Osobní GitHub token do aplikace ani workflow nepatří.

Podpisový klíč pro toto repo byl vytvořený pomocí Sparkle `generate_keys` a uložený v macOS Klíčence pod účtem `local.stretchbreak.app`. Veřejný klíč je v `Resources/Info.plist` jako `SUPublicEDKey`; soukromý klíč je také v GitHub Actions Secrets. Klíč není součástí zdrojových archivů.

Pro nastavení jiné kopie repozitáře nejprve spusť `swift package resolve --cache-path .build/cache`. Nástroje Sparkle potom najdeš v `.build/artifacts/sparkle/Sparkle/bin/`. Existující soukromý klíč lze exportovat z Klíčenky a uložit do repository secret bez vypsání jeho obsahu:

```sh
umask 077
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account local.stretchbreak.app -x /private/tmp/stretchbreak-update-key
gh secret set SPARKLE_PRIVATE_KEY --repo tomaskubat/stretch-break < /private/tmp/stretchbreak-update-key
rm /private/tmp/stretchbreak-update-key
```

Zálohuj Klíčenku nebo exportovaný klíč na bezpečné místo. Zachovej stejný klíč pro další verze. Bez Developer ID není k dispozici náhradní ověření, které by umožnilo obnovit aktualizace po ztrátě klíče. Nový veřejný klíč by vyžadoval ruční instalaci aplikace.

## Vytvoření releasu

Na commitu, který chceš vydat, vytvoř nový tag a odešli ho:

```sh
git tag v1.1.0
git push origin v1.1.0
```

Tag musí ukazovat na commit obsahující release workflow. Po úspěšném dokončení Actions → Release se v Releases objeví:

- `StretchBreak-1.1.0-arm64.zip`, hotová aplikace s návodem k instalaci a licencí.
- `StretchBreak-1.1.0-source.zip`, odpovídající zdrojový projekt včetně `Package.resolved`.
- `StretchBreak-1.1.0-update.zip`, archiv pro Sparkle obsahující pouze `StretchBreak.app`.
- `appcast.xml`, verze, požadavky na Mac, odkaz na konkrétní update ZIP a jeho Ed25519 podpis.
- `SHA256SUMS.txt`, kontrolní součty všech tří archivů a feedu.

Verze aplikace a názvy archivů se odvozují z tagu. `Resources/Info.plist` poskytuje výchozí verzi pro místní sestavení bez argumentu.

Workflow na Apple Silicon runneru `macos-26` s Xcode 26.6 ověří tag, spustí testy, sestaví aplikaci se Sparkle a podepíše aplikaci i pomocné procesy ad hoc. Potom zabalí archivy, vytvoří feed a ověří verzi, architekturu, podpisy, odkazy, kontrolní součty a shodu zdrojů. Ed25519 podpis updateru ověřuje vůči veřejnému klíči skutečně zabalené aplikace. Chybějící secret nebo neodpovídající klíč zastaví workflow před publikováním.

Release workflow také spouští kontroly konfigurace a testy odmítnutí změněné verze, odkazu, délky archivu a podpisu v appcastu. Po publikování stáhne všechny tři ZIPy a kontrolní součty z konkrétního tagu, feed stáhne ze stejné adresy `latest/download/appcast.xml`, kterou používá updater. Porovná stažené součty s místními součty ověřených release assetů, ověří stažené soubory, metadata feedu, Ed25519 podpis update ZIPu a podpis i metadata rozbalené aplikace. Pokud tato kontrola selže, workflow skončí chybou; již publikovaný release zůstane dostupný a vyžaduje kontrolu.

Release běhy se při novém pushi neruší. Kontrola publikovaných souborů je posledním krokem stejného workflow. Vydání vytvořené přes `GITHUB_TOKEN` nespouští navazující workflow na událost `release.published`. Novou verzi vydávej až po dokončení předchozího běhu, aby její publikování nezměnilo `latest` během ověřování.

Feed používá stálou adresu `https://github.com/tomaskubat/stretch-break/releases/latest/download/appcast.xml`. Odkaz na update ZIP uvnitř feedu ukazuje na konkrétní tag. Feed se vytváří pro aktuální release a nabízí plnou aktualizaci, bez delta balíčků.

Každý tag používej pro jednu verzi a vydávej rostoucí čísla verzí. Pokud potřebuješ zpřístupnit starší opravu vedle novější řady nebo změnit podporované platformy, je potřeba upravit publikování feedu tak, aby zachovával více vhodných verzí. Již existující release se automaticky nepřepisuje. Selhání při komunikaci s GitHubem může zanechat rozpracovaný release, který nejprve zkontroluj v Releases.

## Místní ověření

```sh
swift test --cache-path .build/cache
./Scripts/build-app.sh v1.1.0
./Scripts/package-app.sh v1.1.0
./Scripts/generate-appcast.sh v1.1.0
python3 Scripts/test-update-verification.py v1.1.0
./Scripts/verify-package.sh v1.1.0
# Po publikování stejné verze:
./Scripts/verify-published-release.sh v1.1.0
```

`generate-appcast.sh` používá klíč v Klíčence pod účtem `local.stretchbreak.app`; macOS může požádat o povolení přístupu. V CI čte `SPARKLE_PRIVATE_KEY` ze standardního vstupu podpisového nástroje. Soukromý klíč se nepředává jako argument procesu ani se nezapisuje do distribuovaných souborů.

`verify-published-release.sh` vyžaduje původní sestavení a `dist/SHA256SUMS.txt` z publikování. Nové sestavení stejné verze může mít jiné součty, proto jím nenahrazuj očekávané release assety před touto kontrolou.

Při balení jiné verze než má sestavená aplikace skript skončí chybou. Místní skripty přijímají také verzi bez `v`. Hotové soubory vznikají v `dist/`, které se do Gitu neukládá. Při opakovaném balení více verzí platí `SHA256SUMS.txt` a `appcast.xml` pro poslední zabalenou verzi.

## Chování aplikace

Sparkle kontroluje nové verze jednou denně. Ruční kontrola je v menu More options a v Settings. Automatické kontroly jsou ve výchozím stavu zapnuté; automatické stahování a instalace vyžadují zapnutí v Settings nebo dialogu Sparkle. Tyto volby se ukládají ihned. Bez připojení funguje zbytek aplikace dál.

Archiv se před rozbalením ověřuje pomocí Ed25519. System profiling je vypnutý. Historie a nastavení zůstávají v databázi mimo `.app`. Oddělené UI testy updater nespouštějí. Verze bez updateru potřebují jednu ruční instalaci verze, která ho obsahuje.

Aplikace zůstává ad hoc podepsaná, bez Developer ID a notarizace. První instalace proto může vyžadovat schválení spuštění v macOS. Podrobnosti jsou v přiloženém `Install.md`.

Dokumentace: [Sparkle](https://sparkle-project.org/documentation/), [publikování aktualizací](https://sparkle-project.org/documentation/publishing/), [odkazy na latest release](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases), [GitHub workflow](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax).
