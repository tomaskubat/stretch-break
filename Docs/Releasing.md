# Vydávání na GitHubu

Workflow v `.github/workflows/release.yml` vytvoří release po odeslání nového tagu ve tvaru `vX.Y.Z`, například `v1.0.0` nebo `v1.0.1`. Čísla nesmějí mít počáteční nuly. Sufixy jako `-beta` nejsou podporované.

## První nastavení

Nahraj toto repo včetně workflow na GitHub a nastav jeho adresu jako remote `origin`. GitHub Actions musí být v repozitáři povolené. Workflow používá automatický `GITHUB_TOKEN` s oprávněním `contents: write`; pro tento způsob vydávání není potřeba přidávat osobní token ani jiné secrets. Pokud organizace omezuje Actions nebo oprávnění tokenu, musí její nastavení dovolovat tento workflow a vytváření releasů.

## Vytvoření releasu

Na commitu, který chceš vydat, vytvoř nový tag a odešli ho:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Tag musí ukazovat na commit obsahující release workflow. Jeho průběh najdeš na GitHubu v Actions → Release. Po úspěšném dokončení se v Releases objeví:

- `StretchBreak-1.0.0-arm64.zip` — hotová aplikace a návod k instalaci.
- `StretchBreak-1.0.0-source.zip` — odpovídající zdrojový projekt včetně testů, skriptů a workflow.
- `SHA256SUMS.txt` — SHA-256 kontrolní součty obou archivů.

Další verzi vydáš novým tagem, například `v1.0.1`. Názvy archivů, verze v About a metadata aplikace se odvozují z tagu. Kvůli vydání není potřeba měnit verzi v `Resources/Info.plist`; ta slouží jako výchozí verze pro místní sestavení bez argumentu.

Workflow na Apple Silicon runneru `macos-26` s Xcode 26.6 nejprve ověří tag, spustí testy a sestaví aplikaci. Potom ověří podpis, architekturu, verzi, systémové závislosti, kontrolní součty a shodu rozbalených zdrojů. Zveřejnění proběhne až po úspěchu všech těchto kroků. Publikuje pouze uvedené tři soubory.

Při chybě otevři log neúspěšného kroku. Chyba před publikováním release nevytvoří. Již existující release se automaticky nepřepisuje; každý tag používej pro jednu verzi. Selhání při komunikaci s GitHubem může zanechat rozpracovaný release, který je potřeba nejprve zkontrolovat v Releases.

## Místní ověření stejné verze

```sh
swift test --cache-path .build/cache
./Scripts/build-app.sh v1.0.1
./Scripts/package-app.sh v1.0.1
./Scripts/verify-package.sh v1.0.1
```

Při balení jiné verze než má sestavená aplikace skript skončí chybou. Místní skripty přijímají také verzi bez `v`. Hotové soubory vznikají v `dist/`, které se do Gitu neukládá. Při místním opakování s více verzemi platí `SHA256SUMS.txt` pro poslední zabalenou verzi.

Balíček má ad hoc podpis, bez certifikátu Developer ID a notarizace. Automatický release tedy zachovává současný způsob instalace a může vyžadovat schválení prvního spuštění v macOS. Podrobnosti jsou v přiloženém `Install.md`. Pro podepisování a notarizaci by bylo potřeba doplnit Apple Developer certifikát a přihlašovací údaje; tento workflow je nevyžaduje.

Dokumentace: [spouštění při odeslání tagů a oprávnění workflow](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax), [vytváření releasu přes GitHub CLI](https://cli.github.com/manual/gh_release_create), [macOS runner a dostupné Xcode](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md).
