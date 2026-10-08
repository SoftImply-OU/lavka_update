import 'package:flutter/material.dart';

import 'client.dart';

/// Wrap the app with this in `MaterialApp.builder`. It checks Lavka on start
/// and whenever the app comes back to the foreground (throttled), and slides
/// in a banner at the bottom when a newer build exists. "Later" hides it
/// until the next newer build.
class LavkaUpdateGate extends StatefulWidget {
  const LavkaUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<LavkaUpdateGate> createState() => _LavkaUpdateGateState();
}

class _LavkaUpdateGateState extends State<LavkaUpdateGate> with WidgetsBindingObserver {
  int? _dismissedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LavkaUpdate.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) LavkaUpdate.check();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<LavkaUpdateStatus?>(
          valueListenable: LavkaUpdate.status,
          builder: (context, s, _) {
            final show = s != null && s.updateAvailable && s.latestVersionCode != _dismissedFor;
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              left: 12,
              right: 12,
              bottom: show ? 0 : -200,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 12),
                child: show
                    ? _UpdateBanner(
                        status: s,
                        onLater: () => setState(() => _dismissedFor = s.latestVersionCode),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.status, required this.onLater});

  final LavkaUpdateStatus status;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      key: const ValueKey('lavka-update-banner'),
      color: scheme.inverseSurface,
      elevation: 6,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.system_update_rounded, color: scheme.onInverseSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update available',
                      style: text.titleSmall?.copyWith(color: scheme.onInverseSurface, fontWeight: FontWeight.w600)),
                  Text('${status.latestLabel} · you have ${status.label}',
                      style: text.bodySmall?.copyWith(color: scheme.onInverseSurface.withValues(alpha: 0.75))),
                ],
              ),
            ),
            TextButton(
              onPressed: onLater,
              child: Text('Later', style: TextStyle(color: scheme.onInverseSurface.withValues(alpha: 0.8))),
            ),
            FilledButton(onPressed: LavkaUpdate.openStore, child: const Text('Update')),
          ],
        ),
      ),
    );
  }
}

/// A settings-screen row: "Version 1.0.0 (45)", with "Up to date" or the
/// newer build underneath. Tapping it checks again, or opens Lavka when an
/// update is waiting.
class LavkaVersionTile extends StatelessWidget {
  const LavkaVersionTile({super.key, this.leading = const Icon(Icons.info_outline_rounded)});

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LavkaUpdateStatus?>(
      valueListenable: LavkaUpdate.status,
      builder: (context, s, _) {
        if (s == null) LavkaUpdate.check();
        final scheme = Theme.of(context).colorScheme;
        return ListTile(
          leading: leading,
          title: Text(s == null ? 'Version' : 'Version ${s.label}'),
          subtitle: Text(
            s == null
                ? 'Checking…'
                : s.updateAvailable
                    ? 'Update available: ${s.latestLabel}'
                    : s.latestVersionCode == null
                        ? 'Installed from Lavka'
                        : 'Up to date',
            style: s?.updateAvailable == true ? TextStyle(color: scheme.primary, fontWeight: FontWeight.w600) : null,
          ),
          trailing: s?.updateAvailable == true ? const Icon(Icons.system_update_rounded) : null,
          onTap: () => s?.updateAvailable == true ? LavkaUpdate.openStore() : LavkaUpdate.check(force: true),
        );
      },
    );
  }
}

/// Just the version, for a footer or drawer: "v1.0.0 (45)", plus "· update
/// available" when there is one. Tapping opens Lavka.
class LavkaVersionText extends StatelessWidget {
  const LavkaVersionText({super.key, this.style, this.textAlign});

  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LavkaUpdateStatus?>(
      valueListenable: LavkaUpdate.status,
      builder: (context, s, _) {
        if (s == null) {
          LavkaUpdate.check();
          return const SizedBox.shrink();
        }
        final base = style ?? Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);
        return GestureDetector(
          onTap: s.updateAvailable ? LavkaUpdate.openStore : null,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'v${s.label}'),
              if (s.updateAvailable)
                TextSpan(
                  text: ' · update available',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                ),
            ]),
            style: base,
            textAlign: textAlign,
          ),
        );
      },
    );
  }
}
