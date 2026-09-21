# ps-config

Konfiguracja PowerShell 7 dla Windows: **AtkynsonMono Nerd Font**, paleta
**Campbell**, Oh My Posh z motywem **craver**, Terminal-Icons i PSReadLine.

Inspiracja: [poradnik Anita Jha](https://dev.to/anitkrjha/elevate-your-windows-powershell-my-personal-customization-guide-5gf6).
Campbell określa kolory Windows Terminal; craver określa wygląd promptu.

## Instalacja

Wymagania: Windows 10/11, PowerShell 7.2+, Git, Windows Terminal uruchomiony
przynajmniej raz i dostęp do internetu. Uruchom zwykłą sesję PowerShell 7
(bez „Uruchom jako administrator”).

```powershell
git clone https://github.com/weirdmann/ps-config.git
cd ps-config
.\Install.ps1
```

Instalator dodaje Scoop, jeśli go brakuje, i instaluje `oh-my-posh` oraz
`AtkinsonHyperlegibleMono-NF` z bucketu `nerd-fonts`. Nazwa rodziny fontu widoczna
w Windows to `AtkynsonMono Nerd Font`. Moduły PSReadLine i Terminal-Icons
instaluje z PSGallery w zakresie bieżącego użytkownika. Politykę wykonywania
zmienia na `RemoteSigned` dla użytkownika tylko wtedy, gdy istniejąca blokuje Scoop.

Pliki profilu kopiuje do `%LOCALAPPDATA%\ps-config`, a w `$PROFILE` umieszcza
oznaczony blok ładujący. Kopię istniejących ustawień terminala i profilu zapisuje
w `%LOCALAPPDATA%\ps-config\backups\<data>`. Prywatne ustawienia, kopie i historia
poleceń nie trafiają do repozytorium. Kopia instalacji działa niezależnie od klona.

Windows Terminal otrzymuje font i Campbell w ustawieniach domyślnych oraz
profilach PowerShell 7; PowerShell 7 staje się domyślnym profilem. Nadpisania
kolorów w tych profilach są usuwane, aby obowiązywała paleta Campbell. Rozmiar
fontu, przezroczystość, skróty i pozostałe profile zachowują swoje ustawienia.
JSON jest ponownie formatowany, a komentarze pomijane; oryginał jest w kopii.
Instalator nie zmienia systemowej domyślnej aplikacji terminalowej.

Po instalacji zamknij wszystkie okna Windows Terminal i uruchom go ponownie.

## Używanie

- Tab: menu uzupełniania poleceń.
- Strzałki góra/dół: wyszukiwanie historii według wpisanego początku.
- Sugestie PSReadLine: historia lokalna, widok inline.
- `gcom "opis"`: `git add -- .`, następnie commit. Uwzględnia także pliki już w stagingu.
- `lazyg "opis"`: jak `gcom`, a po udanym commicie push do skonfigurowanego upstreamu.
- `which git`: definicja lub ścieżka polecenia.
- `whichdir git`: katalog pliku wykonywalnego lub modułu; funkcja bez pliku zgłasza błąd.

`gcom` i `lazyg` dodają wszystkie zmiany pod bieżącym katalogiem — sprawdź
`git status` przed użyciem. Błąd dodawania/commita przerywa dalsze operacje.

## Zmiany i aktualizacje

Edytuj `config.json`, `profile.ps1` lub `functions.ps1`, następnie:

```powershell
.\Install.ps1 -SkipDependencies
```

Ponowna instalacja zastępuje tylko oznaczony blok w `$PROFILE` i tworzy kolejną
kopię zapasową. Inne fragmenty istniejącego profilu są zachowywane.
Motyw pochodzi z aktualnie zainstalowanego Oh My Posh; ścieżka używa `current`,
więc nie zależy od konkretnego numeru wersji.

```powershell
scoop update oh-my-posh AtkinsonHyperlegibleMono-NF
Install-Module PSReadLine, Terminal-Icons -Scope CurrentUser -Force
```

## Cofnięcie konfiguracji

Usuń blok od `# >>> ps-config >>>` do `# <<< ps-config <<<` z `$PROFILE`.
Przywróć wybraną kopię `terminal.settings.json` jako plik ustawień Windows Terminal
(Ustawienia → Otwórz plik JSON). Jeśli wcześniej istniał profil, jego kopia jest
w tym samym katalogu. Zainstalowane pakiety pozostają dostępne; można je odinstalować
osobno przez Scoop i `Uninstall-Module`.

## Weryfikacja

```powershell
pwsh -NoProfile -File .\tests\Smoke.ps1
```

Testy działają w `.local/`, nie zmieniają prawdziwego profilu ani terminala.
Sprawdzają składnię, dwukrotną instalację z kopią zapasową i zachowanie istniejących
ustawień oraz przerwanie `lazyg` po nieudanym commicie.

Dokumentacja: [Oh My Posh](https://ohmyposh.dev/docs/installation/windows),
[Nerd Fonts](https://www.nerdfonts.com/font-downloads),
[wygląd Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance).
