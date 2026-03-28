import 'package:flutter/material.dart';

class SpeedControl extends StatefulWidget {
  final double currentSpeed;
  final Function(double) onSpeedChanged;

  const SpeedControl({
    super.key,
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  @override
  State<SpeedControl> createState() => _SpeedControlState();
}

class _SpeedControlState extends State<SpeedControl> {
  final List<double> speedPresets = [
    0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0
  ];
  double _currentSpeed = 1.0;
  String _inputText = '1.00';
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.currentSpeed;
    _inputText = _formatSpeed(_currentSpeed);
  }

  @override
  void didUpdateWidget(covariant SpeedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentSpeed != _currentSpeed) {
      setState(() {
        _currentSpeed = widget.currentSpeed;
        _inputText = _formatSpeed(_currentSpeed);
      });
    }
  }

  String _formatSpeed(double speed) {
    return speed.toStringAsFixed(2);
  }

  void _handleSpeedChange(double speed) {
    setState(() {
      _currentSpeed = speed;
      _inputText = _formatSpeed(speed);
    });
    widget.onSpeedChanged(speed);
  }

  void _handleTextChanged(String text) {
    setState(() {
      _inputText = text;
    });
  }

  void _handleTextSubmitted(String text) {
    setState(() {
      _isEditing = false;
    });
    try {
      double speed = double.parse(text);
      if (speed >= 0.25 && speed <= 4.0) {
        _handleSpeedChange(speed);
      } else {
        _inputText = _formatSpeed(_currentSpeed);
      }
    } catch (e) {
      _inputText = _formatSpeed(_currentSpeed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          // 固定档位选择
          Wrap(
            spacing: 0.0,
            children: speedPresets.map((speed) {
              return ElevatedButton(
                onPressed: () => _handleSpeedChange(speed),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentSpeed == speed 
                      ? Colors.blue 
                      : Colors.grey[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                ),
                child: Text('${speed}'),
              );
            }).toList(),
          ),
          // const SizedBox(height: 10),
          
          // 无级滑块
          Row(
            children: [
              const Text('0.25x', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: _currentSpeed,
                  min: 0.25,
                  max: 4.0,
                  divisions: 375, // 0.01精度
                  label: '${_currentSpeed.toStringAsFixed(2)}x',
                  activeColor: Colors.blue,
                  inactiveColor: Colors.grey[700],
                  onChanged: (value) => _handleSpeedChange(value),
                ),
              ),
              const Text('4.00x', style: TextStyle(color: Colors.white)),
            ],
          ),
          // const SizedBox(height: 10),
          
          // 手动输入框
          Row(
            children: [
              const Text('自定义速率: ', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: TextEditingController(text: _inputText),
                  onChanged: _handleTextChanged,
                  onSubmitted: _handleTextSubmitted,
                  onEditingComplete: () => _handleTextSubmitted(_inputText),
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
                onPressed: () => _handleSpeedChange(1.0),
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