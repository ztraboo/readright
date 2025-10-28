import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_styles.dart';

class StudentWordDashboardPage extends StatefulWidget {
  const StudentWordDashboardPage({super.key});

  @override
  State<StudentWordDashboardPage> createState() => _StudentWordDashboardPageState();
}

class _StudentWordDashboardPageState extends State<StudentWordDashboardPage> {
  final Set<String> _selectedFilters = {'Sight Words', 'Minimal Pairs'};
  final Set<String> _completedWords = {'away'};

  void _toggleFilter(String filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedFilters.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildCompletionProgress(),
              _buildFilterInstructions(),
              _buildFilterChips(),
              _buildWordList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 246,
      color: AppColors.bgPrimaryGray,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            'Practice Words',
            style: AppStyles.headerText
          ),
          const SizedBox(height: 22),
          Container(
            width: 90,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF292929),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.black, width: 1),
            ),
          ),
          const SizedBox(height: 26),
          const SizedBox(
            width: 349,
            child: Text(
              'Select each word in the list below to explore best way to pronounce them.',
              style: AppStyles.subheaderText,
            ),
          ),
          const SizedBox(height: 38),
        ],
      ),
    );
  }

  Widget _buildCompletionProgress() {
    const int done = 3;
    const int total = 15;
    final double progress = done / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC6C0).withOpacity(0.20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completion Progress',
            style: AppStyles.subsectionText,
          ),
          const SizedBox(height: 22),
          _buildProgressBar(progress),
          const SizedBox(height: 18),
          Row(
            children: [
              Row(
                children: [
                  const Text(
                    'Done',
                    style: AppStyles.subheaderText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$done',
                    style: AppStyles.subheaderText.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Row(
                children: [
                  const Text(
                    'Remaining',
                    style: AppStyles.subheaderText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${total - done}',
                    style: AppStyles.subheaderText.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return SizedBox(
      height: 44,
      child: Center(
        child: Container(
          width: double.infinity,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF787878).withOpacity(0.20),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                width: double.infinity,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF0088FF),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          'Use the filter chips below to display only the grouped category of words. This is helpful if your instructor only wants you to focus on a specific set of words.',
          style: TextStyle(
            fontFamily: 'SF Compact Display',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.black,
            height: 1.375,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 11,
        children: [
          _buildFilterChip(
            'Sight Words',
            const Color(0xFF7498C4),
            const Color(0xFF754F4B),
          ),
          _buildFilterChip(
            'Minimal Pairs',
            const Color(0xFFC99379),
            const Color(0xFF754F4B),
          ),
          _buildFilterChip(
            'Phonics Patterns',
            const Color(0xFFFF3939),
            const Color(0xFF754F4B),
            showCheck: false,
          ),
          _buildClearFiltersButton(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, Color borderColor, Color textColor, {bool showCheck = true}) {
    final bool isSelected = _selectedFilters.contains(label);
    
    return GestureDetector(
      onTap: () => _toggleFilter(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? borderColor.withOpacity(0.20) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected && showCheck) ...[
              SvgPicture.asset(
                'assets/icons/check-svgrepo-com.svg',
                width: 15,
                semanticsLabel: 'Checkmark',
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: AppStyles.chipText.copyWith(
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearFiltersButton() {
    return GestureDetector(
      onTap: _clearFilters,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: const Text(
          'Clear Filters',
          style: AppStyles.chipFilter,
        ),
      ),
    );
  }

  Widget _buildWordList() {
    final List<Map<String, dynamic>> words = [
      {'word': 'away', 'category': 'Sight Words', 'color': Color(0xFF7498C4), 'completed': true},
      {'word': 'blue', 'category': 'Sight Words', 'color': Color(0xFF7498C4), 'completed': false},
      {'word': 'cat', 'category': 'Minimal Pairs', 'color': Color(0xFFC99379), 'completed': false},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: words.map((wordData) => _buildWordItem(
          wordData['word'] as String,
          wordData['category'] as String,
          wordData['color'] as Color,
          wordData['completed'] as bool,
        )).toList(),
      ),
    );
  }

  Widget _buildWordItem(String word, String category, Color categoryColor, bool completed) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/student-word-practice');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFF88843), width: 1.5),
        ),
        child: Row(
        children: [
          Container(
            width: 10,
            height: 64,
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildCheckIcon(completed),
          Expanded(
            child: Center(
              child: Text(
                word,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  height: 0.92,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      ),
    );
  }

  Widget _buildCheckIcon(bool completed) {
    if (completed) {
      return SizedBox(
        width: 44,
        height: 44,
        child: SvgPicture.asset(
          'assets/icons/circle-check-filled-svgrepo-com.svg',
          width: 15,
          semanticsLabel: 'Checkmark',
        ),
      );
    } else {
      return Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFD9D9D9),
        ),
      );
    }
  }
}
