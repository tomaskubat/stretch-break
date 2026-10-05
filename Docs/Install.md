# StretchBreak 1.1.0 pro Apple Silicon

Potřebuješ Mac s čipem Apple Silicon a macOS 14 nebo novější. Ověřeno na macOS 27.0.1. Xcode ani další instalace nejsou potřeba.

1. Rozbal ZIP, přesuň StretchBreak.app do Applications a otevři ji.
2. Ovládání najdeš pod ikonou postavy v menu baru. Výchozí interval je 60 minut.
3. Pokud chceš upozornění, povol systémové notifikace. Jejich odmítnutí nebrání použití aplikace.

Aplikace má lokální podpis a není notarizovaná. Pokud macOS první otevření zablokuje, po pokusu o spuštění lze pro tuto vlastní aplikaci použít System Settings → Privacy & Security → Open Anyway. [Postup Apple](https://support.apple.com/en-us/102445) popisuje podmínky otevření. Na spravovaném Macu může být tato možnost omezená.

Data se ukládají pouze na daném Macu do:

`~/Library/Application Support/StretchBreak/StretchBreak.sqlite`

Přenesení samotné aplikace začne na druhém Macu s novými daty. Pro přenos historie, nastavení a rozpracované přestávky ukonči aplikaci na obou počítačích, zálohuj případná data v cíli a zkopíruj celou složku StretchBreak do stejného umístění. Data najdeš také přes About StretchBreak → Show data in Finder. Aktualizace souboru .app uložená data zachová.

Nové verze aplikace se kontrolují jednou denně přes GitHub Releases. Ruční kontrolu najdeš v menu More options → Check for Updates… nebo v Settings. V Settings lze vypnout automatické kontroly nebo zapnout automatické stahování a instalaci. Aktualizační archiv se před rozbalením ověřuje digitálním podpisem. První přechod z verze bez updateru vyžaduje ruční instalaci.

Start break zahájí přestávku předčasně. Done potvrzuje plánovaný nebo upravený počet, Undo umožní opravu otevřené sady. Poslední Done automaticky dokončí přestávku. Skip & restart zachová potvrzené cviky a zbytek přeskočí. Zavření panelu zachová rozpracovanou přestávku.

Aplikace počítá čas i během uspání a vypnutí aplikace. Po návratu vznikne nejvýše jedna aktuální přestávka. Připomenutí samo neotevře panel. Aplikace se sama nepřidává mezi položky po přihlášení.
