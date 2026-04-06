import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';
import '../../../services/achievement_service.dart';

class AddReviewDialog extends StatefulWidget {
  final String clubId;
  final String clubName;
  final VoidCallback onSubmitted;

  const AddReviewDialog({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.onSubmitted,
  });

  @override
  State<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  int _rating = 0;
  final _textController = TextEditingController();
  bool _loading = false;
  final List<XFile> _photos = [];
  static const _maxPhotos = 3;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _maxPhotos) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );
    if (image != null && mounted) {
      setState(() => _photos.add(image));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите оценку')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      // Upload photos first
      final List<String> photoUrls = [];
      for (final photo in _photos) {
        final bytes = await photo.readAsBytes();
        final url = await SupabaseService().uploadReviewPhoto(bytes.toList(), photo.name);
        photoUrls.add(url);
      }

      await SupabaseService().addReview(
        clubId: widget.clubId,
        rating: _rating,
        text: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
        photoUrls: photoUrls,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Отзыв опубликован!')),
        );
        // Check achievements in background
        AchievementService().checkAndUnlock().then((names) {
          if (names.isNotEmpty && context.mounted) {
            AchievementService.showUnlockNotifications(context, names);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.text3.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.clubName,
              style: TextStyle(
                color: context.text1,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text('Оцените ваш визит',
                style: TextStyle(color: context.text2, fontSize: 14)),
            const SizedBox(height: 20),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      starIndex <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 40,
                      color: starIndex <= _rating
                          ? const Color(0xFFFBBF24)
                          : context.text3,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Text field
            TextField(
              controller: _textController,
              maxLines: 3,
              maxLength: 500,
              style: TextStyle(color: context.text1),
              decoration: InputDecoration(
                hintText: 'Расскажите о вашем опыте (необязательно)',
                hintStyle: TextStyle(color: context.text3, fontSize: 14),
                filled: true,
                fillColor: context.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Photo picker section
            _PhotoPickerSection(
              photos: _photos,
              maxPhotos: _maxPhotos,
              onAdd: _pickPhoto,
              onRemove: _removePhoto,
            ),
            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _rating > 0
                      ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12)]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_photos.isEmpty ? 'Отправить отзыв' : 'Отправить с фото (${_photos.length})'),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PhotoPickerSection extends StatelessWidget {
  final List<XFile> photos;
  final int maxPhotos;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _PhotoPickerSection({
    required this.photos,
    required this.maxPhotos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.camera_alt_outlined, size: 16, color: context.text3),
            const SizedBox(width: 6),
            Text('Фото (${photos.length}/$maxPhotos)',
                style: TextStyle(color: context.text3, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Existing photos
              ...photos.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb
                          ? FutureBuilder<List<int>>(
                              future: entry.value.readAsBytes().then((b) => b.toList()),
                              builder: (_, snap) => snap.hasData
                                  ? Image.memory(
                                      snap.data! as dynamic,
                                      width: 80, height: 80, fit: BoxFit.cover)
                                  : const SizedBox(width: 80, height: 80),
                            )
                          : Image.network(
                              entry.value.path,
                              width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 80, height: 80,
                                color: context.surface,
                                child: Icon(Icons.image, color: context.text3),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 2, right: 2,
                      child: GestureDetector(
                        onTap: () => onRemove(entry.key),
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              // Add button
              if (photos.length < maxPhotos)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: AppTheme.primary.withValues(alpha: 0.7), size: 28),
                        const SizedBox(height: 2),
                        Text('Фото', style: TextStyle(
                            color: AppTheme.primary.withValues(alpha: 0.7), fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
