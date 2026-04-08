# Texture Audit

Audit complet des blocs integres dans le projet Godot. Chaque bloc a ete verifie contre son profil matiere dans `scripts/block_library.gd`, puis recale si la texture de base ne collait pas assez a son nom ou a sa famille visuelle.

## Corrections appliquees

- `mossy_stone` : `mossy_rock` -> `mossy_cobblestone`
- `shale` : `rock_wall_10` -> `slate_floor_03`
- `quartz_ceramic` : `concrete_tiles_02` -> `marble_tiles`
- `reef_stone` : `mossy_rock` -> `lichen_rock`
- `city_brick` : `brick_wall_09` -> `brick_floor_003`
- Sets PBR retires car non utilises apres audit : `brick_floor_02`, `concrete_tiles_02`, `mossy_rock`, `rocks_ground_04`

## Audit bloc par bloc

### Terrain et blocs de base

| Bloc | Source retenue | Analyse |
| --- | --- | --- |
| Grass | `leafy_grass` 2k sur le dessus, `dirt` 2k sur les cotes et dessous | Valide : lecture Minecraft-like claire, herbe/terre bien separees. |
| Dirt | `dirt` 2k | Valide : vraie terre brute pour sous-sol et falaises. |
| Stone | `rock_wall_10` 4k | Valide : roche brute generique, plus logique qu'une texture de brique. |
| Sand | `sand_02` 2k | Valide : grain fin et clair, correct pour desert et plages. |
| Glow Block | Shader emissif maison | Valide : bloc lumineux stylise, pas de PBR minerale necessaire. |
| Wood | `bark_platanus` 4k | Valide : aspect tronc brut, coherent pour bloc bois naturel. |
| Snow | `snow_03` 2k | Valide : bonne lecture neige compacte. |
| Mud | `brown_mud_02` 2k | Valide : boue sombre humide, adapte aux zones basses. |
| Clay | `clay_floor_001` 4k | Valide : terre argileuse seche, base propre pour bloc d'argile. |
| Mossy Stone | `mossy_cobblestone` 2k | Corrige : vraie pierre moussue, plus logique que la roche generique verte. |
| Slate | `slate_floor_03` 4k | Valide : stratification fine, bonne lecture de schiste/ardoise. |
| Granite | `granite_wall` 2k | Valide : granite rugueux, famille roche dure. |
| Marble | `marble_01` 2k | Valide : marbre massif poli, rendu premium. |
| Sandstone | `white_sandstone_blocks_02` 2k | Valide : pierre sableuse claire, base desert lisible. |
| Red Sand | `sand_02` 2k avec teinte chaude | Valide : meme granularite que le sable, variation biome propre. |
| Basalt | `rock_wall_10` 4k avec teinte tres sombre | Valide : lave refroidie / roche volcanique brute. |
| Obsidian | Shader obsidienne maison | Valide : matiere noire vernie, plus adaptee qu'une texture de pierre ordinaire. |
| Copper Alloy | `metal_plate_02` 2k avec teinte cuivre | Valide : relief metallique industriel, bon pour alliage cuivre. |
| Cobalt Alloy | `metal_plate_02` 2k avec teinte cobalt | Valide : meme base industrielle, lecture metal bleu propre. |
| Amethyst | Shader energie cristal maison | Valide : meilleur rendu qu'une photo PBR plate pour un cristal fantasy. |
| Stone Brick | `stone_brick_wall_001` 2k | Valide : vraie maçonnerie de pierre, parfaitement adaptee. |
| Mossy Brick | `mossy_brick` 2k | Valide : brique ancienne vegetalisee, logique. |
| Terracotta Tile | `clay_roof_tiles_02` 2k | Valide : tuiles cuites terre cuite, tres coherentes. |
| Ice | Shader translucide glace | Valide : bloc de glace lisible avec profondeur et transparence. |
| Neon Grid | Shader energie neon maison | Valide : bloc techno lumineux, mieux servi par shader que par PBR photo. |
| Glass | Shader translucide verre | Valide : verre propre et neutre. |

### Pierre taillee et materiaux architecturaux

| Bloc | Source retenue | Analyse |
| --- | --- | --- |
| Frost Marble | `marble_tiles` 4k avec teinte froide | Valide : marbre carrele glace, lecture noble et froide. |
| Aurora Ice | Shader translucide glace aurora | Valide : materiau glace fantasy, pas une pierre classique. |
| Shale | `slate_floor_03` 4k avec teinte plus sombre | Corrige : roche feuilletee bien plus credible que le mur rocheux brut. |
| Moon Granite | `granite_tile_03` 4k | Valide : granite clair et plus premium que le granite brut. |
| Limestone Brick | `white_sandstone_bricks_03` 4k | Valide : brique calcaire pale, famille visuelle correcte. |
| Travertine Tile | `marble_tiles` 4k avec teinte chaude | Valide : proche du travertin taille/poli. |
| Cobble Road | `cobblestone_01` 4k | Valide : pavage ancien net et lisible. |
| Ancient Cobble | `cobblestone_01` 4k avec teinte vieillie | Valide : meme base pavage, vieillie proprement. |
| Moss Tile | `concrete_moss` 4k | Valide : dalle mineralisee envahie par la mousse. |
| Lichen Rock | `lichen_rock` 4k | Valide : roche biologique tres explicite. |
| Quartz Ceramic | `marble_tiles` 4k tres clair | Corrige : lecture quartz/poli plus juste qu'un carreau beton. |
| Ivory Plaster | `plaster_stone_wall_01` 4k | Valide : enduit clair legerement mineral. |
| Kiln Brick | `brick_wall_09` 4k | Valide : vraie brique cuite, bonne texture pour four/brique chaude. |
| Royal Mosaic | `marble_mosaic_tiles` 4k | Valide : motif decoratif haut de gamme. |
| Terrazzo Lux | `terrazzo_tiles` 4k | Valide : lecture terrazzo immediate. |
| Concrete Panel | `concrete_block_wall` 4k | Valide : panneau beton net et structurel. |
| Polished Concrete | `concrete_floor_worn_001` 4k | Valide : beton lisse un peu use, coherent. |

