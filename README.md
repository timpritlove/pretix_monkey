# PretixMonkey

Einfaches Skript, um alle Rechnungsdaten einer Veranstaltung aus der Pretix-API zu exportieren.

# Voraussetzungen

* Elixir und Erlang müssen installiert sein.
* Es wird eine Pretix-Organisation und eine Veranstaltung benötigt, auf die der API-Token zugreifen kann.
* Es wird ein API-Token für die Organisation benötigt, welches die Berechtigung für die Veranstaltung besitzt.
* Es wird ein Verrechnungskonto benötigt, welches die Rechnungen verbuchen kann.

# Installation

Das Programm ist als Mix-Escript installierbar:

```
mix escript.build
```

# Verwendung

Zum Start des Programms müssen diese Optionen oder Umgebungsvariablen gesetzt werden:

* PRETIX_ORGANIZER oder --organizer
* PRETIX_EVENT oder --event
* PRETIX_TOKEN oder --token

Für alle anderen Optionen können Standardwerte verwendet werden. In der Regel sollte ein Verrechnungskonto und ein Kontenrahmen gesetzt werden. Wenn kein anderer Kontenrahmen gesetzt wird, wird "SKR04" verwendet.

```

  Usage:
    pretix_monkey [options]

  Options:
    -o, --output            Output file path (defaults to stdout)
    -O, --organizer         Pretix organizer slug (or PRETIX_ORGANIZER env var)
    -E, --event            Pretix event slug (or PRETIX_EVENT env var)
    -T, --token            Pretix API token (or PRETIX_TOKEN env var)
    -1, --ks1              Kostenstelle1 (optional)
    -2, --ks2              Kostenstelle2 (optional)
    -B, --belegnr          BelegNr prefix (defaults to "Pretix")
    -V, --verrechnungskonto Account number (defaults to "9000")
    -K, --kontenrahmen     Chart of accounts, "skr03" or "skr04" (defaults to "skr04")

  Environment:
    PRETIX_ORGANIZER      Alternative to --organizer
    PRETIX_EVENT         Alternative to --event
    PRETIX_TOKEN         Alternative to --token
```


# Ergebnis

Das Ergebnis ist eine CSV-Datei, welche die Rechnungsdaten enthält. Diese können dann in die Buchhaltung importiert werden. Die derzeitige Struktur der CSV-Datei ist für den Import in der Buchhaltung von "MonKey Office" vorgesehen, kann aber je nach Bedarf angepasst werden.

