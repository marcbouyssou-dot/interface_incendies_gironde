# Identité visuelle MobSanté

Le composant `BrandMark` compose `mobsante_pictogram_transparent.png` et
`mobilization_flame.png`. Ces deux ressources restent séparées dans Flutter
afin que le symbole de mobilisation puisse évoluer indépendamment du
pictogramme principal.

Le pictogramme applicatif réunit uniquement :

- la croix de santé ;
- la figure humaine ;
- les deux courbes rouge et bleue.

`mobsante_app_icon_master.png` est la source haute définition des icônes web et
PWA. Elle réunit le pictogramme et la flamme sur le fond bleu nuit. Les anciens
fichiers `logo_hd.png` et `logo_ui_256.png` restent des sources
institutionnelles distinctes et ne sont pas utilisés directement comme icône
applicative.
