import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(
      'https://odehmohamed.github.io/techno-staff/privacy-policy.md',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('failed_to_open_link'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = _packageInfo?.version ?? '';
    final buildNumber = _packageInfo?.buildNumber ?? '';
    final versionText = version.isNotEmpty
        ? '${'app_version'.tr()} $version ($buildNumber)'
        : '';

    return Scaffold(
      appBar: AppBar(title: Text('about'.tr())),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        children: [
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Techno Staff',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          if (versionText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                versionText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text('privacy_policy'.tr()),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: _openPrivacyPolicy,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text('open_source_licenses'.tr()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Techno Staff',
              applicationVersion: version,
            ),
          ),
        ],
      ),
    );
  }
}
