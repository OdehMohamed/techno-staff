import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthCubit>().signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 600 ? 420.0 : double.infinity;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          Navigator.pushReplacementNamed(context, RouteNames.dashboard);
        }

        if (state.status == AuthStatus.error && state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text('login'.tr())),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('welcome_back'.tr(), style: textTheme.headlineMedium),
                    const SizedBox(height: AppSizes.lg),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'email'.tr()),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'email_required'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSizes.md),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: 'password'.tr()),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'password_required'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSizes.lg),
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        final isLoading = state.status == AuthStatus.loading;

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submitLogin,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('login'.tr()),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
