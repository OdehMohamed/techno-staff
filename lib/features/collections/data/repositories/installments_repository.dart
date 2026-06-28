import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/installment_model.dart';
import '../models/installment_plan_model.dart';
import '../../../../core/constants/firebase_paths.dart';

class InstallmentsRepository {
  final FirebaseFirestore _firestore;

  InstallmentsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createPlan(InstallmentPlanModel plan) async {
    await _firestore
        .collection(FirebasePaths.installmentPlans)
        .add(plan.toCreateMap());
  }

  Future<InstallmentPlanModel?> getPlanForDebt(String debtId) async {
    final snap = await _firestore
        .collection(FirebasePaths.installmentPlans)
        .where('debtId', isEqualTo: debtId)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return InstallmentPlanModel.fromMap(doc.data(), doc.id);
  }

  Future<List<InstallmentModel>> getInstallments(String planId) async {
    final snap = await _firestore
        .collection(FirebasePaths.installmentPlans)
        .doc(planId)
        .collection(FirebasePaths.installments)
        .get(const GetOptions(source: Source.server));
    final list = snap.docs
        .map((d) => InstallmentModel.fromMap(d.data(), d.id))
        .toList();
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }
}
