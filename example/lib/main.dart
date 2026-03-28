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

  TscLabelGenerator _generator = _buildGenerator(
    englishText: 'Hello TSC',
    khmerText: 'សួស្តី​ពិភពលោក',
  );
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
    final generator = _buildGenerator(
      englishText: _englishController.text,
      khmerText: _khmerController.text,
    );

    final bytes = await generator.buildBytes();

    if (!mounted) {
      return;
    }

    setState(() {
      _generator = generator;
      _byteLength = bytes.length;
    });
  }

  static TscLabelGenerator _buildGenerator({
    required String englishText,
    required String khmerText,
  }) {
    return TscLabelGenerator(
      config: const TscLabelConfiguration(
        printWidth: 600,
        labelLength: 400,
        printDensity: TscPrintDensity.d8,
      ),
      commands: [
        TscText(x: 24, y: 24, text: englishText),
        const TscBarcode(
          x: 24,
          y: 80,
          data: '123456789012',
          height: 70,
          type: TscBarcodeType.code128,
          printInterpretationLine: true,
        ),
        const TscQrCode(
          x: 420,
          y: 24,
          data: 'https://pub.dev/packages/flutter_tsc_utils',
          cellWidth: TscQrCellWidth.size4,
        ),
        TscRenderedText(
          x: 24,
          y: 190,
          text: khmerText,
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
        ),
        const TscText(
          x: 24,
          y: 330,
          text: 'Khmer text is rendered by Flutter and sent as a bitmap.',
        ),
      ],
    );
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
              _LabelPreview(generator: _generator),
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
          Text(
            'Declarative preview demo',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Update the generator inputs and the preview widget rebuilds from the same TSC label definition.',
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
            label: const Text('Rebuild live preview'),
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
  const _LabelPreview({required this.generator});

  final TscLabelGenerator generator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live preview', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: TscPreview(generator: generator),
          ),
        ],
      ),
    );
  }
}
