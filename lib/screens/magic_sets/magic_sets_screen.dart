import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify/spotify.dart' hide Player;
import '../../models/magic_set_models.dart';
import '../../providers/unified_providers.dart';
import '../../providers/magic_set_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/unified_widgets.dart';
import 'package:beatbox_manager/widgets/playlist_dialogs.dart';
import 'package:beatbox_manager/services/spotify/unified_spotify_service.dart';
import 'package:beatbox_manager/utils/unified_utils.dart';

enum PaginatedStatus {
  initial,
  loading,
  loaded,
  error
}

class PaginatedState<T> {
  final List<T> items;
  final PaginatedStatus status;
  final String? error;
  final bool hasMore;

  PaginatedState({
    required this.items,
    required this.status,
    this.error,
    this.hasMore = false,
  });

  bool get isLoading => status == PaginatedStatus.loading;
  bool get isError => status == PaginatedStatus.error;
  bool get isLoaded => status == PaginatedStatus.loaded;
}

class MagicSetsScreen extends ConsumerStatefulWidget {
  const MagicSetsScreen({Key? key}) : super(key: key);

  @override
  MagicSetsScreenState createState() => MagicSetsScreenState();
}

class MagicSetsScreenState extends ConsumerState<MagicSetsScreen> {
  @override
  Widget build(BuildContext context) {
    final magicSets = ref.watch(magicSetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Magic Sets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_offer),
            onPressed: () => Navigator.pushNamed(context, '/tag-manager'),
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: magicSets.when(
          data: (sets) => sets.isEmpty
              ? _buildEmptyState()
              : _buildSetsList(sets),
          loading: () => const LoadingIndicator(
            message: 'Chargement des Magic Sets...',
          ),
          error: (error, stack) => ErrorDisplay(
            message: 'Erreur: $error',
            onRetry: () => ref.refresh(magicSetsProvider),
            onBack: () => Navigator.pop(context), // Ajout du paramètre manquant
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSetDialog,
        child: const Icon(Icons.add),
        backgroundColor: AppTheme.spotifyGreen,
      ),
    );
  }


