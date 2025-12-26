import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';

import '../../models/model_menu.dart';
import '../../providers/cart_provider.dart';

class MysteryBoxScreen extends StatefulWidget {
  const MysteryBoxScreen({super.key});

  @override
  State<MysteryBoxScreen> createState() => _MysteryBoxScreenState();
}

class _MysteryBoxScreenState extends State<MysteryBoxScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;
  
  bool _isPlaying = false;
  
  // 🔥 ปรับราคาเป็น 44 บาท
  final double _gachaPrice = 44.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -5, end: 5).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playGacha() async {
    // 🔥 เช็คซ้ำอีกรอบกันเหนียว
    final cart = Provider.of<CartProvider>(context, listen: false);
    bool alreadyPlayed = cart.items.values.any((item) => item.menu.id.contains('GACHA'));
    
    if (alreadyPlayed) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("คุณใช้สิทธิ์สุ่มไปแล้ว (จำกัด 1 ครั้งต่อออเดอร์)"), backgroundColor: Colors.red));
       return;
    }

    setState(() {
      _isPlaying = true;
    });

    // 1. เริ่ม Animation
    _controller.repeat(reverse: true);

    // 2. ดึงสินค้าทั้งหมด (เฉพาะเครื่องดื่ม)
    var snapshot = await FirebaseFirestore.instance
        .collection('menu_items')
        .where('isAvailable', isEqualTo: true)
        .get();

    List<MenuItem> pool = [];
    for (var doc in snapshot.docs) {
       var data = doc.data();
       if (['กาแฟ', 'ชา', 'นมสด','ผลไม้'].contains(data['category'])) {
          pool.add(MenuItem(
            id: doc.id,
            name: data['name'] ?? '',
            price: (data['price'] ?? 0).toDouble(),
            category: data['category'] ?? '',
            imageUrl: data['imageUrl'] ?? '',
            recipe: [], 
            isAvailable: true
          ));
       }
    }

    // 3. จำลองเวลาลุ้น (3 วินาที)
    await Future.delayed(const Duration(seconds: 3));

    _controller.stop(); // หยุดเขย่า

    if (pool.length >= 2) {
      // 4. สุ่ม 2 รายการ (ไม่ซ้ำกัน)
      var random = Random();
      MenuItem item1 = pool[random.nextInt(pool.length)];
      MenuItem item2;
      do {
        item2 = pool[random.nextInt(pool.length)];
      } while (item1.id == item2.id); // วนหาใหม่ถ้าซ้ำกับอันแรก

      setState(() {
        _isPlaying = false;
      });
      
      // โชว์ Dialog รางวัลคู่
      _showRewardDialog(item1, item2);
    } else {
      setState(() => _isPlaying = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("สินค้าในระบบไม่พอสำหรับสุ่มคู่")));
    }
  }

  void _showRewardDialog(MenuItem item1, MenuItem item2) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🎉 ยินดีด้วย! คุณได้รับ 🎉", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 15),
            
            // แสดงรูปคู่
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRewardItem(item1),
                const SizedBox(width: 10),
                const Icon(Icons.add, color: Colors.grey),
                const SizedBox(width: 10),
                _buildRewardItem(item2),
              ],
            ),
              
            const SizedBox(height: 20),
            Text("${item1.name} + ${item2.name}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6F4E37)), textAlign: TextAlign.center),
            const SizedBox(height: 5),
            Text("มูลค่ารวม ฿${(item1.price + item2.price).toStringAsFixed(0)}", style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
            const SizedBox(height: 10),
            Text("จ่ายเพียง ฿${_gachaPrice.toStringAsFixed(0)} เท่านั้น!", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA6C48A), foregroundColor: Colors.white),
            onPressed: () {
              // เพิ่มลงตะกร้าเป็น 1 รายการรวม (Bundle)
              MenuItem gachaBundle = MenuItem(
                id: "MYSTERY_BOX_GACHA", // ID พิเศษ
                name: "กล่องสุ่ม (${item1.name} + ${item2.name})",
                price: _gachaPrice, // ราคา 44
                category: 'Promotion',
                imageUrl: 'https://cdn-icons-png.flaticon.com/512/4522/4522489.png',
                recipe: [], 
                isAvailable: true,
              );
              
              Provider.of<CartProvider>(context, listen: false).addItem(gachaBundle);
              Navigator.pop(ctx); 
              Navigator.pop(context); 
              
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("เพิ่มกล่องสุ่มลงตะกร้าแล้ว!"), backgroundColor: Colors.green));
            }, 
            child: const Text("รับสินค้าใส่ตะกร้า")
          )
        ],
      ),
    );
  }

  Widget _buildRewardItem(MenuItem item) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: item.imageUrl.isNotEmpty
            ? Image.network(item.imageUrl, width: 70, height: 70, fit: BoxFit.cover)
            : const Icon(Icons.local_cafe, size: 50, color: Colors.brown),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- 🔥 เช็คสิทธิ์: มีกล่องสุ่มในตะกร้าหรือยัง? ---
    final cart = Provider.of<CartProvider>(context);
    bool hasPlayed = cart.items.values.any((item) => item.menu.id.contains('GACHA'));

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        title: const Text("Mystery Drink Box", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // กล่องสุ่ม Animation
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_isPlaying ? _shakeAnimation.value : 0, 0),
                  child: child,
                );
              },
              child: GestureDetector(
                // ถ้าใช้สิทธิ์แล้ว กดไม่ได้
                onTap: hasPlayed || _isPlaying ? null : _playGacha,
                child: Opacity(
                  opacity: hasPlayed ? 0.5 : 1.0, // จางลงถ้าเล่นแล้ว
                  child: Image.network(
                    'https://cdn-icons-png.flaticon.com/512/4522/4522489.png',
                    width: 250,
                    color: _isPlaying ? Colors.white.withOpacity(0.8) : null,
                    colorBlendMode: BlendMode.modulate,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            if (_isPlaying)
              const Column(
                children: [
                  Text("กำลังสุ่ม...", style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  CircularProgressIndicator(color: Colors.orange),
                ],
              )
            else
              Column(
                children: [
                  const Text("กล่องสุ่มลุ้นเมนูจับคู่", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text("รับ 2 เมนู ในราคาเพียง ฿${_gachaPrice.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  const SizedBox(height: 40),
                  
                  // ปุ่มกด
                  SizedBox(
                    width: 220,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasPlayed ? Colors.grey : Colors.orange, // เปลี่ยนสีถ้าเล่นแล้ว
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                      ),
                      onPressed: hasPlayed ? null : _playGacha, // ล็อกปุ่มถ้าเล่นแล้ว
                      icon: Icon(hasPlayed ? Icons.lock : Icons.casino),
                      label: Text(
                        hasPlayed ? "ใช้สิทธิ์ไปแล้ว" : "กดเพื่อสุ่ม (44.-)", 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                  
                  if (hasPlayed)
                    const Padding(
                      padding: EdgeInsets.only(top: 15),
                      child: Text("(จำกัด 1 สิทธิ์ต่อ 1 ออเดอร์)", style: TextStyle(color: Colors.redAccent)),
                    )
                ],
              )
          ],
        ),
      ),
    );
  }
}