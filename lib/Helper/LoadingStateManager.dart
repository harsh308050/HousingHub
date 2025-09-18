import 'package:flutter/material.dart';
import 'package:housinghub/Helper/Models.dart';

/// A utility class to manage loading states safely in Flutter
class LoadingStateManager {
  /// Safely executes an async operation and manages loading state
  ///
  /// - [context] The BuildContext to check if the widget is still mounted
  /// - [loadingState] A function that updates the loading state
  /// - [operation] The async operation to execute
  /// - [onSuccess] Callback executed on success
  /// - [onError] Callback executed on error
  /// - [finallyCallback] Optional callback that always executes at the end
  static Future<void> runWithLoader<T>({
    required BuildContext context,
    required Function(bool) loadingState,
    required Future<T> Function() operation,
    required Function(T) onSuccess,
    required Function(Object) onError,
    Function()? finallyCallback,
  }) async {
    try {
      loadingState(true);

      final result = await operation();

      // Check if the widget is still in the tree before updating state
      if (context.mounted) {
        onSuccess(result);
      }
    } catch (e) {
      // Only update UI if widget is still mounted
      if (context.mounted) {
        onError(e);
      }
    } finally {
      // Always reset loading state if widget is still mounted
      if (context.mounted) {
        loadingState(false);
      }

      if (finallyCallback != null && context.mounted) {
        finallyCallback();
      }
    }
  }

  /// Timeout feature to automatically end loading state after a specified duration
  static Future<void> withTimeout({
    required BuildContext context,
    required Function(bool) loadingState,
    required Future Function() operation,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    bool operationComplete = false;

    try {
      loadingState(true);

      await Future.any([
        operation().then((_) {
          operationComplete = true;
        }),
        Future.delayed(timeout),
      ]);

      if (!operationComplete && context.mounted) {
        // Operation timed out
        loadingState(false);
        Models.showWarningSnackBar(
            context, 'Operation timed out. Please try again.');
      }
    } catch (e) {
      if (context.mounted) {
        loadingState(false);
        Models.showErrorSnackBar(context, 'Error: ${e.toString()}');
      }
    }
  }
}
