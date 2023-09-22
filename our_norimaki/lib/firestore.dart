import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> addProduct(String name, int price) async {
  CollectionReference products =
      FirebaseFirestore.instance.collection('products');

  return products
      .add({
        'name': name, // 상품 이름
        'price': price, // 상품 가격
      })
      .then((value) => print("상품 추가 성공"))
      .catchError((error) => print("상품 추가 실패: $error"));
}
