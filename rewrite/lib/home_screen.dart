import 'package:flutter/material.dart';

/// Original responsive dashboard inspired by the user's visual reference.
/// All feature tiles open real existing app destinations.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onFeature,
    required this.onHistory,
    required this.onSettings,
    required this.language,
  });

  final ValueChanged<String> onFeature;
  final VoidCallback onHistory;
  final VoidCallback onSettings;
  final String language;
  String tr(String ar,String en)=>language=='ar'?ar:en;

  static const _blue = [Color(0xFF086BED), Color(0xFF34D0EF)];
  static const _violet = [Color(0xFF6269F8), Color(0xFFAD5CF2)];
  static const _aqua = [Color(0xFF0795EE), Color(0xFF52D6F1)];
  static const _purple = [Color(0xFF8C48ED), Color(0xFFCA68F3)];
  static const _teal = [Color(0xFF159ABB), Color(0xFF38D7CF)];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final gutter = compact ? 10.0 : 13.0;
    return Directionality(textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr,
      child:Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFFF6F9FF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: 14),
              children: [
                Row(children: [
                  const CircleAvatar(radius: 24, backgroundColor: Color(0xFFE0EEFF),
                    child: Icon(Icons.language_rounded, size: 29, color: Color(0xFF126DEB))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('مترجم الذكاء الاصطناعي','AI Translator'), style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                    Text(tr('الترجمة والتواصل بسهولة','Global translation and communication'),
                      maxLines: 2, style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                  IconButton(tooltip: tr('الإعدادات','Settings'), onPressed: onSettings,
                    icon: const Icon(Icons.settings_outlined)),
                ]),
                const SizedBox(height: 20),
                FeatureTile(
                  title: tr('استخراج النص من الصور','AI photo recognition'),
                  subtitle: tr('استخراج النص العربي والإنجليزي','Extract Arabic and English text'),
                  icon: Icons.photo_camera_outlined, colors: _blue,
                  height: 184, onTap: () => onFeature('photo'),
                ),
                SizedBox(height: gutter),
                FeatureTile(
                  title: tr('ترجمة الصور','AI photo translation'),
                  subtitle: tr('ترجمة النصوص داخل الصور','Translate words inside images'),
                  icon: Icons.document_scanner_outlined, colors: _violet,
                  height: 184, onTap: () => onFeature('photo_translate'),
                ),
                SizedBox(height: gutter),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: FeatureTile(
                    title: tr('محادثة بين شخصين','AI simultaneous interpretation'),
                    subtitle: tr('محادثة صوتية بلغتين','Two-person voice conversation'),
                    icon: Icons.record_voice_over_outlined,
                    colors: _aqua, height: 344 + gutter,
                    onTap: () => onFeature('conversation'),
                  )),
                  SizedBox(width: gutter),
                  Expanded(child: Column(children: [
                    FeatureTile(title: tr('ترجمة الكلام','AI real-time translation'),
                      subtitle: tr('تكلم وترجم على الهاتف','Speak and translate locally'),
                      icon: Icons.translate_outlined, colors: _blue,
                      height: 172, onTap: () => onFeature('live')),
                    SizedBox(height: gutter),
                    FeatureTile(title: tr('المساعد اللغوي','AI chat'),
                      subtitle: tr('أدوات الكتابة وإعادة الصياغة','Local writing and rewriting tools'),
                      icon: Icons.chat_bubble_outline_rounded, colors: _purple,
                      height: 172, onTap: () => onFeature('chat')),
                  ])),
                ]),
                SizedBox(height: gutter),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: FeatureTile(title: tr('تدريب الإنجليزية','Oral English'),
                    subtitle: tr('تدريب على المحادثة','Speaking practice'),
                    icon: Icons.mic_none_rounded, colors: _purple,
                    height: compact ? 215 : 220,
                    onTap: () => onFeature('english'), small: true)),
                  SizedBox(width: gutter),
                  Expanded(child: FeatureTile(title: tr('تفريغ الصوت','Convert audio to text'),
                    subtitle: tr('تحويل WAV إلى نص','Offline WAV transcription'),
                    icon: Icons.graphic_eq_rounded, colors: _blue,
                    height: compact ? 215 : 220,
                    onTap: () => onFeature('audio'), small: true)),
                  SizedBox(width: gutter),
                  Expanded(child: FeatureTile(title: tr('ترجمة دون إنترنت','Offline translation'),
                    subtitle: tr('عربي ↔ إنجليزي','Arabic ↔ English'),
                    icon: Icons.offline_bolt_outlined, colors: _teal,
                    height: compact ? 215 : 220,
                    onTap: () => onFeature('offline'), small: true)),
                ]),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) onHistory();
          if (index == 2) onSettings();
        },
        destinations: [
          NavigationDestination(icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded), label: tr('الرئيسية','Home')),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: tr('السجل','History')),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: tr('الإعدادات','Settings')),
        ],
      ),
    ));
  }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({super.key, required this.title, required this.subtitle,
    required this.icon, required this.colors, required this.height,
    required this.onTap, this.small = false});

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final double height;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true, label: '$title. $subtitle',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: onTap,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft,
              end: Alignment.bottomRight, colors: colors),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.14),
              blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(children: [
              Positioned(right: -24, bottom: -32, child: CircleAvatar(
                radius: small ? 45 : 86,
                backgroundColor: Colors.white.withValues(alpha: 0.07))),
              Positioned(right: small ? 9 : 14, bottom: small ? 15 : 15,
                child: Icon(icon, color: Colors.white.withValues(alpha: 0.55),
                  size: small ? 46 : 76)),
              Padding(
                padding: EdgeInsets.all(small ? 11 : 15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: small ? 3 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: small ? 14 : 18, height: 1.2,
                      color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(subtitle, maxLines: small ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: small ? 10 : 12,
                      color: Colors.white.withValues(alpha: 0.92))),
                  const Spacer(),
                  Container(width: 30, height: 30,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88),
                      shape: BoxShape.circle),
                    child: Icon(Icons.arrow_forward_rounded,
                      color: colors.first, size: 20)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}
