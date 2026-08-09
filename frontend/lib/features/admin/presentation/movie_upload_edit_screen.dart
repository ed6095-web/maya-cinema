// MAYA — Admin Upload & Edit Screen
// Full movie upload with video + poster file picker, metadata form, and progress.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/movies/data/models.dart';
import 'package:maya_app/features/movies/data/movie_repository.dart';

// ============================================================================
// Upload / Edit Movie Screen
// ============================================================================

class MovieUploadEditScreen extends ConsumerStatefulWidget {
  /// If editing an existing movie, pass it here. null = create new.
  final MovieModel? existingMovie;
  final VoidCallback? onSaved;

  const MovieUploadEditScreen({super.key, this.existingMovie, this.onSaved});

  @override
  ConsumerState<MovieUploadEditScreen> createState() => _MovieUploadEditScreenState();
}

class _MovieUploadEditScreenState extends ConsumerState<MovieUploadEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  late final _titleCtrl = TextEditingController(text: widget.existingMovie?.title);
  late final _descCtrl = TextEditingController(text: widget.existingMovie?.description);
  late final _yearCtrl = TextEditingController(text: widget.existingMovie?.releaseYear?.toString());
  late final _durationCtrl = TextEditingController(
    text: widget.existingMovie?.duration != null
        ? (widget.existingMovie!.duration! ~/ 60).toString()
        : '',
  );
  late final _langCtrl = TextEditingController(text: widget.existingMovie?.language);
  late final _ratingCtrl = TextEditingController(
    text: widget.existingMovie?.rating?.toStringAsFixed(1),
  );

  bool _isFeatured = false;
  bool _isActive = true;
  List<int> _selectedGenreIds = [];
  List<GenreModel> _allGenres = [];

  // File selections
  String? _videoFilePath;
  String? _posterFilePath;
  String? _videoFileName;
  String? _posterFileName;

  bool _loading = false;
  String? _error;
  double? _uploadProgress;

  bool get _isEditing => widget.existingMovie != null;

  @override
  void initState() {
    super.initState();
    _isFeatured = widget.existingMovie?.isFeatured ?? false;
    _isActive = widget.existingMovie?.isActive ?? true;
    _selectedGenreIds = widget.existingMovie?.genres.map((g) => g.id).toList() ?? [];
    _loadGenres();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _yearCtrl.dispose();
    _durationCtrl.dispose();
    _langCtrl.dispose();
    _ratingCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await const MovieRepository().getGenres();
      if (mounted) setState(() => _allGenres = genres);
    } catch (_) {}
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _videoFilePath = result.files.first.path;
        _videoFileName = result.files.first.name;
      });
    }
  }

  Future<void> _pickPoster() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _posterFilePath = result.files.first.path;
        _posterFileName = result.files.first.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isEditing && _videoFilePath == null) {
      setState(() => _error = 'Please select a video file.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _uploadProgress = null;
    });

    try {
      final title = _titleCtrl.text.trim();
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      final year = int.tryParse(_yearCtrl.text.trim());
      final durationMin = int.tryParse(_durationCtrl.text.trim());
      final durationSec = durationMin != null ? durationMin * 60 : null;
      final lang = _langCtrl.text.trim().isEmpty ? null : _langCtrl.text.trim();
      final rating = double.tryParse(_ratingCtrl.text.trim());

      if (_isEditing) {
        await const MovieRepository().updateMovie(
          widget.existingMovie!.id,
          title: title,
          description: desc,
          releaseYear: year,
          duration: durationSec,
          language: lang,
          rating: rating,
          isFeatured: _isFeatured,
          isActive: _isActive,
          genreIds: _selectedGenreIds,
        );
      } else {
        await const MovieRepository().createMovie(
          title: title,
          description: desc,
          releaseYear: year,
          duration: durationSec,
          language: lang,
          rating: rating,
          isFeatured: _isFeatured,
          genreIds: _selectedGenreIds,
          videoFilePath: _videoFilePath,
          posterFilePath: _posterFilePath,
          onSendProgress: (sent, total) {
            if (total > 0 && mounted) {
              setState(() => _uploadProgress = sent / total);
            }
          },
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Movie updated.' : 'Movie uploaded successfully!'),
            backgroundColor: MayaColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _uploadProgress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MayaColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Movie' : 'Upload Movie'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _save,
              child: Text(
                _isEditing ? 'Save Changes' : 'Upload',
                style: const TextStyle(color: MayaColors.accent),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MayaSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Files section (only for new uploads) ──────────────────
                  if (!_isEditing) ...[
                    Text('Media Files', style: MayaTextStyles.titleSmall),
                    const SizedBox(height: MayaSpacing.md),
                    Row(
                      children: [
                        Expanded(child: _FilePicker(
                          label: 'Video File *',
                          icon: Icons.movie_outlined,
                          fileName: _videoFileName,
                          hint: 'MP4, MKV, WebM, MOV…',
                          onPick: _pickVideo,
                          isRequired: true,
                        )),
                        const SizedBox(width: MayaSpacing.md),
                        Expanded(child: _FilePicker(
                          label: 'Poster Image',
                          icon: Icons.image_outlined,
                          fileName: _posterFileName,
                          hint: 'JPG, PNG, WebP',
                          onPick: _pickPoster,
                          isRequired: false,
                        )),
                      ],
                    ),
                    const SizedBox(height: MayaSpacing.xl),
                    const Divider(color: MayaColors.border),
                    const SizedBox(height: MayaSpacing.xl),
                  ],

                  // ── Metadata section ──────────────────────────────────────
                  Text('Movie Details', style: MayaTextStyles.titleSmall),
                  const SizedBox(height: MayaSpacing.md),

                  // Title
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title *'),
                    style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: MayaSpacing.md),

                  // Description
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                    style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
                    maxLines: 4,
                    minLines: 2,
                  ),
                  const SizedBox(height: MayaSpacing.md),

                  // Year + Duration + Rating row
                  Row(
                    children: [
                      Expanded(child: TextFormField(
                        controller: _yearCtrl,
                        decoration: const InputDecoration(labelText: 'Year'),
                        style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final y = int.tryParse(v);
                          if (y == null || y < 1888 || y > 2100) return 'Invalid year';
                          return null;
                        },
                      )),
                      const SizedBox(width: MayaSpacing.md),
                      Expanded(child: TextFormField(
                        controller: _durationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                          hintText: 'e.g. 120',
                        ),
                        style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
                        keyboardType: TextInputType.number,
                      )),
                      const SizedBox(width: MayaSpacing.md),
                      Expanded(child: TextFormField(
                        controller: _ratingCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Rating (0–10)',
                          hintText: 'e.g. 8.5',
                        ),
                        style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final r = double.tryParse(v);
                          if (r == null || r < 0 || r > 10) return '0–10 only';
                          return null;
                        },
                      )),
                    ],
                  ),
                  const SizedBox(height: MayaSpacing.md),

                  // Language
                  TextFormField(
                    controller: _langCtrl,
                    decoration: const InputDecoration(labelText: 'Language', hintText: 'e.g. English'),
                    style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
                  ),
                  const SizedBox(height: MayaSpacing.xl),

                  // ── Genres ───────────────────────────────────────────────
                  Text('Genres', style: MayaTextStyles.titleSmall),
                  const SizedBox(height: MayaSpacing.md),
                  _allGenres.isEmpty
                      ? Text('Loading genres…', style: MayaTextStyles.bodySmall)
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allGenres.map((g) {
                            final selected = _selectedGenreIds.contains(g.id);
                            return FilterChip(
                              label: Text(g.name),
                              selected: selected,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _selectedGenreIds.add(g.id);
                                  } else {
                                    _selectedGenreIds.remove(g.id);
                                  }
                                });
                              },
                              selectedColor: MayaColors.accentSubtle,
                              checkmarkColor: MayaColors.accent,
                              labelStyle: MayaTextStyles.bodySmall.copyWith(
                                color: selected ? MayaColors.accent : MayaColors.textSecondary,
                              ),
                              backgroundColor: MayaColors.surfaceElevated,
                              side: BorderSide(
                                color: selected ? MayaColors.accentDim : MayaColors.border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: MayaSpacing.xl),

                  // ── Options ──────────────────────────────────────────────
                  Text('Options', style: MayaTextStyles.titleSmall),
                  const SizedBox(height: MayaSpacing.sm),
                  _ToggleRow(
                    label: 'Mark as Featured',
                    subtitle: 'Shown in the Featured section on the home screen',
                    value: _isFeatured,
                    onChanged: (v) => setState(() => _isFeatured = v),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: MayaSpacing.sm),
                    _ToggleRow(
                      label: 'Active (visible to users)',
                      subtitle: 'Inactive movies are hidden from regular users',
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                  const SizedBox(height: MayaSpacing.xl),

                  // ── Upload progress ───────────────────────────────────────
                  if (_uploadProgress != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: MayaColors.surfaceElevated,
                              valueColor: const AlwaysStoppedAnimation(MayaColors.accent),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${((_uploadProgress ?? 0) * 100).toStringAsFixed(0)}%',
                          style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: MayaSpacing.md),
                    Text(
                      'Uploading… Please do not close this window.',
                      style: MayaTextStyles.bodySmall,
                    ),
                    const SizedBox(height: MayaSpacing.xl),
                  ],

                  // ── Error ─────────────────────────────────────────────────
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(MayaSpacing.md),
                      margin: const EdgeInsets.only(bottom: MayaSpacing.md),
                      decoration: BoxDecoration(
                        color: MayaColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(MayaSpacing.buttonRadius),
                        border: Border.all(color: MayaColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: MayaColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.error)),
                          ),
                        ],
                      ),
                    ),

                  // ── Submit button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: _loading && _uploadProgress == null
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: MayaColors.background),
                            )
                          : Text(_isEditing ? 'Save Changes' : 'Upload Movie'),
                    ),
                  ),
                  const SizedBox(height: MayaSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Helper Widgets
// ============================================================================

class _FilePicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? fileName;
  final String hint;
  final VoidCallback onPick;
  final bool isRequired;

  const _FilePicker({
    required this.label,
    required this.icon,
    required this.fileName,
    required this.hint,
    required this.onPick,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null;
    return GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(MayaSpacing.md),
        decoration: BoxDecoration(
          color: hasFile ? MayaColors.accentSubtle : MayaColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
          border: Border.all(
            color: hasFile ? MayaColors.accentDim : MayaColors.border,
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: hasFile ? MayaColors.accent : MayaColors.textMuted, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: MayaTextStyles.labelMedium.copyWith(
                      color: hasFile ? MayaColors.accent : MayaColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MayaSpacing.sm),
            if (hasFile)
              Text(
                fileName!,
                style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.accent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Click to browse',
                    style: MayaTextStyles.bodySmall,
                  ),
                  Text(hint, style: MayaTextStyles.labelSmall),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MayaSpacing.md, vertical: MayaSpacing.sm),
      decoration: BoxDecoration(
        color: MayaColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
        border: Border.all(color: MayaColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MayaTextStyles.bodyMedium.copyWith(color: MayaColors.textPrimary)),
                Text(subtitle, style: MayaTextStyles.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: MayaColors.accent,
            activeTrackColor: MayaColors.accentDim,
            inactiveThumbColor: MayaColors.textMuted,
            inactiveTrackColor: MayaColors.surfaceElevated,
          ),
        ],
      ),
    );
  }
}
