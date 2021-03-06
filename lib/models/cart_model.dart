import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:ruagramapp/datas/cart_product.dart';
import 'package:ruagramapp/models/user_model.dart';
import 'package:scoped_model/scoped_model.dart';

class CartModel extends Model {
  //Cupom de desconto
  String cupomDesconto;
  String nomeEmpresa;
  int discountPercentage = 0;

  UserModel user;
  List<CartProduct> products = [];

  bool isLoading = false;
  CartModel(this.user) {
    if (user.isLoggedIn()) _loadCartItens();
  }

  static CartModel of(BuildContext context) =>
      ScopedModel.of<CartModel>(context);
  void addCartItem(CartProduct cartProduct) {
    products.add(cartProduct);

    Firestore.instance
        .collection("ConsumidorFinal")
        .document(user.firebaseUser.uid)
        .collection("Em Aberto")
        .document("Carrinho")
        .collection("Barbearia Transformacao")
        .add(cartProduct.toMap())
        .then((doc) {
      cartProduct.cid = doc.documentID;
    });

    notifyListeners();
  }

  void removeCartItem(CartProduct cartProduct) {
    Firestore.instance
        .collection("ConsumidorFinal")
        .document(user.firebaseUser.uid)
        .collection("cart")
        .document(cartProduct.cid)
        .delete();

    products.remove(cartProduct);

    notifyListeners();
  }

  void decProduct(CartProduct cartProduct) {
    cartProduct.quantidade--;

    Firestore.instance
        .collection("ConsumidorFinal")
        .document(user.firebaseUser.uid)
        .collection("Em Aberto")
        .document("Carrinho")
        .collection("Barbearia Transformacao")
        .document(cartProduct.cid)
        .updateData(cartProduct.toMap());

    notifyListeners();
  }

  void incProduct(CartProduct cartProduct) {
    cartProduct.quantidade++;

    Firestore.instance
        .collection("ConsumidorFinal")
        .document(user.firebaseUser.uid)
        .collection("Em Aberto")
        .document("Carrinho")
        .collection("Barbearia Transformacao")
        .document(cartProduct.cid)
        .updateData(cartProduct.toMap());

    notifyListeners();
  }

  void _loadCartItens() async {
    QuerySnapshot querySnapshot = await Firestore.instance
        .collection("ConsumidorFinal")
        .document(user.firebaseUser.uid)
        .collection("Em Aberto")
        .document("Carrinho")
        .collection("Barbearia ElShaday")
        .getDocuments();

    products = querySnapshot.documents
        .map((doc) => CartProduct.fromDocument(doc))
        .toList();
    notifyListeners();
  }

  void setCupon(String cupomCodigo, int descontoPorcentagem) {
    this.cupomDesconto = cupomCodigo;
    this.discountPercentage = descontoPorcentagem;
  }

  double getProductPrice() {
    double price = 0.0;
    for (CartProduct c in products) {
      if (c.productData != null) price += c.quantidade * c.productData.price;
    }
    return price;
  }

  double getDesconto() {
    return getProductPrice() * discountPercentage / 100;
  }

  double getFrete() {
    return 7.00;
  }

  void updatePrice() {
    notifyListeners();
  }

  Future<String> finalizarCompra() async {
    if (products.length == 0) return null;

    isLoading = true;
    notifyListeners();

    String data = formatDate(DateTime.now(), [dd, '/', mm, '/', yyyy]) +
        " às ${formatDate(DateTime.now(), [HH, ':', nn, ':', ss])}";
    double productsPrice = getProductPrice();
    double productsFrete = getFrete();
    double productsDesconto = getDesconto();

    DocumentReference referenciaOrdem =
        await Firestore.instance.collection("ordensSolicitadas").add({
      "clienteId": user.firebaseUser.uid,
      "produtos": products.map((catProduct) => catProduct.toMap()).toList(),
      "precoDoFrete": productsFrete,
      "precoDosProdutos": productsPrice,
      "desconto": productsDesconto,
      "data": formatDate(DateTime.now(), [dd, '/', mm, '/', yyyy]) +
          " às ${formatDate(DateTime.now(), [HH, ':', nn, ':', ss])}",
      "precoTotal": productsPrice - productsDesconto + productsFrete,
      "status": 1
    });

    await Firestore.instance
        .collection("ConsumidorFinal")
        .document(user.firebaseUser.uid)
        .collection("ordemPedidos")
        .document(referenciaOrdem.documentID)
        .setData({"ordemId": referenciaOrdem.documentID});

    QuerySnapshot querySnapshot = await Firestore.instance
        .collection("ConsumidorFinal")
        .document(user.firebaseUser.uid)
        .collection("Em Aberto")
        .document("Carrinho")
        .collection("Barbearia Transformacao")
        .getDocuments();
    for (DocumentSnapshot doc in querySnapshot.documents) {
      doc.reference.delete();
    }

    products.clear();

    cupomDesconto = null;
    discountPercentage = 0;

    isLoading = false;
    notifyListeners();

    return referenciaOrdem.documentID;
  }
}
