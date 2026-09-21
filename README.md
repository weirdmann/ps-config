# ps-config

Konfiguracja PowerShell 7 dla Windows: **AtkynsonMono Nerd Font**, paleta
**Campbell**, waga fontu **SemiBold (600)**, Oh My Posh z motywem **craver**,
Terminal-Icons, PSReadLine, listy plików przez **eza** oraz uzupełnianie przez **fzf + PSFzf + posh-git**.
Do tego zoxide, bat, lazygit, delta, btop i skracanie poprzednich promptów.

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

Instalator dodaje Scoop, jeśli go brakuje, i instaluje `oh-my-posh`, `fzf`, `eza`,
`zoxide`, `bat`, `lazygit` (bucket `extras`), `delta`, `btop`, `less` oraz
`AtkinsonHyperlegibleMono-NF` z bucketu `nerd-fonts`. Nazwa rodziny fontu widoczna
w Windows to `AtkynsonMono NF`. Moduły PSReadLine, Terminal-Icons, posh-git i PSFzf
instaluje z PSGallery w zakresie bieżącego użytkownika tylko wtedy, gdy ich brakuje.
Aktualizacje są osobnym krokiem opisanym niżej. Politykę wykonywania
zmienia na `RemoteSigned` dla użytkownika tylko wtedy, gdy istniejąca blokuje Scoop.

Pliki profilu kopiuje do `%USERPROFILE%\.config\ps-config`, a w `$PROFILE` umieszcza
oznaczony blok ładujący. Kopię istniejących ustawień terminala i profilu zapisuje
w `%USERPROFILE%\.config\ps-config\backups\<data>`. Prywatne ustawienia, kopie i historia
poleceń nie trafiają do repozytorium. Kopia instalacji działa niezależnie od klona.
Katalog poza AppData działa także z PowerShell instalowanym przez Microsoft Store,
który może korzystać z wirtualizowanego AppData.

Windows Terminal otrzymuje font i Campbell w ustawieniach domyślnych;
profile PowerShell 7 dziedziczą je bez powielania. PowerShell 7 staje się domyślnym profilem. Nadpisania
kolorów w tych profilach są usuwane, aby obowiązywała paleta Campbell. Rozmiar
fontu, przezroczystość, skróty i pozostałe profile zachowują swoje ustawienia.
JSON jest ponownie formatowany, a komentarze pomijane; oryginał jest w kopii.
Instalator nie zmienia systemowej domyślnej aplikacji terminalowej.

Po instalacji zamknij wszystkie okna Windows Terminal i uruchom go ponownie.

## Używanie

- `ls`: eza, jeden wpis na wiersz, ikony, katalogi pierwsze.
- `la`: eza, szczegółowa tabela z nagłówkami i ukrytymi plikami.
- `tr`: eza, szczegółowe drzewo do dwóch poziomów.
- `z nazwa`: przejście do zapamiętanego katalogu pasującego do nazwy.
- `zi`: wybór zapamiętanego katalogu przez fzf. Zoxide uczy się odwiedzanych katalogów przy wyświetlaniu promptu.
- `bat plik`: podgląd z kolorowaniem składni i numerami linii; `q` zamyka przewijany podgląd.
- `lg` lub `lazygit`: interaktywny Git; `?` pokazuje pomoc aplikacji.
- `git diff` / `git show`: podgląd przez delta z numerami linii w sesji interaktywnej.
- `btop`: monitor zasobów i procesów; `q` zamyka aplikację.
- F1: lista aktywnych skrótów PSReadLine.
- Ctrl+Alt+K, następnie wybrany skrót: opis przypisanej do niego funkcji.
- `keys`: tabela skrótów; `keys Ctrl`, `keys Alt`, `keys Shift`: filtrowanie według modyfikatora.
- Tab: wyszukiwanie propozycji uzupełniania przez fzf (polecenia, parametry, ścieżki i Git).
- Ctrl+R: wyszukiwanie historii przez fzf; wybór wstawia polecenie bez jego wykonania.
- Ctrl+T: wyszukiwanie i wstawianie ścieżek przez fzf.
- Alt+C: wyszukiwanie katalogu przez fzf i przejście do niego.
- Strzałki góra/dół: wyszukiwanie historii według wpisanego początku.
- Sugestie PSReadLine: historia lokalna, widok listy (ListView), tryb edycji Windows.
- `gcom "opis"`: `git add -- .`, następnie commit. Uwzględnia także pliki już w stagingu.
- `lazyg "opis"`: jak `gcom`, a po udanym commicie push do skonfigurowanego upstreamu.
- `which git`: definicja lub ścieżka polecenia.
- `whichdir git`: katalog pliku wykonywalnego lub modułu; funkcja bez pliku zgłasza błąd.

