import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String _initialName = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialName = context.read<AuthCubit>().state.user?.name ?? '';
    _nameController = TextEditingController(text: _initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _nameController.text.trim() != _initialName.trim();

  bool get _canSave =>
      _isDirty && (_formKey.currentState?.validate() ?? false);

  Future<void> _handleSave() async {
    if (!_canSave) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final cubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await cubit.updateName(_nameController.text.trim());
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('profile_updated'.tr())),
      );
      navigator.pop();
    } catch (_) {
      if (!context.mounted) return;
      setState(() => _isLoading = false);
      final errorKey = cubit.state.errorMessage ?? 'failed_to_update_profile';
      messenger.showSnackBar(
        SnackBar(content: Text(errorKey.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == AuthStatus.unauthenticated,
      listener: (context, state) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('edit_profile'.tr())),
        body: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'name'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSave(),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) return 'name_required'.tr();
                    if (trimmed.length < 2) return 'name_too_short'.tr();
                    if (trimmed.length > 50) return 'name_too_long'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.lg),
                FilledButton(
                  onPressed: (_isLoading || !_canSave) ? null : _handleSave,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('save'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
