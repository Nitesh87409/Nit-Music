import 'package:flutter/material.dart';

class SettingsCardGroup extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;

  const SettingsCardGroup({
    required this.title,
    required this.children,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 56.0, right: 16.0),
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModernSettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ModernSettingsTile({
    required this.title,
    required this.icon,
    this.subtitle,
    
    this.trailing,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0x262196F3), // Colors.blue with opacity
                      Color(0x26E91E63), // Colors.pink with opacity
                      Color(0x26FF9800), // Colors.orange with opacity
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      colors: [
                        Colors.blue,
                        Colors.pink,
                        Colors.orange,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds);
                  },
                  child: Icon(icon, size: 20, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ModernSettingsHeader extends StatelessWidget {
  const ModernSettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Customize your music experience',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.settings_suggest_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class ModernSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ModernSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Transform.scale(
      scale: 0.85,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
        activeTrackColor: colorScheme.primary.withValues(alpha: 0.25),
        inactiveThumbColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        inactiveTrackColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