  void _showTemplatesManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Templates'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showCreateTemplateDialog(),
                  ),
                ],
              ),
              body: _buildTemplatesList(),
            );
          },
        );
      },
    );
  }

  Widget _buildTemplatesList() {
    return Consumer(
      builder: (context, ref, child) {
        final magicSets = ref.watch(magicSetsProvider);

        return magicSets.when(
          data: (sets) {
            final templates = sets.where((set) => set.isTemplate).toList();
            if (templates.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_outline,
                      size: 64,
                      color: AppTheme.spotifyGreen.withOpacity(0.7),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun template',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Créez des templates pour réutiliser\nvos configurations !',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: templates.length,
              padding: const EdgeInsets.all(8.0),
              itemBuilder: (context, index) {
                final template = templates[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.spotifyGreen,
                      child: Icon(Icons.bookmark, color: Colors.white),
                    ),
                    title: Text(template.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (template.description.isNotEmpty)
                          Text(
                            template.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.local_offer, size: 16, color: Colors.grey[600]),
                            Text(' ${template.tags.length} tags'),
                            if (template.metadata.isNotEmpty) ...[
                              const SizedBox(width: 16),
                              Icon(Icons.settings, size: 16, color: Colors.grey[600]),
                              Text(' ${template.metadata.length} metadata'),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => _handleTemplateAction(value, template),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'use',
                          child: Text('Utiliser ce template'),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Modifier'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const LoadingIndicator(),
          error: (error, stack) => ErrorDisplay(
            message: 'Erreur: $error',
            onRetry: () => ref.refresh(magicSetsProvider),
            onBack: () => Navigator.pop(context), // Ajoutez cette ligne
          ),
        );
      },
    );
  }
  void _handleTemplateAction(String action, MagicSet template) {
    switch (action) {
      case 'use':
        _useTemplate(template);
        break;
      case 'edit':
        _editTemplate(template);
        break;
      case 'delete':
        _confirmDeleteTemplate(template);
        break;
    }
  }
  void _confirmDeleteTemplate(MagicSet template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le template ?'),
        content: Text('Voulez-vous vraiment supprimer le template "${template.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(magicSetsProvider.notifier).deleteSet(template.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Template supprimé')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _useTemplate(MagicSet template) async {
    final playlistsState = ref.read(playlistsProvider);

    if (playlistsState.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chargement des playlists...')),
      );
      return;
    }

    if (playlistsState.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune playlist disponible')),
      );
      return;
    }

    final selectedPlaylistId = await showDialog<String>(
      context: context,
      builder: (context) => PlaylistSelectionDialog(
        playlists: playlistsState.items,
      ),
    );

    if (selectedPlaylistId != null && mounted) {
      try {
        final newSet = template.createFromTemplate(selectedPlaylistId);
        await ref.read(magicSetsProvider.notifier).addSet(newSet);

        Navigator.pop(context); // Ferme le gestionnaire de templates
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Magic Set créé avec succès')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }


  void _editTemplate(MagicSet template) {
    Navigator.pushNamed(
      context,
      '/template-editor',
      arguments: template,
    );
  }
  void _showCreateSetDialog() async {
    final spotifyService = ref.read(spotifyServiceProvider);

    if (!spotifyService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter à Spotify')),
      );
      return;
    }

    try {
      // Récupérer la liste des playlists
      final playlists = await spotifyService.fetchUserPlaylists();

      if (!mounted) return;

      // Afficher le dialogue de sélection de playlist
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Créer un Magic Set'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sélectionnez une playlist pour créer un Magic Set',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        title: Text(playlist.name ?? 'Sans nom'),
                        onTap: () {
                          Navigator.pop(context);
                          _showCreateSetDetailsDialog(playlist);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _showCreateSetDetailsDialog(PlaylistSimple playlist) {
    showDialog(
      context: context,
      builder: (context) => CreateMagicSetDialog(
        playlist: playlist,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: AppTheme.spotifyGreen.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun Magic Set',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Créez un Magic Set à partir d\'une de vos playlists Spotify !',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetsList(List<MagicSet> sets) {
    return ListView.builder(
      itemCount: sets.length,
      itemBuilder: (context, index) {
        final set = sets[index];
        return MagicSetCard(
          set: set,
          onTap: () => Navigator.pushNamed(
            context,
            '/magic-set-detail',
            arguments: set,
          ),
        );
      },
    );
  }


  Future<void> _showCreateTemplateDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateTemplateDialog(),
    );

    if (result != null && mounted) {
      try {
        final template = MagicSet.createTemplate(
          name: result['name'] as String,
          description: result['description'] as String? ?? '',
        );

        await ref.read(magicSetsProvider.notifier).addSet(template);

        // Rediriger vers l'éditeur de template
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/template-editor',
            arguments: template,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }



  void _navigateToSetDetail(MagicSet set) {
    ref.read(selectedSetProvider.notifier).state = set;
    Navigator.pushNamed(
      context,
      '/magic-set-detail',
      arguments: set,
    );
  }


}

class MagicSetCard extends StatelessWidget {
  final MagicSet set;
  final VoidCallback onTap;

  const MagicSetCard({
    Key? key,
    required this.set,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.spotifyGreen,
          child: Icon(
            set.isTemplate ? Icons.bookmark : Icons.auto_awesome,
            color: Colors.white,
          ),
        ),
        title: Text(set.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (set.description.isNotEmpty)
              Text(
                set.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.music_note, size: 16, color: Colors.grey[600]),
                Text(' ${set.tracks.length}'),
                const SizedBox(width: 16),
                Icon(Icons.local_offer, size: 16, color: Colors.grey[600]),
                Text(' ${set.tags.length}'),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (set.isTemplate)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Template',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class CreateSetDialog extends ConsumerStatefulWidget {
  final List<PlaylistSimple> playlists;
  final List<MagicSet> templates;

  const CreateSetDialog({
    Key? key,
    required this.playlists,
    required this.templates,
  }) : super(key: key);

  @override
  CreateSetDialogState createState() => CreateSetDialogState();
}

class CreateSetDialogState extends ConsumerState<CreateSetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedPlaylistId;
  PlaylistSimple? _selectedPlaylist;
  MagicSet? _selectedTemplate;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un Magic Set'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sélection de la playlist
              DropdownButtonFormField<PlaylistSimple>(
                value: _selectedPlaylist,
                decoration: const InputDecoration(
                  labelText: 'Playlist source',
                  hintText: 'Sélectionner une playlist',
                ),
                items: widget.playlists.map((playlist) => DropdownMenuItem(
                  value: playlist,
                  child: Text(playlist.name ?? 'Sans nom'),
                )).toList(),
                onChanged: (playlist) {
                  setState(() {
                    _selectedPlaylist = playlist;
                    _selectedPlaylistId = playlist?.id;
                    if (playlist != null && _nameController.text.isEmpty) {
                      _nameController.text = "Magic Set - ${playlist.name}";
                    }
                  });
                },
                validator: (value) => value == null ? 'Sélectionnez une playlist' : null,
              ),
              const SizedBox(height: 16),

              // Champ nom
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du Magic Set',
                  hintText: 'Donnez un nom à votre Magic Set',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Le nom est requis' : null,
              ),
              const SizedBox(height: 16),

              // Champ description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnelle)',
                  hintText: 'Décrivez votre Magic Set',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createMagicSet,
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Créer'),
        ),
      ],
    );
  }

  // Dans CreateSetDialogState
  Future<void> _createMagicSet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Créer le Magic Set de base
      final newSet = MagicSet.create(
        name: _nameController.text,
        playlistId: _selectedPlaylistId!,
        description: _descriptionController.text,
      );

      // 2. Récupérer la playlist complète
      final spotify = ref.read(spotifyServiceProvider);
      final playlistTracks = await spotify.spotify!.playlists
          .getTracksByPlaylistId(_selectedPlaylistId!)
          .all()
          .then((pages) => pages.toList());

      // 3. Créer un seul Magic Set avec toutes les tracks
      MagicSet updatedSet = newSet;
      for (final track in playlistTracks) {
        // Le track est déjà un Track, pas besoin de .track
        if (track.id != null) {
          updatedSet = updatedSet.addTrack(
            TrackInfo(
              trackId: track.id!,
              duration: Duration(milliseconds: track.duration?.inMilliseconds ?? 0),
            ),
          );
        }
      }

      // 4. Sauvegarder le Magic Set
      await ref.read(magicSetsProvider.notifier).addSet(updatedSet);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Magic Set créé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la création: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
class SelectPlaylistDialog extends StatelessWidget {
  final List<PlaylistSimple> playlists;

  const SelectPlaylistDialog({
    Key? key,
    required this.playlists,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sélectionner une playlist'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return ListTile(
              title: Text(playlist.name ?? 'Sans nom'),
              onTap: () => Navigator.pop(context, playlist.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }

}
class CreateTemplateDialog extends StatefulWidget {
  const CreateTemplateDialog({Key? key}) : super(key: key);

  @override
  CreateTemplateDialogState createState() => CreateTemplateDialogState();
}

class CreateTemplateDialogState extends State<CreateTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un template'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom',
                hintText: 'Nom du template',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Le nom est requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Description du template (optionnel)',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'description': _descriptionController.text,
              });
            }
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
class CreateMagicSetDialog extends ConsumerStatefulWidget {
  final PlaylistSimple playlist;

  const CreateMagicSetDialog({
    Key? key,
    required this.playlist,
  }) : super(key: key);

  @override
  CreateMagicSetDialogState createState() => CreateMagicSetDialogState();
}

class CreateMagicSetDialogState extends ConsumerState<CreateMagicSetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = "Magic Set - ${widget.playlist.name}";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un Magic Set'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du Magic Set',
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Nom requis' : null,
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optionnelle)',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createMagicSet,
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Créer'),
        ),
      ],
    );
  }

  Future<void> _createMagicSet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newSet = MagicSet.create(
        name: _nameController.text,
        playlistId: widget.playlist.id!,
        description: _descriptionController.text,
      );

      await ref.read(magicSetsProvider.notifier).addSet(newSet);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Magic Set créé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}