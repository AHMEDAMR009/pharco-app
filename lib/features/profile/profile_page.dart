import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/employee.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadAvatar(Employee employee) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 800);
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);
      final path = await ref.read(storageServiceProvider).uploadAvatar(picked, employee.id);
      await ref.read(employeeServiceProvider).updateAvatarPath(employee.id, path);
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not upload photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        data: (e) {
          final avatarUrl =
              e.avatarPath != null ? ref.read(storageServiceProvider).avatarPublicUrl(e.avatarPath!) : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _isUploadingAvatar ? null : () => _pickAndUploadAvatar(e),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: PharcoColors.orange,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: (avatarUrl == null)
                            ? Text(
                                e.fullName.isNotEmpty ? e.fullName[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 32, color: Colors.white),
                              )
                            : null,
                      ),
                      if (_isUploadingAvatar)
                        const Positioned.fill(
                          child: CircleAvatar(
                            backgroundColor: Colors.black45,
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: PharcoColors.charcoal, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text(e.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              Center(child: Text(e.titleName ?? '', style: const TextStyle(color: Colors.black54))),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    ListTile(title: const Text('Employee Code'), trailing: Text(e.code)),
                    if (e.email != null) ...[
                      const Divider(height: 1),
                      ListTile(title: const Text('Email'), trailing: Text(e.email!)),
                    ],
                    if (e.phone != null) ...[
                      const Divider(height: 1),
                      ListTile(title: const Text('Phone'), trailing: Text(e.phone!)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _ChangePasswordDialog()),
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('Change Password'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                icon: const Icon(Icons.logout, color: PharcoColors.danger),
                label: const Text('Sign Out', style: TextStyle(color: PharcoColors.danger)),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load profile: $e')),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).changePassword(_newPasswordController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    } catch (e) {
      setState(() => _error = 'Could not change password: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) {
                  if (v == null || v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                validator: (v) => (v != _newPasswordController.text) ? 'Passwords do not match' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: PharcoColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
