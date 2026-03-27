import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tsc_utils/flutter_tsc_utils.dart';

void main() {
  runApp(const TscExampleApp());
}

class TscExampleApp extends StatelessWidget {
  const TscExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_tsc_utils example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  final TextEditingController _englishController = TextEditingController(
    text: 'Hello TSC',
  );
  final TextEditingController _khmerController = TextEditingController(
    text: 'សួស្តី​ពិភពលោក',
  );

  String _preview = '';
  int _byteLength = 0;

  @override
  void initState() {
    super.initState();
    _rebuildPreview();
  }

  @override
  void dispose() {
    _englishController.dispose();
    _khmerController.dispose();
    super.dispose();
  }

  Future<void> _rebuildPreview() async {
    final generator = TscGenerator()
      ..size(const TscLabelSize(60, 40))
      ..gap(2, 0)
      ..density(8)
      ..direction(TscDirection.forward)
      ..cls()
      ..text(24, 24, _englishController.text)
      ..barcode(24, 80, '123456789012', height: 70)
      ..qrCode(360, 24, 'https://pub.dev/packages/flutter_tsc_utils');

    await generator.khmerText(
      24,
      190,
      _khmerController.text,
      options: const TscRenderedTextOptions(
        style: TextStyle(
          fontSize: 28,
          color: Color(0xFF000000),
          fontFamilyFallback: <String>[
            'Noto Sans Khmer',
            'NotoSansKhmer',
            'Khmer OS',
          ],
        ),
        pixelRatio: 2,
        padding: 4,
      ),
    );

    generator
      ..block(
        24,
        280,
        300,
        90,
        'Khmer text is rendered by Flutter and sent as a bitmap.',
      )
      ..print();

    if (!mounted) {
      return;
    }

    setState(() {
      _preview = generator.preview();
      _byteLength = generator.bytes().length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_tsc_utils example')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final children = <Widget>[
              _ControlsPanel(
                englishController: _englishController,
                khmerController: _khmerController,
                onChanged: _rebuildPreview,
                byteLength: _byteLength,
              ),
              _LabelPreview(
                englishText: _englishController.text,
                khmerText: _khmerController.text,
                commandPreview: _preview,
              ),
            ];

            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children
                        .map((child) => Expanded(child: child))
                        .toList(),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: children,
                  );
          },
        ),
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.englishController,
    required this.khmerController,
    required this.onChanged,
    required this.byteLength,
  });

  final TextEditingController englishController;
  final TextEditingController khmerController;
  final Future<void> Function() onChanged;
  final int byteLength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demo label', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'This preview app shows how to generate TSPL commands and render Khmer text as a bitmap using Flutter.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: englishController,
            decoration: const InputDecoration(
              labelText: 'English text',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: khmerController,
            decoration: const InputDecoration(
              labelText: 'Khmer text',
              border: OutlineInputBorder(),
              helperText:
                  'Use a Khmer-capable font on the device for best shaping results.',
            ),
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onChanged,
            icon: const Icon(Icons.refresh),
            label: const Text('Rebuild command preview'),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long),
                const SizedBox(width: 12),
                Text('Generated payload: $byteLength bytes'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelPreview extends StatelessWidget {
  const _LabelPreview({
    required this.englishText,
    required this.khmerText,
    required this.commandPreview,
  });

  final String englishText;
  final String khmerText;
  final String commandPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 600,
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFCF1), Color(0xFFF7F1DE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 60 / 40,
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 0,
                    child: Text(
                      englishText,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 58,
                    child: Container(
                      width: 220,
                      height: 70,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(width: 2),
                          bottom: BorderSide(width: 2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '|||| ||| | |||| |||',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.black,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 120,
                      height: 120,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Text('QR'),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 150,
                    child: Text(
                      khmerText,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.black,
                        fontFamilyFallback: const <String>[
                          'Noto Sans Khmer',
                          'NotoSansKhmer',
                          'Khmer OS',
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                      'Khmer text is rendered as bitmap before sending to the printer.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('TSPL preview', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1320),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SelectableText(
              _trimCommandPreview(commandPreview),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFD9F99D),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _trimCommandPreview(String preview) {
  final lines = const LineSplitter().convert(preview);
  return lines
      .map((line) {
        if (line.startsWith('BITMAP ')) {
          return '${line.substring(0, line.indexOf(',') + 1)}<binary bitmap bytes>';
        }
        return line;
      })
      .join('\n');
}