### Metal, verre et blocs energie

| Bloc | Source retenue | Analyse |
| --- | --- | --- |
| Rust Steel | `rusty_metal_04` 4k | Valide : acier oxyde bien lisible. |
| Navy Steel | `blue_metal_plate` 4k | Valide : metal industriel bleu fonce, texture adaptee. |
| Circuit Plate | Shader circuit maison | Valide : traces lumineuses animees, meilleur choix qu'une simple plaque metal. |
| Bronze Plate | `metal_plate` 4k | Valide : plaque metal bronze propre. |
| Obsidian Glass | Shader verre sombre maison | Valide : verre mineral noir/fume, pas une simple vitre claire. |
| Prism Glass | Shader verre irise maison | Valide : bloc optique stylise, bon rendu premium. |
| Ember Crystal | Shader cristal emissif orange | Valide : cristal chaud/fantasy. |
| Storm Crystal | Shader cristal emissif bleu | Valide : cristal electrique clair. |
| Aurora Crystal | Shader cristal emissif vert cyan | Valide : cristal magique lisible. |

### Variantes biome, bois et nature

| Bloc | Source retenue | Analyse |
| --- | --- | --- |
| Dune Clay | `clay_floor_001` 4k avec teinte sablee | Valide : argile desertique, meme famille que l'argile de base. |
| Canyon Stone | `red_sandstone_wall` 4k | Valide : roche canyonesque rouge, tres logique. |
| Reef Stone | `lichen_rock` 4k avec teinte recif | Corrige : roche colonisee plus credible pour un bloc de recif. |
| Ash Basalt | `rock_wall_10` 4k avec teinte cendree | Valide : basalt volcanique couvert de cendre. |
| Volcanic Brick | `brick_wall_09` 4k avec teinte sombre | Valide : brique volcanique taillee, plus logique que pierre lisse. |
| Frost Slate | `slate_floor_03` 4k avec teinte froide | Valide : ardoise gelee. |
| Glacier Tile | `blue_floor_tiles_01` 4k | Valide : dalle glacee bleutee, propre et nette. |
| Bark Block | `bark_platanus` 4k | Valide : cube tronc/ecorce. |
| Dark Timber | `dark_wooden_planks` 4k | Valide : bois sombre travaille. |
| Old Planks | `old_wood_floor` 4k | Valide : vieilles planches usees. |
| Moss Wood | `moss_wood` 4k | Valide : bois ancien envahi de mousse. |

### Architecture chaude, urbain et surfaces speciales

| Bloc | Source retenue | Analyse |
| --- | --- | --- |
| Carved Sandstone | `sandstone_brick_wall_01` 4k | Valide : pierre sableuse taillee / sculptable. |
| Scarlet Sandstone | `red_sandstone_wall` 4k | Valide : variante plus rouge du greseux desertique. |
| White Citadel Brick | `white_sandstone_bricks_03` 4k | Valide : brique forteresse claire, famille noble. |
| Checkered Tile | `checkered_pavement_tiles` 4k | Valide : damier propre pour zones premium/urbaines. |
| Industrial Grate | `metal_grate_rusty` 4k | Valide : vraie grille industrielle. |
| Ancient Metal | `rusty_metal_grid` 4k | Valide : metal ancien maille et oxyde. |
| Ceramic Blue | `blue_floor_tiles_01` 4k | Valide : carreau emaille bleu. |
| Ceramic Brown | `brown_floor_tiles` 4k | Valide : carreau terre brune / ceramique chaude. |
| Plaster Stone | `plaster_stone_wall_01` 4k | Valide : mur enduit mineral standard. |
| Moss Concrete | `concrete_moss` 4k | Valide : beton humide colonise, lecture directe. |
| Rock Tile | `rock_tile_floor` 4k | Valide : dalle de pierre taillee. |
| Marble Tile | `marble_tiles` 4k | Valide : marbre carrele classique. |
| City Brick | `brick_floor_003` 4k | Corrige : vraie brique/pavage urbain, plus logique qu'un mur de brique generique. |

## Conclusion

Apres cette passe, chaque bloc builtin utilise soit :

- un set PBR explicitement coherent avec sa famille visuelle ;
- soit un shader maison quand le bloc est volontairement stylise, emissif, translucide ou cristallin.

Les textures retirees l'ont ete uniquement parce qu'elles n'etaient plus appelees nulle part dans le jeu.
