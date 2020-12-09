# language: fr
Fonctionnalité: Cookie consent
      Scénario: Comportement du bandeau
        Lorsque je navigue vers la page d'accueil
        Alors je vois la page d'accueil
        Alors je vois que la page a un titre EPFL
        Alors je vois le bandeau "cookie consent"
        Lorsque je clique le boutton "OK" du cookie consent
        Alors le bandeau "cookie consent" n'est plus là
        Lorsque je retourne vers la page d'accueil
        Alors le bandeau "cookie consent" n'est plus là
