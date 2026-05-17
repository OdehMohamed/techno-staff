import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_paths.dart';
import '../models/task_template_model.dart';

class TemplatesRepository {
  final FirebaseFirestore _firestore;

  TemplatesRepository(this._firestore);

  Future<List<TaskTemplateModel>> getAllTemplates() async {
    final snapshot = await _firestore
        .collection(FirebasePaths.taskTemplates)
        .orderBy('createdAt', descending: true)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => TaskTemplateModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<TaskTemplateModel?> getTemplateById(String templateId) async {
    final doc = await _firestore
        .collection(FirebasePaths.taskTemplates)
        .doc(templateId)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists) return null;
    return TaskTemplateModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> createTemplate(TaskTemplateModel template) async {
    await _firestore
        .collection(FirebasePaths.taskTemplates)
        .add(template.toMap());
  }

  Future<void> updateTemplate(TaskTemplateModel template) async {
    await _firestore
        .collection(FirebasePaths.taskTemplates)
        .doc(template.id)
        .update(template.toMap());
  }

  Future<void> setTemplateActive(String templateId, bool isActive) async {
    await _firestore
        .collection(FirebasePaths.taskTemplates)
        .doc(templateId)
        .update({
          'isActive': isActive,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  Future<void> deleteTemplate(String templateId) async {
    await _firestore
        .collection(FirebasePaths.taskTemplates)
        .doc(templateId)
        .delete();
  }
}
