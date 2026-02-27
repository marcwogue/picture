# Plan de correction (fixer.md)

Objectif
--------
Documenter étape par étape les corrections à appliquer pour résoudre le bug suivant : lorsqu'on sélectionne un album contenant des médias (ex. 234), l'ouverture de l'album montre "Aucun fichier trouvé" alors que les médias existent.

Résumé du problème
------------------
Observations initiales :
- GalleryPage reçoit un AppAlbum et appelle MediaService.getMediaFromAlbum mais _media reste vide.
- MediaService utilise PhotoManager.getAssetListPaged puis bascule sur getAssetListRange si la première méthode renvoie une liste vide.
- Un _initialPageSize trop grand (500) est utilisé dans GalleryPage (valeur non alignée avec AppConstants.mediaPageSize).
- AppAlbum.assetCountAsync renvoie 0 pour les albums locaux (assetPath == null), ce qui casse la logique de filtrage dans HomePage.
- Certaines méthodes publiques de MediaService n'effectuent pas de vérification explicite de permission avant d'appeler PhotoManager.

Causes probables
----------------
1. Permissions manquantes/oubliées : getMediaFromAlbum et getMediaFromAlbumRange doivent s'assurer que la permission a été accordée avant d'interroger PhotoManager.
2. Page size / pagination : pageSize excessif (500) pouvant provoquer des comportements inattendus selon la plateforme/photo_manager ; fallback non robuste.
3. Albums locaux : AppAlbum.assetCountAsync retourne 0 pour albums locaux, ce qui provoque des albums vides ou exclus.
4. Manque de gestion d'erreurs et logs insuffisants au moment où PhotoManager retourne 0 éléments alors que assetCountAsync > 0.

Plan de correction (étapes détaillées)
-------------------------------------
Les corrections ci-dessous sont ordonnées par priorité (impact élevé → faible).

Étape 1 — Ajouter des vérifications de permission dans MediaService
-----------------------------------------------------------------
But : garantir que chaque méthode qui interroge PhotoManager demande/valide la permission avant de procéder.
Fichiers ciblés : `lib/services/media_service.dart`

Modifications proposées :
- Au début de toutes les méthodes publiques qui accèdent à PhotoManager (getMediaFromAlbum, getMediaFromAlbumRange, getAllImages, getAllVideos, getRecentMedia, getMediaByDateRange, etc.) ajouter :

```dart
if (!_hasPermission) {
  final granted = await requestPermission();
  if (!granted) return [];
}
```

- Centraliser si utile : créer une méthode privée `_ensurePermission()` qui fait cette logique et l'utiliser partout.

Étape 2 — Réduire page size / utiliser AppConstants.mediaPageSize
----------------------------------------------------------------
But : éviter des requêtes trop larges qui provoquent l'échec de getAssetListPaged.
Fichiers ciblés : `lib/pages/gallery/gallery_page.dart`

Modifications proposées :
- Remplacer `static const int _initialPageSize = 500;` par :

```dart
static const int _initialPageSize = AppConstants.mediaPageSize; // = 50
```

- Utiliser cette valeur partout (ou supprimer la constante et référencer `AppConstants.mediaPageSize` directement).

Étape 3 — Rendre getMediaFromAlbum robuste (pagination et fallback)
-----------------------------------------------------------------
But : si getAssetListPaged renvoie 0 éléments alors que assetCountAsync > 0, essayer des approches graduelles et plus résistantes.
Fichiers ciblés : `lib/services/media_service.dart`

Modifications proposées (approche recommandée) :
1. Après avoir récupéré `totalCount`, calculer `start = page * pageSize` et `end = min(totalCount, start + pageSize)`.
2. Appeler `getAssetListRange(start: start, end: end)`. Ne pas dépendre uniquement de getAssetListPaged.
3. Si `assets.isEmpty && totalCount > 0 && page == 0`, essayer une récupération par petits segments (chunks) :

```dart
final int chunk = AppConstants.mediaPageSize;
for (int s = 0; s < totalCount; s += chunk) {
  final e = (s + chunk) > totalCount ? totalCount : (s + chunk);
  final batch = await album.assetPath!.getAssetListRange(start: s, end: e);
  if (batch.isNotEmpty) { assets.addAll(batch); break; }
}
```

4. Si après cela `assets` est toujours vide, logger une erreur détaillée (assetCount, album id/name, plateforme, résultat de permission) et retourner `[]`.

Raisons : certains backends/versions de photo_manager ont des comportements différents entre getAssetListPaged et getAssetListRange ; récupérer par petits segments est plus tolérant.

Étape 4 — Corriger AppAlbum.assetCountAsync pour les albums locaux
-----------------------------------------------------------------
But : HomePage filtre _albums selon `album.assetCountAsync` et les albums locaux sont vus comme vides.
Fichiers ciblés : `lib/models/album_model.dart`

Modifications proposées :
- Ajouter `import 'dart:io';` en haut du fichier.
- Remplacer l'implémentation de assetCountAsync par :

