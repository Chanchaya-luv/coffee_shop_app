import 'package:flutter/material.dart';
import '../../models/model_menu.dart';

class VisualProductCustomizeDialog extends StatefulWidget {
  final MenuItem menu;
  final Function(String sweetness, String milk) onConfirm;

  const VisualProductCustomizeDialog({
    super.key,
    required this.menu,
    required this.onConfirm,
  });

  @override
  State<VisualProductCustomizeDialog> createState() =>
      _VisualProductCustomizeDialogState();
}

class _VisualProductCustomizeDialogState
    extends State<VisualProductCustomizeDialog>
    with TickerProviderStateMixin {

  String _sweetness = 'ปกติ (100%)';
  String _milk = 'นมวัว';

  late AnimationController _liquidController;
  late Animation<double> _liquidAnimation;

  @override
  void initState() {
    super.initState();
    _liquidController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    _liquidAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _liquidController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _liquidController.dispose();
    super.dispose();
  }

  Color _getDrinkColor() {
    Color baseColor = const Color(0xFF3E2723);

    if (_milk == 'นมวัว') {
      baseColor = const Color(0xFF8D6E63);
    } else if (_milk == 'นมโอ๊ต (+10)') {
      baseColor = const Color(0xFFD7CCC8);
    } else if (_milk == 'นมถั่วเหลือง') {
      baseColor = const Color(0xFFFFECB3);
    }

    if (_sweetness == '0%') return baseColor.withOpacity(0.9);
    if (_sweetness == '125%') return baseColor.withOpacity(0.7);

    return baseColor;
  }

  int _getSugarCount() {
    if (_sweetness == '0%') return 0;
    if (_sweetness == '25%') return 1;
    if (_sweetness == '50%') return 2;
    if (_sweetness == 'ปกติ (100%)') return 3;
    if (_sweetness == '125%') return 4;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView( // ✅ ตัวแก้ OVERFLOW หลัก
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // ================= VISUAL =================
                SizedBox(
                  height: 360,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(25)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFF3E0), Colors.white],
                          ),
                        ),
                      ),

                      Positioned(
                        top: 20,
                        child: Text(
                          widget.menu.name,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037)),
                        ),
                      ),

                      Positioned(
                        bottom: 20,
                        child: SizedBox(
                          width: 180,
                          height: 250,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              AnimatedBuilder(
                                animation: _liquidAnimation,
                                builder: (_, __) {
                                  return AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 500),
                                    width:
                                        140 + _liquidAnimation.value,
                                    height: 220,
                                    decoration: BoxDecoration(
                                      color: _getDrinkColor(),
                                      borderRadius:
                                          const BorderRadius.only(
                                        bottomLeft: Radius.circular(30),
                                        bottomRight: Radius.circular(30),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              Positioned(
                                bottom: 50,
                                child: Row(
                                  children: List.generate(
                                    _getSugarCount(),
                                    (_) => Padding(
                                      padding:
                                          const EdgeInsets.all(2.0),
                                      child: Icon(Icons.crop_square,
                                          size: 20,
                                          color: Colors.white
                                              .withOpacity(0.8)),
                                    ),
                                  ),
                                ),
                              ),

                              Container(
                                width: 150,
                                height: 230,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade400,
                                      width: 3),
                                  borderRadius:
                                      const BorderRadius.only(
                                    bottomLeft: Radius.circular(35),
                                    bottomRight: Radius.circular(35),
                                  ),
                                ),
                              ),

                              Positioned(
                                top: -20,
                                right: 40,
                                child: Transform.rotate(
                                  angle: 0.2,
                                  child: Container(
                                    width: 10,
                                    height: 100,
                                    color: Colors.orange,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ================= CONTROLS =================
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const Text("ระดับความหวาน",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey)),
                      const SizedBox(height: 10),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['0%', '25%', '50%', 'ปกติ (100%)', '125%']
                              .map((val) {
                            final isSelected = _sweetness == val;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(val),
                                selected: isSelected,
                                selectedColor:
                                    const Color(0xFFA6C48A),
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black),
                                onSelected: (_) =>
                                    setState(() => _sweetness = val),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text("ประเภทนม",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey)),
                      const SizedBox(height: 10),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['นมวัว', 'นมโอ๊ต', 'นมถั่วเหลือง','ไม่ใส่นม']
                              .map((val) {
                            final isSelected = _milk == val;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(val),
                                selected: isSelected,
                                selectedColor:
                                    const Color(0xFF6F4E37),
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black),
                                onSelected: (_) =>
                                    setState(() => _milk = val),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFA6C48A),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15)),
                          ),
                          onPressed: () {
                            widget.onConfirm(_sweetness, _milk);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "ปรุงเสร็จแล้ว! ใส่ตะกร้าเลย",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
