# language: fr
Fonctionnalité: Page d'accueil

  Scénario: Page d'accueil
    Lorsque je navigue vers la page d'accueil
    Alors je n'ai pas d'erreurs

  Scénario: Nouveau site - Plug-ins à jour
    Etant donné un nouveau site
    Lorsque je me connecte sur wp-admin
    Et que je navigue vers '/wp-admin/plugins.php'
    Alors je vois que 'polylang' est à jour
    Et je vois que 'epfl' est à jour
