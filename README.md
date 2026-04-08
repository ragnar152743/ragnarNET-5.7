# Voxel RTX Game

Godot 4 sandbox voxel moderne inspire de Minecraft RTX, avec generation infinie par chunks, sauvegardes multi-mondes, chargement reel, inventaire limite, systeme de mods data-driven et personnage 3D anime. Le jeu est maintenant accompagne d'un launcher Windows separe qui demarre le jeu avec une cle et un jeton de session.

## Features

- monde voxel infini autour du joueur avec streaming progressif terrain + props
- executable de launcher separe pour demarrer le jeu, verifier GitHub et installer les mises a jour du build jeu
- sprint avec FOV dynamique et animation de vue joueur
- 50 nouveaux blocs premium du jeu, avec matieres PBR et shaders dedies
- terrain procedural, eau, brouillard, cycle jour/nuit et eclairage premium
- collisions voxel stables, chunks lointains sans physique, et rebuild optimise par echantillonnage local
- inventaire limite, vide au depart, avec stacks finis
- destruction/pose de blocs avec consommation reelle
- arbres 3D cassables avec drops de bois et animation de casse
- coffres, caisses, tool chests et souches 3D cassables avec loot
- vegetation 3D plus riche: arbres, rochers, herbe et buissons
- panneau de mods en jeu
- personnage 3D anime en vue joueur

## Controls

- `ZQSD` / `WASD`: move
- `Shift`: sprint
- `Space`: jump
- `Mouse`: look
- `Left click`: break
- `Right click`: place
- `Mouse wheel` / `1-8`: select slot
- `M`: open mod panel
- `R`: regenerate a new world seed
- `Esc`: release / capture mouse

## Main scenes

- `scenes/Main.tscn`: bootstrap du jeu, sauvegardes, monde, joueur, HUD, avec verification de cle au demarrage.
- `scenes/World.tscn`: monde infini, streaming, eau, props, ambiance.
- `scenes/Player.tscn`: controleur FPS, inventaire, interaction, personnage anime.
- `scenes/ui/HUD.tscn`: hotbar, target label, crosshair, panneau de mods.
- `scenes/ui/MainMenu.tscn`: menu principal, slots de sauvegarde et ecran de chargement.
- `scenes/props/*.tscn`: props 3D interactifs et decoratifs.

## Main scripts

- `scripts/main.gd`: orchestration globale du jeu, slots de sauvegarde, chargement, autosave, monde et HUD.
- `scripts/launch_security.gd`: validation de la cle de lancement et du jeton de session envoye par le launcher.
- `scripts/github_updater.gd`: check GitHub Releases, telechargement d'une mise a jour Windows et preparation de l'installation au redemarrage.
- `scripts/save_manager.gd`: lecture/ecriture des slots et metadonnees de parties.
- `scripts/world.gd`: generation infinie, streaming progressif terrain/props, collision radius dedie, raycast interaction, spawn et variantes de blocs.
- `scripts/voxel_chunk.gd`: mesh/collisions par chunk avec cache voxel local et fusion de boites de collision pour reduire fortement le cout physique.
- `scripts/block_library.gd`: registre des blocs, mapping de materiaux coherents, shaders speciaux et extension par mods.
- `scripts/mod_loader.gd`: lecture et interpretation des `mod.json`, activation et etat des mods.
- `scripts/player.gd`: deplacement, sprint, inventaire fini, interaction blocs/props, vue personnage animee.
- `scripts/ui/main_menu.gd`: interface des sauvegardes et progression de chargement.
- `scripts/ui/hud.gd`: hotbar detaillee et panneau de mods.
- `scripts/props/tree.gd`: arbre cassable avec loot et animation.
- `scripts/props/breakable_prop_base.gd`: base commune des props cassables.
- `scripts/props/treasure_chest.gd`: coffre 3D avec loot rare.
- `scripts/props/wooden_crate.gd`: caisse 3D avec loot bois.
- `scripts/props/tool_chest.gd`: coffre a outils 3D avec loot industriel.
- `scripts/props/tree_stump.gd`: souche 3D cassable.
- `scripts/props/shrub.gd`: buisson 3D decoratif.

## Mods

- Les mods integres sont dans `mods/`.
- En build exporte, tu peux aussi deposer des mods dans un dossier `mods/` a cote de l executable.
- Le format est documente dans `mods/README.md`.

## Assets

- Voir `assets/README.md` pour les assets integres, les overrides et les sources web utilisees.
- Voir `TEXTURE_AUDIT.md` pour l'audit complet texture/bloc et les corrections de mapping.

## Launcher / Updates

- Le launcher Windows se trouve dans `launcher_app/VoxelRTXLauncher/`.
- Il installe `VoxelRTXGame.exe` dans `%LocalAppData%\Programs\VoxelRTX` si le jeu n'est pas encore present.
- Il verifie le manifeste GitHub et tente une reparation ou une mise a jour avant de lancer le jeu.
- Il demande la cle de lancement, lance `VoxelRTXGame.exe` avec la cle et un jeton de session, et le jeu refuse le demarrage si la validation echoue.
- Le repo GitHub configure pour le flux launcher est `ragnar152743/ragnarNET-5.7`.
- Le contrat partage est dans `security/launch_contract.json`.
- Le manifeste GitHub versionne est dans `launcher/manifest.json`.
- `tools/publish_launcher.ps1` publie le launcher dans `builds/`.
- `tools/prepare_github_release.ps1` prepare `VoxelRTXGame.exe`, `VoxelRTXLauncher.exe` et `manifest.json` pour la prochaine release GitHub.
