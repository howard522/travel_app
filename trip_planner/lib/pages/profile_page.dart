// lib/pages/profile_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../providers/profile_providers.dart';
import '../providers/auth_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl         = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _countryCtrl     = TextEditingController();

  bool _loading = false;
  String _selectedGender = ''; // Male / Female / Other / empty

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (img == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepoProvider).uploadAvatar(File(img.path));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('上傳失敗：$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile(UserProfile profile) async {
    setState(() => _loading = true);
    try {
      final newName    = _displayNameCtrl.text.trim();
      final newBio     = _bioCtrl.text.trim();
      final newPhone   = _phoneCtrl.text.trim();
      final newGender  = _selectedGender;
      final newCountry = _countryCtrl.text.trim();

      await ref.read(authRepoProvider).updateUserProfile(
            displayName: newName  != profile.displayName ? newName  : null,
            bio        : newBio   != profile.bio         ? newBio   : null,
            phone      : newPhone != profile.phone       ? newPhone : null,
            gender     : newGender != profile.gender     ? newGender : null,
            country    : newCountry != profile.country   ? newCountry : null,
          );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已更新個人資料')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('個人資料')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗：$e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('找不到使用者資料'));
          }
          // 預填
          _displayNameCtrl.text = profile.displayName;
          _bioCtrl.text         = profile.bio;
          _phoneCtrl.text       = profile.phone;
          _countryCtrl.text     = profile.country;
          _selectedGender       = profile.gender;

          return AbsorbPointer(
            absorbing: _loading,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: profile.photoURL.isNotEmpty
                          ? NetworkImage(profile.photoURL)
                          : null,
                      child: profile.photoURL.isEmpty
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _pickAvatar,
                    child: const Text('更換頭像'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _displayNameCtrl,
                    decoration: const InputDecoration(labelText: '顯示名稱'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bioCtrl,
                    decoration: const InputDecoration(labelText: '個人簡介'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: '電話'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  // 新增：性別欄位
                  DropdownButtonFormField<String>(
                    value: _selectedGender.isEmpty ? null : _selectedGender,
                    decoration: const InputDecoration(labelText: '性別'),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('男')),
                      DropdownMenuItem(value: 'Female', child: Text('女')),
                      DropdownMenuItem(value: 'Other', child: Text('其他')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedGender = v ?? '';
                      });
                    },
                    isExpanded: true,
                    hint: const Text('請選擇性別'),
                  ),
                  const SizedBox(height: 12),
                  // 新增：國家欄位
                  TextFormField(
                    controller: _countryCtrl,
                    decoration: const InputDecoration(labelText: '國家'),
                  ),
                  const SizedBox(height: 24),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: () => _saveProfile(profile),
                          child: const Text('儲存'),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
