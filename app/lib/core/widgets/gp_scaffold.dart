import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GpSectionCard extends StatelessWidget {
  const GpSectionCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: padding, child: child),
    );
  }
}

class GpPageScaffold extends StatelessWidget {
  const GpPageScaffold({
    required this.title,
    required this.body,
    super.key,
    this.actions,
    this.bottom,
    this.showBack = false,
    this.backFallbackRoute,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool showBack;
  final String? backFallbackRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
        leading: showBack
            ? BackButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                    return;
                  }
                  if (backFallbackRoute != null) {
                    context.go(backFallbackRoute!);
                  }
                },
              )
            : null,
        actions: actions,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(padding: const EdgeInsets.all(16), child: body),
        ),
      ),
      bottomNavigationBar: bottom,
    );
  }
}

class GpAsyncStateView<T> extends StatelessWidget {
  const GpAsyncStateView({
    required this.value,
    required this.dataBuilder,
    super.key,
    this.onRetry,
    this.emptyBuilder,
  });

  final AsyncSnapshot<T> value;
  final Widget Function(T data) dataBuilder;
  final VoidCallback? onRetry;
  final WidgetBuilder? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    if (value.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (value.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Something went wrong: ${value.error}'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final data = value.data;
    if (data == null) {
      return emptyBuilder?.call(context) ?? const SizedBox.shrink();
    }
    return dataBuilder(data);
  }
}
