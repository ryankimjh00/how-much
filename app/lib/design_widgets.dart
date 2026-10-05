import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_theme.dart';

/// Figma 원본 SVG의 크기와 색을 유지한다. 터치 영역은 버튼에서 확보한다.
class DesignIcon extends StatelessWidget {
  const DesignIcon(this.name, {super.key, this.screen = '34-2'});

  final String name;
  final String screen;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/figma/$screen-img$name.svg',
    excludeFromSemantics: true,
  );
}

class DesignBackButton extends StatelessWidget {
  const DesignBackButton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 20),
    child: IconButton(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
      ),
      tooltip: '뒤로',
      onPressed: () => Navigator.pop(context),
      icon: const DesignIcon('IconBack', screen: '34-171'),
    ),
  );
}

class DesignCheckbox extends StatelessWidget {
  const DesignCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.screen = '34-2',
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String screen;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    button: true,
    child: InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppColors.primary : AppColors.border,
              ),
            ),
            child: value
                ? Center(child: DesignIcon('IconCheck', screen: screen))
                : null,
          ),
        ),
      ),
    ),
  );
}

class DesignNavigation extends StatelessWidget {
  const DesignNavigation({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            2,
            (tab) => Semantics(
              selected: index == tab,
              child: InkWell(
                onTap: () => onChanged(tab),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 108,
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: index == tab ? AppColors.secondary : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DesignIcon(
                        tab == 0 ? 'IconCart' : 'IconHistory',
                        screen: index == 0 ? '34-2' : '34-296',
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab == 0 ? '장보기' : '구매 기록',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: index == tab
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: index == tab
                              ? AppColors.coral
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.color = AppColors.surface,
  });
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: color == AppColors.note
            ? AppColors.noteBorder
            : AppColors.border,
      ),
      boxShadow: const [
        BoxShadow(color: Color(0x57CBB6A5), offset: Offset(0, 3)),
      ],
    ),
    child: child,
  );
}

class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    child: SafeArea(
      top: false,
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    ),
  );
}
