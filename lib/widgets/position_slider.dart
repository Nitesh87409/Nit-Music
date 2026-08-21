import 'package:flutter/material.dart';
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/utilities/formatter.dart';

PositionData _positionData = PositionData(
  Duration.zero,
  Duration.zero,
  Duration.zero,
);

class PositionSlider extends StatefulWidget {
  const PositionSlider({super.key});

  @override
  State<PositionSlider> createState() => _PositionSliderState();
}

class _PositionSliderState extends State<PositionSlider> {
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: audioHandler.positionDataStream,
      builder: (context, snapshot) {
        if (snapshot.data != null && snapshot.data!.position.inSeconds > 0) {
          _positionData = snapshot.data!;
        }

        final maxDuration = _positionData.duration.inSeconds > 0
            ? _positionData.duration.inSeconds.toDouble()
            : 1.0;

        final currentValue = _isDragging
            ? _dragValue
            : _positionData.position.inSeconds.toDouble();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                thumbColor: Theme.of(context).colorScheme.primary,
                overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: currentValue.clamp(0.0, maxDuration),
                onChanged: (value) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = value;
                  });
                },
                onChangeEnd: (value) {
                  audioHandler.seek(Duration(seconds: value.toInt()));
                  setState(() {
                    _isDragging = false;
                  });
                },
                max: maxDuration,
                semanticFormatterCallback: (value) =>
                    formatDuration(value.toInt()),
              ),
            ),
            _buildPositionRow(context, _positionData),
          ],
        );
      },
    );
  }

  Widget _buildPositionRow(BuildContext context, PositionData positionData) {
    final positionText = formatDuration(
      _isDragging ? _dragValue.toInt() : positionData.position.inSeconds,
    );
    final durationText = formatDuration(positionData.duration.inSeconds);
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(positionText, style: textStyle),
          Text(durationText, style: textStyle),
        ],
      ),
    );
  }
}
