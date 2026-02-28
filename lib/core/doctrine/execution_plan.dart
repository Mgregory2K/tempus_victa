class ExecutionPlan {
  final String surface;
  final String rawText;
  final double confidence;
  final List<DoctrineAction> actions;

  ExecutionPlan({
    required this.surface,
    required this.rawText,
    required this.actions,
    this.confidence = 0.5,
  });

  bool get isEmpty => actions.isEmpty;
}

abstract class DoctrineAction {
  const DoctrineAction();
}

class CreateTaskAction extends DoctrineAction {
  final String title;
  final String transcript;
  final int? audioDurationMs;
  const CreateTaskAction({
    required this.title,
    required this.transcript,
    this.audioDurationMs,
  });
}

class CreateListIfMissingAction extends DoctrineAction {
  final String name;
  const CreateListIfMissingAction(this.name);
}

class AddListItemsAction extends DoctrineAction {
  final String listName;
  final List<String> items;
  const AddListItemsAction({required this.listName, required this.items});
}

class RemoveListItemsAction extends DoctrineAction {
  final String listName;
  final List<String> items;
  const RemoveListItemsAction({required this.listName, required this.items});
}

class ClearListAction extends DoctrineAction {
  final String listName;
  const ClearListAction(this.listName);
}

class CorkItAction extends DoctrineAction {
  final String text;
  const CorkItAction(this.text);
}

class CreateProjectAction extends DoctrineAction {
  final String name;
  const CreateProjectAction(this.name);
}
