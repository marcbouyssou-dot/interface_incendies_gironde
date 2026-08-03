# Identité visuelle MobSanté

Le composant `BrandMark` utilise `mobsante_pictogram_256.png`, optimisé pour
l’interface. `mobsante_pictogram_master.png` est la source haute définition
commune aux déclinaisons Flutter et web ; elle n’est pas embarquée dans le
build Flutter.

Le pictogramme applicatif réunit uniquement :

- la croix de santé ;
- la figure humaine ;
- les deux courbes rouge et bleue.

Le symbole de mobilisation, actuellement une flamme, est configuré et affiché
séparément par Flutter. Les anciens fichiers `logo_hd.png` et
`logo_ui_256.png` restent des sources institutionnelles distinctes et ne sont
pas utilisés comme icône applicative.
