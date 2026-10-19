import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../data/score_repository.dart';
import '../services/simulated_target.dart';
import '../services/target_analyzer.dart';
import 'review_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({required this.repository, super.key});

  final ScoreRepository repository;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _takingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera is available.');
      }
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = _cameraMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the camera. Please try again.');
      }
    }
  }

  String _cameraMessage(CameraException error) => switch (error.code) {
    'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
      'Camera access is off. Allow camera access in your phone settings, then try again.',
    'CameraAccessDeniedWithPrompt' =>
      'Allow camera access when your phone asks, then try again.',
    _ => 'The camera could not start (${error.code}). Please try again.',
  };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || _takingPhoto) return;
    setState(() => _takingPhoto = true);
    try {
      final capturedAt = DateTime.now();
      final photo = await controller.takePicture();
      final photoFile = File(photo.path);
      final imageBytes = await photoFile.readAsBytes();
      await photoFile.delete().catchError((_) => photoFile);
      if (!mounted) {
        return;
      }
      await _openReview(imageBytes, capturedAt);
      if (mounted) setState(() => _takingPhoto = false);
    } catch (_) {
      if (mounted) {
        setState(() => _takingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not capture the target. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _trySampleTarget() async {
    if (_takingPhoto) return;
    setState(() => _takingPhoto = true);
    try {
      final imageBytes = await SimulatedTarget.create();
      if (!mounted) return;
      await _openReview(imageBytes, DateTime.now());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not create the sample target. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _openReview(Uint8List imageBytes, DateTime capturedAt) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          imageBytes: imageBytes,
          capturedAt: capturedAt,
          repository: widget.repository,
          analyzer: PrototypeTargetAnalyzer(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: const Color(0xFF111A16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111A16),
        foregroundColor: Colors.white,
        title: const Text('Photograph target'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            CameraPreview(controller)
          else
            Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.no_photography_outlined,
                            color: Colors.white70,
                            size: 40,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _initializeCamera,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
            ),
          if (controller != null && controller.value.isInitialized) ...[
            IgnorePointer(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 0.92,
                  child: Container(
                    margin: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .9),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 24,
              left: 26,
              right: 26,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  'Fill the frame with the target face. Keep the phone level and avoid glare.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, height: 1.35),
                ),
              ),
            ),
            Positioned(
              bottom: 78,
              left: 24,
              right: 24,
              child: Center(
                child: IconButton.filled(
                  onPressed: _takingPhoto ? null : _takePhoto,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF2C65D),
                    foregroundColor: const Color(0xFF26372F),
                    fixedSize: const Size(72, 72),
                  ),
                  icon: _takingPhoto
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 30),
                ),
              ),
            ),
          ],
          Positioned(
            bottom: 16,
            left: 20,
            right: 20,
            child: Center(
              child: TextButton.icon(
                onPressed: _takingPhoto ? null : _trySampleTarget,
                style: TextButton.styleFrom(
                  foregroundColor:
                      controller != null && controller.value.isInitialized
                      ? Colors.white
                      : const Color(0xFF245B48),
                  backgroundColor:
                      controller != null && controller.value.isInitialized
                      ? Colors.black.withValues(alpha: .42)
                      : Colors.white,
                ),
                icon: const Icon(Icons.science_outlined, size: 18),
                label: Text(
                  _takingPhoto ? 'Preparing sample…' : 'Try sample target',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
