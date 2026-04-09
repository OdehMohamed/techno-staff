import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/tasks_repository.dart';
import 'task_details_screen.dart';

class TaskDetailsLoaderScreen extends StatelessWidget {
  final String taskId;

  const TaskDetailsLoaderScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final repository = TasksRepository(FirebaseFirestore.instance);

    return FutureBuilder(
      future: repository.getTaskById(taskId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Scaffold(body: Center(child: Text('Task not found')));
        }

        return TaskDetailsScreen(task: snapshot.data!);
      },
    );
  }
}
