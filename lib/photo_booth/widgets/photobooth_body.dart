import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:holobooth/audio_player/audio_player.dart';
import 'package:holobooth/avatar_detector/avatar_detector.dart';
import 'package:holobooth/camera/camera.dart';
import 'package:holobooth/footer/footer.dart';
import 'package:holobooth/in_experience_selection/in_experience_selection.dart';
import 'package:holobooth/photo_booth/photo_booth.dart';
import 'package:holobooth_ui/holobooth_ui.dart';
import 'package:platform_helper/platform_helper.dart';
import 'package:screen_recorder/screen_recorder.dart';

Exporter _getExporter() => Exporter();

class PhotoboothBody extends StatefulWidget {
  PhotoboothBody({
    super.key,
    ValueGetter<Exporter>? exporter,
    PlatformHelper? platformHelper,
    CameraDescription? camera,
  })  : _exporter = exporter ?? _getExporter,
        _platformHelper = platformHelper ?? PlatformHelper(),
        _camera = camera;

  final ValueGetter<Exporter> _exporter;
  final PlatformHelper _platformHelper;
  final CameraDescription? _camera;

  static const emptyViewKey = Key('emptyView');

  @override
  State<PhotoboothBody> createState() => _PhotoboothBodyState();
}

class _PhotoboothBodyState extends State<PhotoboothBody> {
  CameraController? _cameraController;
  late final ScreenRecorderController _screenRecorderController;

  @override
  void initState() {
    super.initState();
    _screenRecorderController =
        ScreenRecorderController(exporter: widget._exporter());
  }

  @override
  void dispose() {
    _screenRecorderController.stop();
    super.dispose();
  }

  bool get _isCameraAvailable =>
      (_cameraController?.value.isInitialized) ?? false;

  void _onCameraReady(CameraController cameraController) {
    setState(() => _cameraController = cameraController);
  }

  void _startRecording() {
    _screenRecorderController.start();
    context.read<PhotoBoothBloc>().add(const PhotoBoothRecordingStarted());
  }

  Future<void> _stopRecording() async {
    _screenRecorderController.stop();
    final photoBoothBloc = context.read<PhotoBoothBloc>();
    final frames = _screenRecorderController.exporter.frames;
    photoBoothBloc.add(PhotoBoothRecordingFinished(frames));
  }

  @override
  Widget build(BuildContext context) {
    final avatarStatus =
        context.select((AvatarDetectorBloc bloc) => bloc.state.status);

    return Stack(
      children: [
        Align(
          child: CameraView(
            camera: widget._camera,
            onCameraReady: _onCameraReady,
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final double characterOffestY;
            if (constraints.maxWidth > HoloboothBreakpoints.medium) {
              characterOffestY = constraints.maxHeight / 5;
            } else if (constraints.maxWidth > HoloboothBreakpoints.small) {
              characterOffestY = constraints.maxHeight / 5;
            } else {
              characterOffestY = -300 + constraints.maxWidth / 6;
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                ScreenRecorder(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  controller: _screenRecorderController,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PhotoboothBackground(),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Transform.translate(
                          offset: Offset(0, characterOffestY),
                          child: const PhotoboothCharacter(),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SimplifiedFooter(),
                ),
                if (constraints.maxWidth <= HoloboothBreakpoints.small &&
                    !widget._platformHelper.isMobile)
                  const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: MuteButton(),
                    ),
                  ),
                if (_isCameraAvailable)
                  CameraStreamListener(cameraController: _cameraController!),
                if (_isCameraAvailable &&
                    avatarStatus == AvatarDetectorStatus.notDetected)
                  const Align(child: HoloBoothCharacterError()),
                BlocBuilder<PhotoBoothBloc, PhotoBoothState>(
                  builder: (_, state) {
                    if (state.isRecording) {
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding:
                              constraints.maxWidth > HoloboothBreakpoints.small
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.only(bottom: 80),
                          child: RecordingCountdown(
                            onCountdownCompleted: _stopRecording,
                          ),
                        ),
                      );
                    } else if (state.gettingReady) {
                      return GetReadyLayer(
                        onCountdownCompleted: _startRecording,
                      );
                    } else if (avatarStatus.hasLoadedModel &&
                        !state.isFinished) {
                      return const SelectionLayer();
                    }
                    return const SizedBox(key: PhotoboothBody.emptyViewKey);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
