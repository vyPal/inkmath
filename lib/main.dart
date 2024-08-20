import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Ink;
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';
import 'package:expressions/expressions.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scribble',
      theme: ThemeData.from(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple)),
      home: const HomePage(title: 'InkMath ALPHA (by vyPal)'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DigitalInkRecognizerModelManager _modelManager =
      DigitalInkRecognizerModelManager();
  var _language = 'en';
  // Codes from https://developers.google.com/ml-kit/vision/digital-ink-recognition/base-models?hl=en#text
  final _languages = [
    'en',
    'es',
    'fr',
    'hi',
    'it',
    'ja',
    'pt',
    'ru',
    'zh-Hani',
  ];
  var _digitalInkRecognizer = DigitalInkRecognizer(languageCode: 'en');
  final Ink _ink = Ink();
  List<StrokePoint> _points = [];
  String _recognizedText = '';
  bool _canAddToStack = false;

  @override
  void dispose() {
    _digitalInkRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('InkMath ALPHA (by vyPal)')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDropdown(),
                  ElevatedButton(
                    onPressed: _isModelDownloaded,
                    child: const Text('Check Model'),
                  ),
                  ElevatedButton(
                    onPressed: _downloadModel,
                    child: const Icon(Icons.download),
                  ),
                  ElevatedButton(
                    onPressed: _deleteModel,
                    child: const Icon(Icons.delete),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _recogniseText,
                    child: const Text('Read Text'),
                  ),
                  ElevatedButton(
                    onPressed: _clearPad,
                    child: const Text('Clear Pad'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Listener(
                onPointerDown: (PointerDownEvent details) {
                  _ink.strokes.add(Stroke());
                },
                onPointerMove: (PointerMoveEvent details) {
                  setState(() {
                    final RenderObject? object = context.findRenderObject();
                    final localPosition = (object as RenderBox?)
                        ?.globalToLocal(details.localPosition);
                    if (localPosition != null) {
                      _points = List.from(_points)
                        ..add(StrokePoint(
                          x: localPosition.dx,
                          y: localPosition.dy,
                          t: DateTime.now().millisecondsSinceEpoch,
                        ));
                    }
                    if (_ink.strokes.isNotEmpty) {
                      _ink.strokes.last.points = _points.toList();
                    }
                  });
                },
                onPointerUp: (PointerUpEvent details) {
                  _points.clear();
                  setState(() {});
                  _recogniseText();
                },
                child: CustomPaint(
                  painter: Signature(ink: _ink),
                  size: Size.infinite,
                ),
              ),
            ),
            if (_recognizedText.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _recognizedText,
                    style: const TextStyle(fontSize: 23),
                  ),
                  if (_canAddToStack)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text("Add to stack"),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown() => DropdownButton<String>(
        value: _language,
        icon: const Icon(Icons.arrow_downward),
        elevation: 16,
        style: const TextStyle(color: Colors.blue),
        underline: Container(
          height: 2,
          color: Colors.blue,
        ),
        onChanged: (String? lang) {
          if (lang != null) {
            setState(() {
              _language = lang;
              _digitalInkRecognizer.close();
              _digitalInkRecognizer =
                  DigitalInkRecognizer(languageCode: _language);
            });
          }
        },
        items: _languages.map<DropdownMenuItem<String>>((lang) {
          return DropdownMenuItem<String>(
            value: lang,
            child: Text(lang),
          );
        }).toList(),
      );

  void _clearPad() {
    setState(() {
      _ink.strokes.clear();
      _points.clear();
      _recognizedText = '';
    });
  }

  Future<void> _isModelDownloaded() async {
    Toast().show(
        'Checking if model is downloaded...',
        _modelManager
            .isModelDownloaded(_language)
            .then((value) => value ? 'downloaded' : 'not downloaded'),
        context,
        this);
  }

  Future<void> _deleteModel() async {
    Toast().show(
        'Deleting model...',
        _modelManager
            .deleteModel(_language)
            .then((value) => value ? 'success' : 'failed'),
        context,
        this);
  }

  Future<void> _downloadModel() async {
    Toast().show(
        'Downloading model...',
        _modelManager
            .downloadModel(_language)
            .then((value) => value ? 'success' : 'failed'),
        context,
        this);
  }

  Future<void> _recogniseText() async {
    if (_modelManager.isModelDownloaded(_language) == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Model not downloaded. Please download it first.'),
      ));
      return;
    }
    try {
      final candidates = await _digitalInkRecognizer.recognize(_ink);
      candidates.sort((a, b) => b.score.compareTo(a.score));
      _recognizedText = '';
      for (final candidate in candidates) {
        final result = _evaluateMathExpression(candidate.text);
        if (result != null) {
          _recognizedText =
              '${candidate.text.endsWith("=") ? candidate.text.substring(0, candidate.text.length - 1) : candidate.text} = $result';
          break;
        }
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
      ));
    }
  }

  dynamic _evaluateMathExpression(String expression) {
    try {
      // Remove spaces
      final cleanedExpression = expression.replaceAll(' ', '');

      // Check if the expression ends with '=' and remove it
      final exp = cleanedExpression.endsWith('=')
          ? cleanedExpression.substring(0, cleanedExpression.length - 1)
          : cleanedExpression;

      // Parse and evaluate the expression
      final parsedExpression = Expression.parse(exp);
      const evaluator = ExpressionEvaluator();

      // Define constants and functions
      final context = {
        'pi': math.pi,
        'e': math.e,
        'cos': (num x) => math.cos(x),
        'sin': (num x) => math.sin(x),
        'tan': (num x) => math.tan(x),
        'sqrt': (num x) => math.sqrt(x),
        'log': (num x) => math.log(x),
        'exp': (num x) => math.exp(x),
        'pow': (num x, num y) => math.pow(x, y),
      };

      final result = evaluator.eval(parsedExpression, context);

      return result;
    } catch (e) {
      print('Error evaluating expression: $e');
    }
    return null;
  }
}

class Signature extends CustomPainter {
  Ink ink;

  Signature({required this.ink});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (final stroke in ink.strokes) {
      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        canvas.drawLine(Offset(p1.x.toDouble(), p1.y.toDouble()),
            Offset(p2.x.toDouble(), p2.y.toDouble()), paint);
      }
    }
  }

  @override
  bool shouldRepaint(Signature oldDelegate) => true;
}

class Toast {
  void show(String message, Future<String> t, BuildContext context,
      State<StatefulWidget> state) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    showLoadingIndicator(context, message);
    final verificationResult = await t;
    Navigator.of(context).pop();
    if (!state.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Result: ${verificationResult.toString()}'),
    ));
  }

  void showLoadingIndicator(BuildContext context, String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
            canPop: false,
            child: AlertDialog(
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8.0))),
              backgroundColor: Colors.black87,
              content: LoadingIndicator(text: text),
            ));
      },
    );
  }
}

class LoadingIndicator extends StatelessWidget {
  final String text;

  const LoadingIndicator({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.black.withOpacity(0.8),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [_getLoadingIndicator(), _getHeading(), _getText(text)]));
  }

  Widget _getLoadingIndicator() {
    return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3)));
  }

  Widget _getHeading() {
    return const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text(
          'Please wait …',
          style: TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ));
  }

  Widget _getText(String displayedText) {
    return Text(
      displayedText,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      textAlign: TextAlign.center,
    );
  }
}
