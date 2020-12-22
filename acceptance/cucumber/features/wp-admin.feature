# language: fr

Fonctionnalité: Interface d'administration
  Contexte:
    Étant donné que je suis administrateur du site

  Scénario: Plug-ins à jour
    Lorsque je navigue vers la liste des plugins
    Alors je vois que le plug-in wp-gutenberg est à jour

  Scénario: Thème à jour
    Lorsque je navigue vers le thème EPFL 2018
    Alors je vois que le thème EPFL 2018 est à jour
