# language: fr
Fonctionnalité: Affichage de la page d'accueil
  Scénario: Page d'accueil
    Lorsque je navigue vers la page d'accueil
    Alors je vois la page d'accueil
    Alors je vois que la page a un titre EPFL

  Scénario: Page d'accueil pour administrateur
    Lorsque je navigue vers la page d'accueil
    Alors je ne vois pas la barre d'administration
    Lorsque je me loggue sur le site en tant qu'administrateur
    Et que je navigue vers la page d'accueil
    Alors je vois la page d'accueil
    Et je vois la barre d'administration