```dart
Future<int> get assetCountAsync async {
  if (assetPath != null) return await assetPath!.assetCountAsync;
  if (localPath != null) {
    try {
      final dir = Directory(localPath!);
      if (!await dir.exists()) return 0;
      final files = dir
          .listSync(followLinks: false)
          .whereType<File>()
          .where((f) {
            final ext = f.path.toLowerCase().split('.').last;
            return ['jpg','jpeg','png','webp','gif','mp4','mov','avi','mkv']
                .contains(ext);
          })
          .length;
      return files;
    } catch (_) {
      return 0;
    }
  }
  return 0;
}
```

- Cette correction permet d'afficher correctement les albums locaux et d'avoir un `assetCountAsync` cohérent.

Étape 5 — Améliorer logging et messages d'erreur
------------------------------------------------
But : faciliter le diagnostic si PhotoManager renvoie 0 alors qu'il y a des fichiers.
Fichiers ciblés : `lib/services/media_service.dart`, `lib/pages/gallery/gallery_page.dart`, `lib/pages/home/home_page.dart`

Modifications proposées :
- Ajouter des debugPrint plus verboses avec : album.id, album.name, totalCount, page, pageSize, platform (Platform.operatingSystem), permission state.
- En cas d'échec (assets.isEmpty && totalCount > 0), logger stack trace et renvoyer un message d'erreur exploitable.

Étape 6 — Vérifier les méthodes de récupération locales (thumbnails / fichiers)
-------------------------------------------------------------------------------
But : s'assurer que AlbumCard._getAlbumThumbnail() et MediaItem.getThumbnail() gèrent correctement les images et vidéos locaux.
Fichiers ciblés : `lib/widgets/album_card.dart`, `lib/models/media_item.dart`

Remarques :
- Pour desktop, MediaItem.getThumbnail() retourne actuellement le fichier brut (si image). C'est acceptable, mais on pourrait générer une miniature plus légère.
- AlbumCard._getAlbumThumbnail() itère sur `dir.listSync()` sans trier ; il est conseillé de trier par date modifiée descendante (pour choisir la vignette la plus récente).

Étape 7 — Tests et validation manuelle
-------------------------------------
Procédure de reproduction et vérification :
1. Lancer l'application sur l'appareil ciblé (Android/iOS) : `flutter run -d <device>`.
2. Activer les logs `flutter logs` ou observer la console VSCode/Android Studio.
3. Sur l'écran d'accueil, vérifier que les albums apparaissent et que les compteurs sont corrects (log: count > 0).
4. Cliquer sur l'album problématique et observer les logs dans GalleryPage :
   - `DEBUG GalleryPage: Loading from album "<name>", totalCount = <n>`
   - `DEBUG MediaService: Getting media from album "<name>", page: X, pageSize: Y, totalCount: Z`
   - `DEBUG MediaService: Got <k> assets from getAssetListPaged` ou `Fallback got <k> assets`
5. Valider que le grid affiche bien les médias (StatisticsBanner totalCount doit correspondre).

Tests automatisés :
- Ajouter des tests unitaires pour MediaService en mockant AssetPathEntity (Mockito) pour simuler getAssetListPaged renvoyant [] mais assetCountAsync > 0, et vérifier que getMediaFromAlbum finit par retourner des éléments.

Étape 8 — Commit, PR et message
-------------------------------
- Appliquer les changements par petites PRs :
  1. `Fix: permissions checks in MediaService` (media_service.dart)
  2. `Fix: robust asset pagination and fallback` (media_service.dart)
  3. `Fix: local album asset counting` (album_model.dart)
  4. `Tweak: reduce initial page size and logging` (gallery_page.dart + logging)

- Exemple de message de commit (ajouter le trailer requis) :

```
Fix: make album media loading robust and fix local album counts

- Ensure permission checks in MediaService methods
- Use AppConstants.mediaPageSize and chunked retrieval
- Implement assetCountAsync for local albums

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

Étape 9 — Remarques de sécurité et performance
---------------------------------------------
- La récupération chunkée est plus sûre, mais attention aux performances: éviter de charger *tous* les fichiers en mémoire pour de très grands albums; charger par pages et utiliser lazy loading (`_loadMoreMedia`) est recommandé.
- Ne pas committer de chemins absolus ou de données sensibles; les modifications proposées n'introduisent pas de secrets.

Checklist avant merger
----------------------
- [ ] Tests manuels reproduits et logs OK
- [ ] Tests unitaires ajoutés ou mis à jour
- [ ] Changements limités et commentés
- [ ] PR révisée par un pair

Annexe : exemples de patch rapides (diffs suggérés)
--------------------------------------------------
1) `lib/models/album_model.dart`
- Ajouter `import 'dart:io';`
- Remplacer le getter assetCountAsync par la version qui compte les fichiers locaux (cf. section Étape 4).

2) `lib/services/media_service.dart`
- Au début de `getMediaFromAlbum` et `getMediaFromAlbumRange` : s'assurer que `_hasPermission` est vrai (cf. Étape 1).
- Remplacer la récupération `getAssetListPaged` par une version qui utilise `getAssetListRange` et, si nécessaire, récupère par `chunk`.

3) `lib/pages/gallery/gallery_page.dart`
- Remplacer `_initialPageSize = 500` par `AppConstants.mediaPageSize`.

Fin du document.
