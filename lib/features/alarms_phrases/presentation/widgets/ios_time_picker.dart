import 'package:flutter/material.dart';

class IosTimePicker extends StatefulWidget {
  final int initialHour;
  final int initialMinute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  const IosTimePicker({
    super.key,
    required this.initialHour,
    required this.initialMinute,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  @override
  State<IosTimePicker> createState() => _IosTimePickerState();
}

class _IosTimePickerState extends State<IosTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialHour;
    _selectedMinute = widget.initialMinute;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: _buildColumn(
              controller: _hourController,
              itemCount: 24,
              label: 'Часы',
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedHour = index;
                });
                widget.onHourChanged(index);
              },
            ),
          ),
          const Text(
            ':',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: _buildColumn(
              controller: _minuteController,
              itemCount: 60,
              label: 'Минуты',
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedMinute = index;
                });
                widget.onMinuteChanged(index);
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildColumn({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String label,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification) {
                final item = controller.selectedItem;
                onSelectedItemChanged(item);
              }
              return false;
            },
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: 40,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.5,
              perspective: 0.003,
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  return Center(
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
                childCount: itemCount,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }
}
