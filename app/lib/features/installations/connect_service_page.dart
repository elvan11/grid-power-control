import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_responsive.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/provider_functions_service.dart';

Map<String, String> parseSolisConfigValues(Map<String, dynamic>? config) {
  String asText(dynamic value) => value is String ? value : '';

  return {
    'inverterSn': asText(config?['inverterSn']),
    'apiId': asText(config?['apiId']),
    'apiSecret': asText(config?['apiSecret']),
    'apiBaseUrl': asText(config?['apiBaseUrl']),
  };
}

class ConnectServicePage extends ConsumerStatefulWidget {
  const ConnectServicePage({required this.plantId, super.key});

  final String plantId;

  @override
  ConsumerState<ConnectServicePage> createState() => _ConnectServicePageState();
}

class _ConnectServicePageState extends ConsumerState<ConnectServicePage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _inverterSnController = TextEditingController();
  final _apiIdController = TextEditingController();
  final _apiSecretController = TextEditingController();
  final _apiBaseUrlController = TextEditingController();

  bool _isLoading = false;
  bool _hideSecret = true;
  String? _statusMessage;
  bool? _statusSuccess;

  @override
  void initState() {
    super.initState();
    _loadExistingConnection();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _inverterSnController.dispose();
    _apiIdController.dispose();
    _apiSecretController.dispose();
    _apiBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConnection() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null || widget.plantId.startsWith('local-')) {
      return;
    }
    try {
      final connection = await client
          .from('provider_connections')
          .select('display_name,config_json')
          .eq('plant_id', widget.plantId)
          .eq('provider_type', 'soliscloud')
          .maybeSingle();
      if (connection == null || !mounted) {
        return;
      }
      _displayNameController.text =
          (connection['display_name'] as String?) ?? '';
      final configValues = parseSolisConfigValues(
        connection['config_json'] as Map<String, dynamic>?,
      );
      _inverterSnController.text = configValues['inverterSn']!;
      _apiIdController.text = configValues['apiId']!;
      _apiSecretController.text = configValues['apiSecret']!;
      _apiBaseUrlController.text = configValues['apiBaseUrl']!;
      setState(() {});
    } catch (_) {
      // Non-blocking load failure: page remains editable.
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final service = ref.read(providerFunctionsServiceProvider);
      final result = await service.testProviderConnection(
        plantId: widget.plantId,
        inverterSn: _inverterSnController.text.trim(),
        apiId: _apiIdController.text.trim(),
        apiSecret: _apiSecretController.text.trim(),
        apiBaseUrl: _apiBaseUrlController.text.trim(),
      );
      setState(() {
        _statusSuccess = result['ok'] == true;
        _statusMessage =
            (result['message'] as String?) ??
            (_statusSuccess == true
                ? 'Connection test succeeded.'
                : 'Connection test failed.');
      });
    } catch (error) {
      setState(() {
        _statusSuccess = false;
        _statusMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final service = ref.read(providerFunctionsServiceProvider);
      final result = await service.upsertProviderConnection(
        plantId: widget.plantId,
        displayName: _displayNameController.text.trim(),
        inverterSn: _inverterSnController.text.trim(),
        apiId: _apiIdController.text.trim(),
        apiSecret: _apiSecretController.text.trim(),
        apiBaseUrl: _apiBaseUrlController.text.trim(),
      );
      setState(() {
        _statusSuccess = result['ok'] == true;
        _statusMessage = _statusSuccess == true
            ? 'Cloud connection saved.'
            : (result['error'] as String?);
      });
    } catch (error) {
      setState(() {
        _statusSuccess = false;
        _statusMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GpPageScaffold(
      title: 'Connect Cloud Service',
      showBack: true,
      backFallbackRoute: '/installations',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = GpResponsiveBreakpoints.layoutForWidth(
            constraints.maxWidth,
          );
          final isCompact = layout == GpWindowSize.compact;
          const spacing = 12.0;
          final halfWidth = (constraints.maxWidth - spacing) / 2;

          Widget fieldSlot(Widget child, {bool fullWidth = false}) {
            final width = isCompact || fullWidth
                ? constraints.maxWidth
                : halfWidth;
            return SizedBox(width: width, child: child);
          }

          return ListView(
            children: [
              const GpSectionCard(
                child: Text(
                  'Connect SolisCloud for remote control. Credentials are stored server-side only and are never returned to the app.',
                ),
              ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Wrap(
                  spacing: spacing,
                  runSpacing: 10,
                  children: [
                    fieldSlot(
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Installation display name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Display name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    fieldSlot(
                      TextFormField(
                        initialValue: 'SolisCloud',
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Provider',
                        ),
                      ),
                    ),
                    fieldSlot(
                      TextFormField(
                        controller: _inverterSnController,
                        decoration: const InputDecoration(
                          labelText: 'Inverter serial number',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inverter serial number is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    fieldSlot(
                      TextFormField(
                        controller: _apiIdController,
                        decoration: const InputDecoration(
                          labelText: 'Solis API ID',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'API ID is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    fieldSlot(
                      TextFormField(
                        controller: _apiSecretController,
                        obscureText: _hideSecret,
                        decoration: InputDecoration(
                          labelText: 'Solis API Secret',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _hideSecret = !_hideSecret),
                            icon: Icon(
                              _hideSecret
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'API secret is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    fieldSlot(
                      TextFormField(
                        controller: _apiBaseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Custom API base URL (optional)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_statusMessage != null) ...[
                GpSectionCard(
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: (_statusSuccess ?? false)
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (isCompact) ...[
                GpSecondaryButton(
                  label: _isLoading ? 'Testing...' : 'Test Connection',
                  icon: Icons.network_check_outlined,
                  onPressed: _isLoading ? null : _testConnection,
                ),
                const SizedBox(height: 8),
                GpPrimaryButton(
                  label: _isLoading ? 'Saving...' : 'Save Installation',
                  icon: Icons.save_outlined,
                  onPressed: _isLoading ? null : _saveConnection,
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: GpSecondaryButton(
                        label: _isLoading ? 'Testing...' : 'Test Connection',
                        icon: Icons.network_check_outlined,
                        onPressed: _isLoading ? null : _testConnection,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GpPrimaryButton(
                        label: _isLoading ? 'Saving...' : 'Save Installation',
                        icon: Icons.save_outlined,
                        onPressed: _isLoading ? null : _saveConnection,
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
