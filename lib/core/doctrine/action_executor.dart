
import 'execution_result.dart';

class ActionExecutor {
  static final ActionExecutor instance = ActionExecutor._();

  ActionExecutor._();

  Future<ExecutionResult> execute(plan) async {
    // TODO: Implement actual store writes here
    return ExecutionResult(success: true);
  }
}
