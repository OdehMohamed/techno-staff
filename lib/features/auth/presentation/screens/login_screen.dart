import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('login'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('welcome_back'.tr(), style: textTheme.headlineMedium),
            const SizedBox(height: AppSizes.lg),
            TextField(decoration: InputDecoration(labelText: 'email'.tr())),
            const SizedBox(height: AppSizes.md),
            TextField(
              decoration: InputDecoration(labelText: 'password'.tr()),
              obscureText: true,
            ),
            const SizedBox(height: AppSizes.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, RouteNames.dashboard);
                },
                child: Text('login'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