W menu fzf wpisz fragment nazwy, wybierz strzałkami i zatwierdź Enterem;
Esc anuluje wybór. Na przykład `git switch ` + Tab pozwala wybrać gałąź,
a `Get-ChildItem -` + Tab wybrać parametr. Fzf filtruje propozycje dostarczone
przez PowerShell i posh-git; inne programy mogą wymagać własnych completerów.
Jeśli brakuje fzf lub PSFzf, Tab zachowuje zwykłe menu PSReadLine.
Integracja uruchamia się tylko w sesjach interaktywnych; Oh My Posh nadal rysuje prompt.
Terminal-Icons obsługuje `Get-ChildItem`/`gci`, a posh-git uzupełnia polecenia Git;
nie zastępują odpowiednio eza ani segmentu Git w Oh My Posh.
Pomoc F1 dotyczy wiersza poleceń; fzf, lazygit i btop mają własne skróty wewnątrz
aplikacji. Sam Ctrl nie jest wyzwalaczem pomocy. F1 zastępuje domyślną pomoc
kontekstową PowerShella; `Get-Help` pozostaje dostępne. W fzf można nawigować
Ctrl+P/Ctrl+N lub Ctrl+K/Ctrl+J, a Esc anuluje wybór.

Delta jest ustawiana przez `GIT_PAGER` wyłącznie w interaktywnym profilu
(`delta --paging=auto --line-numbers`); plik globalnej konfiguracji Git nie jest zmieniany.
Bat i delta używają `less -R` do przewijania. `cat`/`Get-Content` oraz `cd`/`Set-Location`
zachowują swoje funkcje. Zoxide korzysta z hooka `Set-PoshContext`, bez zastępowania
funkcji promptu; poprzedni kod wyjścia polecenia jest zachowywany.

Skróty eza przyjmują ścieżki i dodatkowe opcje, np. `la "C:\Program Files"`
lub `ls --all`. Kolory i ikony są automatyczne: widoczne w terminalu,
pomijane przy przekierowaniu do pliku. Skróty `ls`, `la`, `tr` są ustawiane
tylko w sesjach interaktywnych i gdy eza jest dostępne. Zwracają tekst;
do potoków obiektowych i parametrów PowerShell (`-Recurse`, `-Force`) używaj
`Get-ChildItem` lub `gci`. W sesjach interaktywnych `ls` przyjmuje opcje eza,
a nie parametry `Get-ChildItem`.

`gcom` i `lazyg` dodają wszystkie zmiany pod bieżącym katalogiem — sprawdź
`git status` przed użyciem. Błąd dodawania/commita przerywa dalsze operacje.

## Zmiany i aktualizacje

Edytuj `config.json`, `profile.ps1` lub `functions.ps1`, następnie:

```powershell
.\Install.ps1 -SkipDependencies
```

Ponowna instalacja zastępuje tylko oznaczony blok w `$PROFILE` i tworzy kolejną
kopię zapasową. Inne fragmenty istniejącego profilu są zachowywane.
Motyw `craver` pochodzi z lokalnego pliku `themes/craver.omp.json`: ozdobne
separatory zastąpiono prostymi trójkątami, a przed godziną dodano odstęp.
Aktualizacja Oh My Posh nie nadpisuje tej poprawki. Inne motywy są wyszukiwane
także w aktualnej instalacji Oh My Posh (`current`). Motyw bazuje na upstream
craver; jego licencja znajduje się w `themes/LICENSE`.

Kolory promptu: Windows ma pomarańczowe tło `#E88624`, godzina `#242424`,
folder `#343434`, Git `#484848`, .NET `#5C5C5C`, status `#707070`.
Czas wykonania ma przezroczyste tło i szary tekst oraz ikonę `#808080`.
Segmenty Node i Python pojawiają się dla odpowiedniego projektu (Python również
po aktywacji środowiska). Kubernetes pokazuje kontekst z lokalnego kubeconfig,
jeżeli jest skonfigurowany, a SSH nazwę użytkownika i hosta w sesji SSH.
Konfiguracja nie instaluje Node, Pythona, kubectl ani serwera SSH.
Transient prompt skraca poprzedni pasek do szarego `❯` po zatwierdzeniu polecenia.
Po aktualizacji wczytaj profil ponownie (`. $PROFILE`) lub otwórz nową kartę.
Profil inicjalizuje Oh My Posh z `--print`, aby nie używać starego cache inicjalizacji,
i usuwa poprzedni moduł przed ponownym załadowaniem. Dzięki temu zmiany motywu
(w tym włączenie transient prompt) obowiązują również w już otwartej sesji.
Paski pozostawione wcześniej w historii terminala nie zmienią się wstecz.

```powershell
scoop update oh-my-posh fzf eza zoxide bat lazygit delta btop less AtkinsonHyperlegibleMono-NF
Install-Module PSReadLine, Terminal-Icons, PSFzf, posh-git -Scope CurrentUser -Force
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

Integrację promptu sprawdź osobno w interaktywnym terminalu z zainstalowanymi
zależnościami: `pwsh -NoProfile -File .\tests\Prompt.ps1`.
Test kontroluje włączenie transient prompt i skróty po trzykrotnym wczytaniu profilu.

Dokumentacja: [Oh My Posh](https://ohmyposh.dev/docs/installation/windows),
[Nerd Fonts](https://www.nerdfonts.com/font-downloads),
[wygląd Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance).
