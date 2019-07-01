# language: fr

Fonctionnalité: Interface d'administration

  Scénario: Nouveau site - Plug-ins à jour
    Étant donné un nouveau site
    Lorsque je me connecte sur wp-admin
    Et que je navigue vers '/wp-admin/plugins.php'
    Alors je vois que le plug-in 'polylang' est à jour
    Et je vois que le plug-in 'epfl' est à jour
