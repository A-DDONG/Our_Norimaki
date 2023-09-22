import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MenuPage extends StatefulWidget {
  final int tableNumber;

  const MenuPage({super.key, required this.tableNumber});

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  Map<String, Map<String, dynamic>> selectedItems = {};

  void addItem(String name, int price, String code) {
    if (selectedItems.containsKey(name)) {
      selectedItems[name]!['quantity'] += 1;
      selectedItems[name]!['totalPrice'] += price;
    } else {
      selectedItems[name] = {
        'price': price,
        'quantity': 1,
        'totalPrice': price,
        'code': code, // 상품 코드 추가
        'name': name // 상품 이름 추가
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('테이블 ${widget.tableNumber} - 메뉴 선택')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream:
                  FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                return ListView.builder(
                  itemCount: snapshot.data?.docs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot menu = snapshot.data!.docs[index];
                    print(menu['name']);
                    return ListTile(
                      title: Text(menu['name']),
                      subtitle: Text('${menu['price']}원'),
                      onTap: () {
                        if (menu['name'] != null &&
                            menu['price'] != null &&
                            menu['code'] != null) {
                          setState(() {
                            addItem(menu['name'],
                                (menu['price'] as num).toInt(), menu['code']);
                          });
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          const Text('선택한 상품'),
          Expanded(
            child: ListView.builder(
              itemCount: selectedItems.length,
              itemBuilder: (context, index) {
                String key = selectedItems.keys.elementAt(index);
                return ListTile(
                  title: Text(key),
                  subtitle: Text(
                      '단가: ${selectedItems[key]!['price']}원, 수량: ${selectedItems[key]!['quantity']}, 금액: ${selectedItems[key]!['totalPrice']}원'),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => PaymentDialog(
                  tableNumber: widget.tableNumber,
                  selectedItems: selectedItems,
                ),
              );
            },
            child: const Text('결제하기'),
          ),
        ],
      ),
    );
  }
}

class PaymentDialog extends StatelessWidget {
  final int tableNumber;
  final Map<String, Map<String, dynamic>> selectedItems;

  const PaymentDialog(
      {super.key, required this.tableNumber, required this.selectedItems});

  Future<void> clearTable() async {
    // 여기에 테이블을 초기화하는 로직을 추가할 수 있습니다.
    // 예를 들어, Firestore에서 해당 테이블의 데이터를 삭제하는 등
  }

  @override
  Widget build(BuildContext context) {
    int totalAmount = 0;

    selectedItems.forEach((key, value) {
      totalAmount += (value['totalPrice'] as num).toInt();
    });

    return AlertDialog(
      title: Text('테이블 $tableNumber - 결제'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('선택한 메뉴와 금액'),
          ...selectedItems.keys.map((key) {
            return Text(
                '$key - ${selectedItems[key]!['quantity']}개 - ${selectedItems[key]!['totalPrice']}원');
          }).toList(),
          const Divider(),
          Text('총 금액: $totalAmount원'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await savePaymentInfo(
                selectedItems, totalAmount, '현금'); // 현금 결제 정보 저장
            await clearTable();
            Navigator.pop(context);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('현금 $totalAmount 원이 결제되었습니다.')),
            );
          },
          child: const Text('현금 결제'),
        ),
        TextButton(
          onPressed: () async {
            await savePaymentInfo(
                selectedItems, totalAmount, '카드'); // 카드 결제 정보 저장
            await clearTable();
            Navigator.pop(context);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('카드 $totalAmount 원이 결제되었습니다.')),
            );
          },
          child: const Text('카드 결제'),
        ),
      ],
    );
  }

  Future<void> savePaymentInfo(Map<String, Map<String, dynamic>> items,
      int totalAmount, String paymentMethod) async {
    CollectionReference payments =
        FirebaseFirestore.instance.collection('payments');
    CollectionReference counters =
        FirebaseFirestore.instance.collection('counters');

    // 판매 SEQ 자동 생성
    DocumentSnapshot counterDoc = await counters.doc('salesCounter').get();
    int nextSeq = counterDoc.exists ? counterDoc['nextSeq'] : 1;
    String seq = nextSeq.toString().padLeft(10, '0');

    // 판매 정보 저장
    await payments.add({
      'seq': seq,
      'tableNumber': tableNumber,
      'items': items,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'timestamp': Timestamp.now(),
    });

    // 카운터 업데이트
    await counters.doc('salesCounter').set({'nextSeq': nextSeq + 1});
  }
}
