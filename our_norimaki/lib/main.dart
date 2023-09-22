import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:our_norimaki/menu_page.dart';
import 'package:our_norimaki/firebase_options.dart';
import 'package:our_norimaki/sales_history.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const App());
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('식당 POS 시스템'),
          ),
          body: const TableLayout(),
        );
      }),
    );
  }
}

class TableLayout extends StatelessWidget {
  const TableLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
            itemCount: 16,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MenuPage(tableNumber: index + 1),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                  ),
                  child: Center(
                    child: Text('테이블 ${index + 1}'),
                  ),
                ),
              );
            },
          ),
        ),
        ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AddProductDialog(),
            );
          },
          child: const Text('상품 등록'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SalesHistoryPage(),
              ),
            );
          },
          child: const Text('판매 내역'),
        ),
      ],
    );
  }
}

class AddProductDialog extends StatelessWidget {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();

  AddProductDialog({super.key});

  Future<void> addProduct(String name, int price, String description) async {
    CollectionReference products =
        FirebaseFirestore.instance.collection('products');
    CollectionReference counters =
        FirebaseFirestore.instance.collection('counters');

    // 상품 코드 자동 생성
    DocumentSnapshot counterDoc = await counters.doc('productCounter').get();
    int nextCode = counterDoc.exists ? counterDoc['nextCode'] : 1;
    String code = 'A${nextCode.toString().padLeft(9, '0')}';

    // 상품 정보 저장
    await products.add({
      'name': name,
      'price': price,
      'code': code,
      'description': description,
    });

    // 카운터 업데이트
    await counters.doc('productCounter').set({'nextCode': nextCode + 1});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('상품 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '상품 이름'),
          ),
          TextField(
            controller: priceController,
            decoration: const InputDecoration(labelText: '상품 가격'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(labelText: '세부 설명'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            String name = nameController.text;
            int price = int.parse(priceController.text);
            String description = descriptionController.text;
            addProduct(name, price, description);
            Navigator.of(context).pop();
          },
          child: const Text('추가'),
        ),
      ],
    );
  }
}
