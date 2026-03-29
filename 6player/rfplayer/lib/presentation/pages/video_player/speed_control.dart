import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'video_player_controller.dart';

class SpeedControl extends StatefulWidget {
  final double currentSpeed;
  final MyVideoPlayerController controller;
  /// 拖动时实时回调（只更新状态，不持久化）
  final void Function(double speed)? onSpeedChanged;
  /// 点击档位或手动输入后的最终值回调（持久化）
  final void Function(double speed) onSpeedChangeFinal;

  const SpeedControl({
    super.key,
    required this.currentSpeed,
    required this.controller,
    this.onSpeedChanged,
    required this.onSpeedChangeFinal,
  });

  @override
  State<SpeedControl> createState() => _SpeedControlState();
}

class _SpeedControlState extends State<SpeedControl> {
  List<double> get speedPresets {
    if (Platform.isAndroid) {
      return [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0];
    } else {
      return [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0];
    }
  }

  double _currentSpeed = 1.0;
  bool _isDragging = false;
  // 使用固定 controller 避免每次 rebuild 时光标跳到头
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.currentSpeed;
    _textController = TextEditingController(text: _formatSpeed(_currentSpeed));
  }

  @override
  void didUpdateWidget(covariant SpeedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDragging) return;
    if (widget.currentSpeed != _currentSpeed) {
      _currentSpeed = widget.currentSpeed;
      if (!_textController.selection.isValid ||
          _textController.text != _formatSpeed(_currentSpeed)) {
        _textController.text = _formatSpeed(_currentSpeed);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _formatSpeed(double speed) => speed.toStringAsFixed(2);

  double get _maxSpeed => Platform.isAndroid ? 3.0 : 4.0;

  void _applyPreset(double speed) {
    setState(() {
      _currentSpeed = speed;
      _textController.text = _formatSpeed(speed);
    });
    widget.onSpeedChangeFinal(speed);
  }

  void _handleSliderChanged(double value) {
    _isDragging = true;
    setState(() {
      _currentSpeed = value;
      _textController.text = _formatSpeed(value);
    });
    widget.controller.setPlaybackSpeed(value);
    widget.onSpeedChanged?.call(value);
  }

  void _handleSliderEnd(double value) {
    _isDragging = false;
    setState(() {
      _currentSpeed = value;
      _textController.text = _formatSpeed(value);
    });
    widget.onSpeedChangeFinal(value);
  }

  void _handleTextSubmitted(String text) {
    try {
      final speed = double.parse(text);
      if (speed >= 0.25 && speed <= _maxSpeed) {
        setState(() {
          _currentSpeed = speed;
          _textController.text = _formatSpeed(speed);
        });
        widget.onSpeedChangeFinal(speed);
      } else {
        _textController.text = _formatSpeed(_currentSpeed);
      }
    } catch (_) {
      _textController.text = _formatSpeed(_currentSpeed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          // 固定档位
          Wrap(
            spacing: 0.0,
            children: speedPresets.map((speed) {
              return ElevatedButton(
                onPressed: () => _applyPreset(speed),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _currentSpeed == speed ? Colors.blue : Colors.grey[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                ),
                child: Text('$speed'),
              );
            }).toList(),
          ),

          // 无级滑块
          Row(
            children: [
              const Text('0.25x', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: _currentSpeed,
                  min: 0.25,
                  max: _maxSpeed,
                  label: '${_currentSpeed.toStringAsFixed(2)}x',
                  activeColor: Colors.blue,
                  inactiveColor: Colors.grey[700],
                  onChanged: _handleSliderChanged,
                  onChangeEnd: _handleSliderEnd,
                ),
              ),
              Text('${_maxSpeed.toStringAsFixed(2)}x',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),

          // 手动输入
          Row(
            children: [
              const Text('自定义速率: ', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _textController,
                  onSubmitted: _handleTextSubmitted,
                  onEditingComplete: () => _handleTextSubmitted(_textController.text),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    suffixText: 'x',
                    suffixStyle: TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _applyPreset(1.0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                ),
                child: const Text('重置'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
