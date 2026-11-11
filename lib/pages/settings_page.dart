import 'package:flutter/material.dart' hide Ink;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_version_service.dart';
import '../services/youtube_music_service.dart';
import '../sketch.dart';
import '../state.dart';
import '../widgets/privacy_lock_widgets.dart';
import '../widgets/suggestion_dialog.dart';
import '../widgets/youtube_login_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ImagePicker _picker = ImagePicker();
  bool _uploadingAvatar = false;

  Future<void> _changeProfileImage(BuildContext context) async {
    Uint8List? stagedBytes = app.avatarMemoryBytes;
    String? stagedExt;
    String? stagedUrl = app.avatarUrl;
    var stagedHatch = app.avatarHatch;
    var pickedNewPhoto = false;
    var removedPhoto = false;
    var saving = false;
    String? errorText;

    await showSketchDialog<void>(
      context,
      (c) => StatefulBuilder(
        builder: (c, setDialogState) {
          final hasPhoto = !removedPhoto &&
              (stagedBytes != null || (stagedUrl != null && stagedUrl!.isNotEmpty));

          Future<void> pickStagedImage(ImageSource source) async {
            if (saving) return;
            try {
              final picked = await _picker.pickImage(
                source: source,
                maxWidth: 720,
                maxHeight: 720,
                imageQuality: 84,
              );
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              if (bytes.lengthInBytes > 5 * 1024 * 1024) {
                if (c.mounted) {
                  setDialogState(() => errorText = 'image must be smaller than 5 MB.');
                }
                return;
              }
              final nameParts = picked.name.split('.');
              final ext = nameParts.length > 1 ? nameParts.last : 'jpg';
              if (c.mounted) {
                setDialogState(() {
                  stagedBytes = bytes;
                  stagedExt = ext;
                  pickedNewPhoto = true;
                  removedPhoto = false;
                  errorText = null;
                });
              }
            } on PlatformException catch (e) {
              if (c.mounted) {
                setDialogState(
                  () => errorText = e.message ?? 'couldn\'t access camera/photos.',
                );
              }
            } catch (_) {
              if (c.mounted) {
                setDialogState(() => errorText = 'couldn\'t load selected image.');
              }
            }
          }

          return SketchDialogCard(
            title: 'profile portrait',
            body: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    _ProfileAvatarBox(
                      size: 64,
                      uploading: saving,
                      usePreview: true,
                      previewBytes: removedPhoto ? null : stagedBytes,
                      previewUrl: removedPhoto ? null : stagedUrl,
                      previewHatch: stagedHatch,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.name.toUpperCase(), style: T.head(16)),
                          Text(app.handle, style: T.body(14, c: Ink.soft)),
                          const SizedBox(height: 2),
                          Note(
                            hasPhoto
                                ? (pickedNewPhoto ? 'new photo staged' : 'custom photo active')
                                : 'sketch hatch: ${stagedHatch.name}',
                            size: 13,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('UPLOAD PHOTO', style: T.head(12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SketchTap(
                        onTap: () => pickStagedImage(ImageSource.gallery),
                        child: SketchBox(
                          shadow: false,
                          seed: 41,
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.photo_library_outlined, size: 16, color: Ink.ink),
                              const SizedBox(width: 6),
                              Text('GALLERY', style: T.head(12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SketchTap(
                        onTap: () => pickStagedImage(ImageSource.camera),
                        child: SketchBox(
                          shadow: false,
                          seed: 43,
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.photo_camera_outlined, size: 16, color: Ink.ink),
                              const SizedBox(width: 6),
                              Text('CAMERA', style: T.head(12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasPhoto) ...[
                  const SizedBox(height: 8),
                  SketchTap(
                    onTap: () {
                      setDialogState(() {
                        stagedBytes = null;
                        stagedUrl = null;
                        pickedNewPhoto = false;
                        removedPhoto = true;
                        errorText = null;
                      });
                    },
                    child: SketchBox(
                      shadow: false,
                      dashed: true,
                      seed: 47,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Center(
                        child: Text('remove photo & use sketch hatch', style: T.note(14)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text('OR PICK SKETCH HATCH', style: T.head(12)),
                const SizedBox(height: 6),
                ClipRect(
                  clipBehavior: Clip.hardEdge,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.hardEdge,
                    child: Row(
                      children: [
                      for (final h in Hatch.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                stagedHatch = h;
                                stagedBytes = null;
                                stagedUrl = null;
                                pickedNewPhoto = false;
                                removedPhoto = true;
                                errorText = null;
                              });
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: (!hasPhoto && stagedHatch == h)
                                          ? Ink.ink
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: HatchSwatch(h, size: 38, gap: 4),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  h.name,
                                  style: T.body(
                                    11,
                                    c: (!hasPhoto && stagedHatch == h) ? Ink.ink : Ink.soft,
                                    w: (!hasPhoto && stagedHatch == h)
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  SketchBox(
                    shadow: false,
                    dashed: true,
                    fill: Ink.bg,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 15, color: Ink.ink),
                        const SizedBox(width: 6),
                        Expanded(child: Text(errorText!, style: T.body(13))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
            actions: [
              SketchTextButton(
                'cancel',
                onTap: saving ? () {} : () => Navigator.pop(c),
              ),
              SketchTextButton(
                saving ? 'updating...' : 'update',
                primary: true,
                onTap: () async {
                  if (saving) return;
                  setDialogState(() {
                    saving = true;
                    errorText = null;
                  });
                  if (mounted) {
                    setState(() => _uploadingAvatar = true);
                  }
                  try {
                    if (pickedNewPhoto && stagedBytes != null) {
                      if (stagedHatch != app.avatarHatch) {
                        app.setAvatarHatch(stagedHatch);
                      }
                      final err = await app.uploadAvatarBytes(
                        stagedBytes!,
                        stagedExt ?? 'jpg',
                      );
                      if (!c.mounted) return;
                      Navigator.pop(c);
                      if (context.mounted) {
                        showNote(context, err ?? 'profile photo updated ✓');
                      }
                    } else if (removedPhoto) {
                      await app.removeAvatarPhoto();
                      app.setAvatarHatch(stagedHatch, clearPhoto: true);
                      if (!c.mounted) return;
                      Navigator.pop(c);
                      if (context.mounted) {
                        showNote(context, 'sketch avatar updated ✓');
                      }
                    } else if (stagedHatch != app.avatarHatch) {
                      app.setAvatarHatch(stagedHatch);
                      if (!c.mounted) return;
                      Navigator.pop(c);
                      if (context.mounted) {
                        showNote(context, 'sketch avatar updated ✓');
                      }
                    } else {
                      Navigator.pop(c);
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _uploadingAvatar = false);
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editUsernameAndName(BuildContext context) async {
    final nameCtl = TextEditingController(text: app.name);
    final rawHandle = app.handle.startsWith('@') ? app.handle.substring(1) : app.handle;
    final handleCtl = TextEditingController(text: rawHandle);
    String? errorText;
    var saving = false;

    await showSketchDialog<void>(
      context,
      (c) => StatefulBuilder(
        builder: (c, setDialogState) => SketchDialogCard(
          title: 'edit username & name',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DIRECTOR NAME', style: T.head(12)),
              const SizedBox(height: 4),
              SketchBox(
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: TextField(
                  controller: nameCtl,
                  autofocus: true,
                  style: T.body(16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'maya',
                    hintStyle: T.body(15, c: Ink.faint),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('USERNAME (@HANDLE)', style: T.head(12)),
              const SizedBox(height: 4),
              SketchBox(
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Row(
                  children: [
                    Text('@', style: T.head(16, c: Ink.soft)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: handleCtl,
                        autocorrect: false,
                        style: T.body(16),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'maya_402',
                          hintStyle: T.body(15, c: Ink.faint),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Note('2–20 lowercase letters, numbers, or underscores', size: 13),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                SketchBox(
                  shadow: false,
                  dashed: true,
                  fill: Ink.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 15, color: Ink.ink),
                      const SizedBox(width: 6),
                      Expanded(child: Text(errorText!, style: T.body(13))),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            SketchTextButton('cancel', onTap: saving ? () {} : () => Navigator.pop(c)),
            SketchTextButton(
              saving ? 'saving...' : 'save',
              primary: true,
              onTap: () async {
                if (saving) return;
                setDialogState(() {
                  saving = true;
                  errorText = null;
                });
                final err = await app.updateProfile(
                  displayName: nameCtl.text,
                  handleInput: handleCtl.text,
                );
                if (!c.mounted) return;
                if (err != null) {
                  setDialogState(() {
                    saving = false;
                    errorText = err;
                  });
                  return;
                }
                Navigator.pop(c);
                if (context.mounted) {
                  showNote(context, 'updated to ${app.name} (${app.handle}) ✓');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    if (app.demoMode || app.user == null) {
      showNote(context, 'sign in to an account to change your password');
      return;
    }

    final passCtl = TextEditingController();
    final confirmCtl = TextEditingController();
    var obscure1 = true;
    var obscure2 = true;
    var saving = false;
    String? errorText;

    await showSketchDialog<void>(
      context,
      (c) => StatefulBuilder(
        builder: (c, setDialogState) => SketchDialogCard(
          title: 'change password',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEW PASSWORD', style: T.head(12)),
              const SizedBox(height: 4),
              SketchBox(
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: passCtl,
                        obscureText: obscure1,
                        autofocus: true,
                        style: T.body(15),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'at least 6 characters',
                          hintStyle: T.body(14, c: Ink.faint),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setDialogState(() => obscure1 = !obscure1),
                      child: Icon(
                        obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: Ink.soft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('CONFIRM NEW PASSWORD', style: T.head(12)),
              const SizedBox(height: 4),
              SketchBox(
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: confirmCtl,
                        obscureText: obscure2,
                        style: T.body(15),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 're-enter new password',
                          hintStyle: T.body(14, c: Ink.faint),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setDialogState(() => obscure2 = !obscure2),
                      child: Icon(
                        obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: Ink.soft,
                      ),
                    ),
                  ],
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                SketchBox(
                  shadow: false,
                  dashed: true,
                  fill: Ink.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 15, color: Ink.ink),
                      const SizedBox(width: 6),
                      Expanded(child: Text(errorText!, style: T.body(13))),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            SketchTextButton('cancel', onTap: saving ? () {} : () => Navigator.pop(c)),
            SketchTextButton(
              saving ? 'saving...' : 'update',
              primary: true,
              onTap: () async {
                if (saving) return;
                final p = passCtl.text;
                if (p.length < 6) {
                  setDialogState(() => errorText = 'password must be at least 6 characters.');
                  return;
                }
                if (p != confirmCtl.text) {
                  setDialogState(() => errorText = 'passwords do not match.');
                  return;
                }
                setDialogState(() {
                  saving = true;
                  errorText = null;
                });
                try {
                  await app.updatePassword(p);
                  if (!c.mounted) return;
                  Navigator.pop(c);
                  if (context.mounted) {
                    showNote(context, 'password updated ✓');
                  }
                } catch (e) {
                  if (!c.mounted) return;
                  setDialogState(() {
                    saving = false;
                    errorText = 'couldn\'t update password – try signing in again.';
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) => showSketchDialog<void>(
        context,
        (c) => SketchDialogCard(
          title: app.demoMode ? 'exit demo reel?' : 'leave the set?',
          body: Text(
            app.demoMode
                ? 'head back to the ticket booth to sign in or register your own reel.'
                : 'your scenes stay safe in Supabase. you can sign back in anytime.',
            style: T.body(15),
          ),
          actions: [
            SketchTextButton('stay', onTap: () => Navigator.pop(c)),
            SketchTextButton(
              app.demoMode ? 'ticket booth' : 'log out',
              primary: true,
              onTap: () async {
                Navigator.pop(c);
                try {
                  await app.signOut();
                } catch (_) {
                  if (context.mounted) {
                    showNote(context, 'couldn\'t sign out – try again');
                  }
                }
              },
            ),
          ],
        ),
      );

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final isDemo = app.demoMode;
    final confirmCtl = TextEditingController();
    var deleting = false;
    String? errorText;

    await showSketchDialog<void>(
      context,
      (c) => StatefulBuilder(
        builder: (c, setDialogState) => SketchDialogCard(
          title: isDemo ? 'reset demo reel?' : 'delete your account?',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDemo
                    ? 'this permanently erases all ${app.sceneCount} sketched scenes and settings, and returns you to the ticket booth. this cannot be undone.'
                    : 'this permanently erases your profile (${app.handle}), all ${app.sceneCount} saved scenes, and co-star connections. this cannot be undone.',
                style: T.body(14),
              ),
              const SizedBox(height: 12),
              Text('TYPE "DELETE" TO CONFIRM', style: T.head(12)),
              const SizedBox(height: 4),
              SketchBox(
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: TextField(
                  controller: confirmCtl,
                  autofocus: true,
                  autocorrect: false,
                  style: T.body(15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'DELETE',
                    hintStyle: T.body(14, c: Ink.faint),
                  ),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!, style: T.note(13, c: const Color(0xFFB03A2E))),
              ],
            ],
          ),
          actions: [
            SketchTextButton('keep reel', onTap: deleting ? () {} : () => Navigator.pop(c)),
            SketchTextButton(
              deleting ? 'deleting...' : (isDemo ? 'reset reel' : 'delete forever'),
              primary: true,
              onTap: () async {
                if (deleting) return;
                if (confirmCtl.text.trim().toUpperCase() != 'DELETE') {
                  setDialogState(() => errorText = 'type DELETE in the box above to confirm.');
                  return;
                }
                setDialogState(() {
                  deleting = true;
                  errorText = null;
                });
                try {
                  await app.deleteAccount();
                  if (c.mounted) {
                    Navigator.of(c, rootNavigator: true).pop();
                    showNote(
                      context,
                      isDemo
                          ? 'demo reel reset · ticket booth ready'
                          : 'account permanently deleted · reel closed',
                    );
                  }
                } catch (e) {
                  if (c.mounted) {
                    setDialogState(() {
                      deleting = false;
                      errorText = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enablePrivacyLockDialog(BuildContext context) async {
    final pin1Ctl = TextEditingController();
    final pin2Ctl = TextEditingController();
    String? errorText;
    var step = 1;

    await showSketchDialog<void>(
      context,
      (c) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isStep1 = step == 1;
          final ctl = isStep1 ? pin1Ctl : pin2Ctl;

          void onDigit(String d) {
            if (ctl.text.length < 4) {
              setDialogState(() {
                ctl.text = '${ctl.text}$d';
                errorText = null;
                if (ctl.text.length == 4) {
                  if (isStep1) {
                    step = 2;
                  } else {
                    if (pin1Ctl.text == pin2Ctl.text) {
                      app.setPrivacyPin(pin1Ctl.text);
                      Navigator.pop(c);
                      showNote(context, 'privacy lock activated with 4-digit PIN ✓');
                    } else {
                      errorText = 'pins do not match · please try again';
                      pin2Ctl.clear();
                    }
                  }
                }
              });
            }
          }

          void onBackspace() {
            if (ctl.text.isNotEmpty) {
              setDialogState(() {
                ctl.text = ctl.text.substring(0, ctl.text.length - 1);
                errorText = null;
              });
            } else if (!isStep1) {
              setDialogState(() {
                step = 1;
                pin2Ctl.clear();
                errorText = null;
              });
            }
          }

          return SketchDialogCard(
            title: isStep1 ? 'set 4-digit pin' : 'confirm 4-digit pin',
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Note(
                  isStep1
                      ? 'choose a 4-digit code to protect your diary'
                      : 're-enter your 4-digit code to confirm',
                  size: 14,
                ),
                const SizedBox(height: 14),
                SketchPinDots(pinLength: ctl.text.length),
                SizedBox(
                  height: 20,
                  child: Center(
                    child: errorText != null
                        ? Text(errorText!, style: T.note(13, c: Ink.ink))
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 8),
                SketchNumpad(
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                  onClear: () => setDialogState(() {
                    ctl.clear();
                    errorText = null;
                  }),
                ),
              ],
            ),
            actions: [
              SketchTextButton('cancel', onTap: () => Navigator.pop(c)),
              if (!isStep1)
                SketchTextButton(
                  'back',
                  onTap: () {
                    setDialogState(() {
                      step = 1;
                      pin2Ctl.clear();
                      errorText = null;
                    });
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _disablePrivacyLockDialog(BuildContext context) async {
    final ctl = TextEditingController();
    String? errorText;

    await showSketchDialog<void>(
      context,
      (c) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void onDigit(String d) {
            if (ctl.text.length < 4) {
              setDialogState(() {
                ctl.text = '${ctl.text}$d';
                errorText = null;
                if (ctl.text.length == 4) {
                  if (app.verifyAndUnlock(ctl.text)) {
                    app.disablePrivacyLock();
                    Navigator.pop(c);
                    showNote(context, 'privacy lock disabled ✓');
                  } else {
                    errorText = 'incorrect pin · try again';
                    ctl.clear();
                  }
                }
              });
            }
          }

          void onBackspace() {
            if (ctl.text.isNotEmpty) {
              setDialogState(() {
                ctl.text = ctl.text.substring(0, ctl.text.length - 1);
                errorText = null;
              });
            }
          }

          return SketchDialogCard(
            title: 'disable privacy lock',
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Note('enter your 4-digit pin to turn off lock', size: 14),
                const SizedBox(height: 14),
                SketchPinDots(pinLength: ctl.text.length),
                SizedBox(
                  height: 20,
                  child: Center(
                    child: errorText != null
                        ? Text(errorText!, style: T.note(13, c: Ink.ink))
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 8),
                SketchNumpad(
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                  onClear: () => setDialogState(() {
                    ctl.clear();
                    errorText = null;
                  }),
                ),
              ],
            ),
            actions: [
              SketchTextButton('cancel', onTap: () => Navigator.pop(c)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changePrivacyPinDialog(BuildContext context) async {
    final oldCtl = TextEditingController();
    final new1Ctl = TextEditingController();
    final new2Ctl = TextEditingController();
    String? errorText;
    var step = 1;

    await showSketchDialog<void>(
      context,
      (c) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final ctl = step == 1 ? oldCtl : (step == 2 ? new1Ctl : new2Ctl);
          final stepTitle = switch (step) {
            1 => 'current 4-digit pin',
            2 => 'new 4-digit pin',
            _ => 'confirm new pin',
          };
          final stepSubtitle = switch (step) {
            1 => 'enter your current 4-digit pin',
            2 => 'choose your new 4-digit code',
            _ => 're-enter your new code to confirm',
          };

          void onDigit(String d) {
            if (ctl.text.length < 4) {
              setDialogState(() {
                ctl.text = '${ctl.text}$d';
                errorText = null;
                if (ctl.text.length == 4) {
                  if (step == 1) {
                    if (app.verifyAndUnlock(oldCtl.text)) {
                      step = 2;
                    } else {
                      errorText = 'incorrect current pin · try again';
                      oldCtl.clear();
                    }
                  } else if (step == 2) {
                    step = 3;
                  } else {
                    if (new1Ctl.text == new2Ctl.text) {
                      app.changePrivacyPin(oldCtl.text, new1Ctl.text);
                      Navigator.pop(c);
                      showNote(context, '4-digit PIN changed successfully ✓');
                    } else {
                      errorText = 'new pins do not match · please retry';
                      new2Ctl.clear();
                    }
                  }
                }
              });
            }
          }

          void onBackspace() {
            if (ctl.text.isNotEmpty) {
              setDialogState(() {
                ctl.text = ctl.text.substring(0, ctl.text.length - 1);
                errorText = null;
              });
            } else if (step > 1) {
              setDialogState(() {
                step -= 1;
                errorText = null;
              });
            }
          }

          return SketchDialogCard(
            title: stepTitle,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Note(stepSubtitle, size: 14),
                const SizedBox(height: 14),
                SketchPinDots(pinLength: ctl.text.length),
                SizedBox(
                  height: 20,
                  child: Center(
                    child: errorText != null
                        ? Text(errorText!, style: T.note(13, c: Ink.ink))
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 8),
                SketchNumpad(
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                  onClear: () => setDialogState(() {
                    ctl.clear();
                    errorText = null;
                  }),
                ),
              ],
            ),
            actions: [
              SketchTextButton('cancel', onTap: () => Navigator.pop(c)),
              if (step > 1)
                SketchTextButton(
                  'back',
                  onTap: () {
                    setDialogState(() {
                      step -= 1;
                      errorText = null;
                    });
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleReminder(BuildContext context, bool enable) async {
    final ok = await app.setDailyReminder(enable);
    if (!context.mounted) return;
    if (!ok) {
      showNote(context, 'notifications are blocked – allow them in system settings.');
    } else if (enable) {
      showNote(context, 'daily reminder set for ${app.reminderTimeLabel} ✓');
    } else {
      showNote(context, 'daily reminder turned off');
    }
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    var hour12 = app.reminderHour % 12 == 0 ? 12 : app.reminderHour % 12;
    var minute = app.reminderMinute;
    var isPm = app.reminderHour >= 12;

    int to24() => (hour12 % 12) + (isPm ? 12 : 0);

    Widget stepper(String label, String value, VoidCallback onUp, VoidCallback onDown, int seed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SketchTap(
            onTap: onUp,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.keyboard_arrow_up, size: 26, color: Ink.ink),
            ),
          ),
          SketchBox(
            seed: seed,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(value, style: T.head(32)),
          ),
          SketchTap(
            onTap: onDown,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.keyboard_arrow_down, size: 26, color: Ink.ink),
            ),
          ),
          Note(label, size: 12),
        ],
      );
    }

    final result = await showSketchDialog<(int, int)>(
      context,
      (c) => StatefulBuilder(
        builder: (ctx, setDlg) => SketchDialogCard(
          title: 'reminder time',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Note('when should the director nudge you?', size: 14),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  stepper(
                    'hour',
                    hour12.toString().padLeft(2, '0'),
                    () => setDlg(() => hour12 = hour12 % 12 + 1),
                    () => setDlg(() => hour12 = hour12 == 1 ? 12 : hour12 - 1),
                    61,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(':', style: T.head(32)),
                  ),
                  stepper(
                    'minute',
                    minute.toString().padLeft(2, '0'),
                    () => setDlg(() => minute = (minute + 5) % 60),
                    () => setDlg(() => minute = (minute - 5 + 60) % 60),
                    62,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final pm in const [false, true])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: SketchTap(
                            onTap: () => setDlg(() => isPm = pm),
                            child: SketchBox(
                              seed: pm ? 64 : 63,
                              shadow: false,
                              fill: isPm == pm ? Ink.ink : Ink.paper,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              child: Text(
                                pm ? 'PM' : 'AM',
                                style: T.head(15, c: isPm == pm ? Ink.paper : Ink.ink),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Note('quick picks', size: 13),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (h, m, label) in const [
                    (8, 0, 'morning 8:00'),
                    (13, 0, 'lunch 1:00'),
                    (18, 30, 'sunset 6:30'),
                    (21, 0, 'night 9:00'),
                    (23, 0, 'late 11:00'),
                  ])
                    SketchTap(
                      onTap: () => setDlg(() {
                        hour12 = h % 12 == 0 ? 12 : h % 12;
                        minute = m;
                        isPm = h >= 12;
                      }),
                      child: SketchBox(
                        seed: 70 + h,
                        shadow: false,
                        dashed: to24() != h || minute != m,
                        fill: (to24() == h && minute == m) ? Ink.ink : Ink.paper,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          label,
                          style: T.body(
                            13,
                            c: (to24() == h && minute == m) ? Ink.paper : Ink.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            SketchTextButton('cancel', onTap: () => Navigator.pop(c)),
            SketchTextButton(
              'set time',
              primary: true,
              onTap: () => Navigator.pop(c, (to24(), minute)),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final ok = await app.setReminderTime(result.$1, result.$2);
    if (context.mounted) {
      showNote(
        context,
        ok
            ? 'reminder moved to ${app.reminderTimeLabel} ✓'
            : 'notifications are blocked – allow them in system settings.',
      );
    }
  }

  Future<void> _handleYouTubeAuth(BuildContext context) async {
    if (musicService.isYouTubeConnected) {
      await showSketchDialog<void>(
        context,
        (c) => SketchDialogCard(
          title: 'YouTube session',
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 20, color: Ink.ink),
                  const SizedBox(width: 8),
                  Text('ACTIVE SESSION', style: T.head(16)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'your Google/YouTube session cookies are active on this device. requests carry your authenticated credentials to bypass YouTube bot blocks and rate limits.',
                style: T.body(14, c: Ink.soft),
              ),
            ],
          ),
          actions: [
            SketchTextButton('keep active', onTap: () => Navigator.pop(c)),
            SketchTextButton(
              'disconnect',
              primary: true,
              onTap: () async {
                await musicService.disconnectYouTube();
                if (c.mounted) Navigator.pop(c);
                if (context.mounted) {
                  showNote(context, 'YouTube session disconnected');
                }
              },
            ),
          ],
        ),
      );
    } else {
      final cookies = await Navigator.push<String>(
        context,
        MaterialPageRoute<String>(
          builder: (_) => const YouTubeLoginSheet(),
        ),
      );
      if (cookies != null && cookies.isNotEmpty) {
        await musicService.connectYouTube(cookies);
        if (context.mounted) {
          showNote(context, 'YouTube account connected · bot blocks resolved ✓');
        }
      }
    }
  }

  Future<void> _about(BuildContext context) => showSketchDialog<void>(
        context,
        (c) => SketchDialogCard(
          title: 'about this film',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'IF MY LIFE WAS A MOVIE...',
                style: T.head(18),
              ),
              const SizedBox(height: 3),
              const Note('daily soundtrack diary', size: 14),
              const SizedBox(height: 10),
              Text(
                'one song a day. one tiny scene. over time your life becomes a soundtrack you can scroll through.',
                style: T.body(15),
              ),
              const SizedBox(height: 12),
              const DashedLine(),
              const SizedBox(height: 10),
              Text(
                'CREDITS',
                style: T.head(12, c: Ink.soft),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: 'Directed & Developed by ', style: T.body(14)),
                    TextSpan(text: 'zakialmahdi\n', style: T.head(15)),
                    TextSpan(
                      text: 'lone developer',
                      style: T.note(13, c: Ink.soft),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Note(
                'v${AppVersionService.kFallbackVersion} – crafted with pencil, code & too much coffee.',
                size: 13,
              ),
            ],
          ),
          actions: [
            SketchTextButton('roll credits', primary: true, onTap: () => Navigator.pop(c)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        var i = 0;
        Widget r(Widget w) => Reveal(index: i++, child: w);

        return ListView(
          addRepaintBoundaries: false,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            r(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Note('backstage', size: 15),
              const SizedBox(height: 2),
              Text('SETTINGS', style: T.head(27)),
            ])),
            const SizedBox(height: 14),

            // ── Director Profile Card
            r(SketchBox(
              seed: 71,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _changeProfileImage(context),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _ProfileAvatarBox(size: 60, uploading: _uploadingAvatar),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Ink.ink,
                                  border: Border.all(color: Ink.paper, width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 13,
                                  color: Ink.paper,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _editUsernameAndName(context),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      app.name.toUpperCase(),
                                      style: T.head(19),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.edit_outlined, size: 15, color: Ink.soft),
                                ],
                              ),
                              Text(
                                '${app.handle} · ${app.email ?? 'offline demo reel'}',
                                style: T.body(13, c: Ink.soft),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Note(
                                '${app.sceneCount} scenes · ${app.streak}-day streak',
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(height: 1, color: Ink.faint),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Note('invite ticket: ${app.inviteCode}', size: 14),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: app.inviteCode));
                          showNote(context, 'copied ticket code ${app.inviteCode} ✓');
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.copy_outlined, size: 13, color: Ink.ink),
                            const SizedBox(width: 4),
                            Text('COPY CODE', style: T.head(11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),

            const SizedBox(height: 18),

            // ── Account Settings Section
            r(const SectionTitle('Account')),
            r(_navRow(
              Icons.portrait_outlined,
              'Change profile image',
              'upload a photo or pick a sketch hatch',
              73,
              () => _changeProfileImage(context),
            )),
            r(_navRow(
              Icons.alternate_email,
              'Change username & name',
              '${app.name} (${app.handle})',
              75,
              () => _editUsernameAndName(context),
            )),
            r(_navRow(
              Icons.lock_outline,
              'Change password',
              app.demoMode ? 'sign in to manage password' : 'update your account password',
              77,
              () => _changePassword(context),
            )),

            const SizedBox(height: 10),
            r(const SectionTitle('The rules')),
            r(_ruleRow('Daily reminder', 'pick today\'s song at ${app.reminderTimeLabel}', app.dailyReminder, 'reminder', 1)),
            if (app.dailyReminder)
              r(_navRow(
                Icons.alarm_outlined,
                'Reminder time',
                'nudge me at ${app.reminderTimeLabel} · skipped if today\'s scene is saved',
                78,
                () => _pickReminderTime(context),
              )),
            r(_ruleRow('Mood prompts', 'little questions before you save', app.moodPrompts, 'prompts', 2)),
            r(_ruleRow('Privacy lock', 'keep the diary to yourself', app.privacyLock, 'lock', 3)),
            if (app.privacyLock)
              r(_navRow(
                Icons.pin_outlined,
                'Change 4-digit PIN',
                'update your diary lock code',
                79,
                () => _changePrivacyPinDialog(context),
              )),

            const SizedBox(height: 10),
            r(const SectionTitle('Sketch paper')),
            r(Row(children: [
              for (final p in const ['plain', 'lined', 'grid'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _Tile(
                      label: p,
                      selected: app.paper == p,
                      onTap: () => app.setPaper(p),
                    ),
                  ),
                ),
            ])),

            const SizedBox(height: 10),
            r(const SectionTitle('Soundtrack playback & stream')),
            r(ListenableBuilder(
              listenable: musicService,
              builder: (context, _) {
                final isConnected = musicService.isYouTubeConnected;
                return _navRow(
                  isConnected
                      ? Icons.check_circle_outline
                      : Icons.smart_display_outlined,
                  isConnected
                      ? 'YouTube session connected ✓'
                      : 'Connect YouTube session',
                  isConnected
                      ? 'authenticated cookies active · bot-detection bypassed'
                      : 'sign in to bypass rate limits & 403 playback blocks',
                  83,
                  () => _handleYouTubeAuth(context),
                );
              },
            )),

            const SizedBox(height: 14),
            r(const SectionTitle('More')),
            r(_navRow(
              Icons.lightbulb_outline,
              'Suggest a feature / feedback',
              'send ideas directly to lone dev zakialmahdi',
              80,
              () => showSuggestionDialog(context),
            )),
            r(_navRow(
              Icons.auto_stories_outlined,
              'How this app works',
              'Story guide & YouTube setup carousel',
              81,
              () => context.push('/intro?replay=true'),
            )),
            r(_navRow(
              Icons.help_outline,
              'About this app',
              'IF MY LIFE WAS A MOVIE... · dev: zakialmahdi',
              82,
              () => _about(context),
            )),

            const SizedBox(height: 14),
            r(const SectionTitle('Session & danger zone')),
            r(Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SketchTap(
                onTap: () => _logout(context),
                child: SketchBox(
                  seed: 82,
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_outlined, size: 17, color: Ink.ink),
                      const SizedBox(width: 8),
                      Text(
                        app.demoMode ? 'BACK TO SIGN IN' : 'LOG OUT',
                        style: T.head(14),
                      ),
                    ],
                  ),
                ),
              ),
            )),
            if (!app.demoMode && app.user != null)
              r(Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SketchTap(
                  onTap: () => _confirmDeleteAccount(context),
                  child: SketchBox(
                    seed: 88,
                    shadow: false,
                    dashed: true,
                    fill: Ink.bg,
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_forever_outlined, size: 18, color: Ink.ink),
                        const SizedBox(width: 8),
                        Text('DELETE ACCOUNT', style: T.head(13)),
                      ],
                    ),
                  ),
                ),
              )),

            r(Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'IF MY LIFE WAS A MOVIE...',
                    style: T.head(13, c: Ink.soft),
                  ),
                  const SizedBox(height: 2),
                  const Note(
                    'lone developer: zakialmahdi · v${AppVersionService.kFallbackVersion}',
                    size: 14,
                  ),
                ],
              ),
            )),
          ],
        );
      },
    );
  }

  Widget _ruleRow(String title, String sub, bool on, String key, int seed) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SketchTap(
          onTap: () {
            if (key == 'lock') {
              if (on) {
                _disablePrivacyLockDialog(context);
              } else {
                _enablePrivacyLockDialog(context);
              }
            } else if (key == 'reminder') {
              _toggleReminder(context, !on);
            } else {
              app.toggle(key);
            }
          },
          pressedScale: .97,
          child: SketchBox(
            seed: 90 + seed,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: T.body(16)),
                  Note(sub, size: 13),
                ]),
              ),
              SketchSwitch(on),
            ]),
          ),
        ),
      );

  Widget _navRow(
    IconData icon,
    String label,
    String subtitle,
    int seed,
    VoidCallback onTap,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SketchTap(
          onTap: onTap,
          pressedScale: .97,
          child: SketchBox(
            seed: seed,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 20, color: Ink.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: T.body(16)),
                    Note(subtitle, size: 13),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Ink.soft),
            ]),
          ),
        ),
      );
}

class _ProfileAvatarBox extends StatelessWidget {
  final double size;
  final bool uploading;
  final bool usePreview;
  final Uint8List? previewBytes;
  final String? previewUrl;
  final Hatch? previewHatch;

  const _ProfileAvatarBox({
    required this.size,
    this.uploading = false,
    this.usePreview = false,
    this.previewBytes,
    this.previewUrl,
    this.previewHatch,
  });

  @override
  Widget build(BuildContext context) {
    final mem = usePreview ? previewBytes : app.avatarMemoryBytes;
    final url = usePreview ? previewUrl : app.avatarUrl;
    final hatch = usePreview ? (previewHatch ?? app.avatarHatch) : app.avatarHatch;

    Widget inner;
    if (mem != null) {
      inner = Image.memory(
        mem,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (url != null && url.isNotEmpty) {
      inner = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackHatch(hatch),
      );
    } else {
      inner = _fallbackHatch(hatch);
    }

    return SketchBox(
      shadow: false,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: inner),
            if (uploading)
              Container(
                color: Ink.paper.withAlpha(200),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Ink.ink,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackHatch(Hatch hatch) {
    final innerBox = (size * 0.64).roundToDouble();
    return Stack(
      alignment: Alignment.center,
      children: [
        HatchSwatch(hatch, size: size, gap: 4),
        Container(
          width: innerBox,
          height: innerBox,
          color: Ink.paper,
          child: Icon(Icons.person, size: size * 0.48, color: Ink.ink),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SketchTap(
      onTap: onTap,
      pressedScale: .94,
      child: SketchBox(
        seed: label.hashCode,
        fill: selected ? Ink.ink : Ink.paper,
        shadow: selected,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          heightFactor: 1,
          child: Text(
            label,
            style: T.body(
              14,
              c: selected ? Ink.paper : Ink.ink,
              w: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
