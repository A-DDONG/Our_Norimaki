import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  _SalesHistoryPageState createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  DateTime? startDate;
  DateTime? endDate;
  bool showByProduct = false;
  Map<String, Map<String, int>> productData = {};

  bool sortAscending = true;
  int sortColumnIndex = 0;

  onSort(int columnIndex, bool ascending) {
    if (showByProduct) {
      List<MapEntry<String, Map<String, int>>>? sortedEntries; // nullable로 선언
      if (columnIndex == 1) {
        sortedEntries = productData.entries.toList()
          ..sort((a, b) => ascending
              ? a.value['totalPrice']!.compareTo(b.value['totalPrice']!)
              : b.value['totalPrice']!.compareTo(a.value['totalPrice']!));
      } else if (columnIndex == 2) {
        sortedEntries = productData.entries.toList()
          ..sort((a, b) => ascending
              ? a.value['quantity']!.compareTo(b.value['quantity']!)
              : b.value['quantity']!.compareTo(a.value['quantity']!));
      }

      if (sortedEntries != null) {
        // null 체크 추가
        setState(() {
          productData = Map.fromEntries(sortedEntries!);
          sortAscending = ascending;
          sortColumnIndex = columnIndex;
        });
      }
    }
  }

  Stream<QuerySnapshot> getSalesHistoryStream() {
    Query query = FirebaseFirestore.instance
        .collection('payments')
        .orderBy('timestamp', descending: true);

    if (startDate != null && endDate != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!),
          isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
    } else if (startDate != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!));
    } else if (endDate != null) {
      query = query.where('timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('판매 내역'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                showByProduct = !showByProduct;
              });
            },
            child: Text(showByProduct ? '기간별 보기' : '상품별 보기'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: () async {
                  DateTime? selectedDate = await showDatePicker(
                    context: context,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (selectedDate != null && selectedDate != startDate) {
                    setState(() {
                      startDate = selectedDate;
                    });
                  }
                },
                child: Text(
                    '시작 날짜: ${startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : "선택 안됨"}'),
              ),
              ElevatedButton(
                onPressed: () async {
                  DateTime? selectedDate = await showDatePicker(
                    context: context,
                    initialDate: endDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (selectedDate != null && selectedDate != endDate) {
                    setState(() {
                      endDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          23,
                          59,
                          59); // 종료 날짜의 시간을 23:59:59로 설정
                    });
                  }
                },
                child: Text(
                    '종료 날짜: ${endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : "선택 안됨"}'),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder(
              stream: getSalesHistoryStream(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                List<DataRow> rows = [];

                if (showByProduct) {
                  productData.clear();
                  for (var doc in snapshot.data!.docs) {
                    var seq = doc['seq'].toString();
                    var items = doc['items'];
                    if (items != null) {
                      for (var item in items.values) {
                        var name = item['name'];
                        var price = item['totalPrice'];
                        var quantity = item['quantity'];
                        var productCode = item['productCode'];

                        if (productData[name] == null) {
                          productData[name] = {'totalPrice': 0, 'quantity': 0};
                        }

                        productData[name]!['totalPrice'] =
                            ((productData[name]!['totalPrice'] ?? 0) + price)
                                .toInt();
                        productData[name]!['quantity'] =
                            ((productData[name]!['quantity'] ?? 0) + quantity)
                                .toInt();
                      }
                    }
                  }
                  // 정렬 로직 추가
                  if (sortColumnIndex == 1) {
                    productData = Map.fromEntries(
                      productData.entries.toList()
                        ..sort((a, b) => sortAscending
                            ? a.value['totalPrice']!
                                .compareTo(b.value['totalPrice']!)
                            : b.value['totalPrice']!
                                .compareTo(a.value['totalPrice']!)),
                    );
                  } else if (sortColumnIndex == 2) {
                    productData = Map.fromEntries(
                      productData.entries.toList()
                        ..sort((a, b) => sortAscending
                            ? a.value['quantity']!
                                .compareTo(b.value['quantity']!)
                            : b.value['quantity']!
                                .compareTo(a.value['quantity']!)),
                    );
                  }

                  rows = productData.entries.map((e) {
                    return DataRow(cells: [
                      DataCell(Text(e.key)),
                      DataCell(Text(e.value['totalPrice'].toString())),
                      DataCell(Text(e.value['quantity'].toString())),
                    ]);
                  }).toList();
                } else if (!showByProduct) {
                  rows = snapshot.data!.docs.map((doc) {
                    var items = doc['items'];
                    List<String> productNames = [];
                    int totalQuantity = 0;

                    if (items != null) {
                      for (var item in items.values) {
                        productNames.add(item['name']);
                        totalQuantity = (item['quantity'] as num).toInt();
                      }
                    }

                    return DataRow(cells: [
                      DataCell(Text(doc['seq'].toString())),
                      DataCell(Text(doc['tableNumber'].toString())),
                      DataCell(Text(DateFormat('yyyy-MM-dd')
                          .format(doc['timestamp'].toDate()))),
                      DataCell(Text(productNames.join(", "))), // 상품 이름 나열
                      DataCell(Text(totalQuantity.toString())), // 판매 수량
                      DataCell(Text(doc['totalAmount'].toString())),
                      DataCell(Text(doc['paymentMethod'].toString())),
                    ]);
                  }).toList();
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    sortColumnIndex: sortColumnIndex,
                    sortAscending: sortAscending,
                    columns: showByProduct
                        ? [
                            const DataColumn(label: Text('상품')),
                            DataColumn(
                                label: const Text('총 판매액'),
                                numeric: true,
                                onSort: (columnIndex, ascending) {
                                  onSort(columnIndex, ascending);
                                }),
                            DataColumn(
                                label: const Text('총 판매수량'),
                                numeric: true,
                                onSort: (columnIndex, ascending) {
                                  onSort(columnIndex, ascending);
                                }),
                          ]
                        : [
                            const DataColumn(label: Text('SEQ')),
                            const DataColumn(label: Text('테이블 번호')),
                            const DataColumn(label: Text('판매일자')),
                            const DataColumn(label: Text('판매상품')),
                            const DataColumn(label: Text('판매수량')),
                            const DataColumn(label: Text('판매금액')),
                            const DataColumn(label: Text('결제방법')),
                          ],
                    rows: rows,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
