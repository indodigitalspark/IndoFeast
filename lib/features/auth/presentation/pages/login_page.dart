import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/breakpoints.dart';
import '../../../../models/user_role.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/app_brand_panel.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/registration_request.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_card.dart';

enum _AuthMode { signIn, register }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.initialMode, this.initialRole});

  final String? initialMode;
  final String? initialRole;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerOtpController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _vehicleLabelController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  UserRole _selectedRegisterRole = UserRole.customer;
  List<int>? _documentBytes;
  String? _documentName;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == 'register'
        ? _AuthMode.register
        : _AuthMode.signIn;

    final requestedRole = UserRole.fromValue(widget.initialRole);
    if (const [
      UserRole.customer,
      UserRole.vendor,
      UserRole.deliveryPartner,
    ].contains(requestedRole)) {
      _selectedRegisterRole = requestedRole;
    }

    ref.listenManual(authControllerProvider, _handleAuthState);
  }

  void _handleAuthState(
    AsyncValue<AuthSession>? previous,
    AsyncValue<AuthSession> next,
  ) {
    if (!mounted) {
      return;
    }

    next.whenOrNull(
      data: (session) {
        if (session.message != null && session.message!.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(session.message!)));
        }

        final user = session.user;
        if (user != null && user.canAccessDashboard) {
          context.go(user.role.dashboardRoute);
        }
      },
      error: (error, stackTrace) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.toString())));
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPhoneController.dispose();
    _registerPasswordController.dispose();
    _registerOtpController.dispose();
    _businessNameController.dispose();
    _vehicleLabelController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() {
    return ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
  }

  Future<void> _sendRegistrationOtp() {
    return ref
        .read(authControllerProvider.notifier)
        .sendPhoneOtp(
          phoneNumber: _registerPhoneController.text.trim(),
          role: _selectedRegisterRole,
        );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file?.bytes == null || file?.name == null) {
      return;
    }

    setState(() {
      _documentBytes = file!.bytes!;
      _documentName = file.name;
    });
  }

  Future<void> _register() {
    return ref
        .read(authControllerProvider.notifier)
        .register(
          RegistrationRequest(
            displayName: _registerNameController.text.trim(),
            email: _registerEmailController.text.trim(),
            phoneNumber: _registerPhoneController.text.trim(),
            password: _registerPasswordController.text.trim(),
            role: _selectedRegisterRole,
            otp: _registerOtpController.text.trim(),
            documentBytes: _documentBytes,
            documentName: _documentName,
            businessName: _selectedRegisterRole == UserRole.vendor
                ? _businessNameController.text.trim()
                : null,
            vehicleLabel: _selectedRegisterRole == UserRole.deliveryPartner
                ? _vehicleLabelController.text.trim()
                : null,
          ),
        );
  }

  bool get _requiresApproval =>
      _selectedRegisterRole == UserRole.vendor ||
      _selectedRegisterRole == UserRole.deliveryPartner;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= Breakpoints.tablet;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: AppBrandPanel(
                                title:
                                    'One secure login and registration flow for every IndoFeast user.',
                                subtitle:
                                    'Customers can start after OTP verification. Vendor stores and delivery partners register with OTP and wait for Super Admin, Admin, or Manager approval.',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(child: _buildAuthCard(authState)),
                          ],
                        )
                      : _buildAuthCard(authState),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard(AsyncValue<AuthSession> authState) {
    final isLoading = authState.isLoading;
    final otpSent = authState.valueOrNull?.isOtpSent ?? false;

    return AuthFormCard(
      title: _mode == _AuthMode.signIn ? 'Portal Sign In' : 'Create Account',
      subtitle: _mode == _AuthMode.signIn
          ? 'Use your approved IndoFeast account. Your username and password automatically open the correct portal.'
          : 'Register as Customer, Vendor (Store), or Delivery Boy. OTP verification is required before signup is completed.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<_AuthMode>(
            segments: const [
              ButtonSegment<_AuthMode>(
                value: _AuthMode.signIn,
                label: Text('Sign In'),
                icon: Icon(Icons.login),
              ),
              ButtonSegment<_AuthMode>(
                value: _AuthMode.register,
                label: Text('Register'),
                icon: Icon(Icons.person_add_alt_1),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: isLoading
                ? null
                : (selection) => setState(() => _mode = selection.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_mode == _AuthMode.signIn)
            _buildSignInForm(isLoading)
          else
            _buildRegisterForm(isLoading, otpSent),
        ],
      ),
    );
  }

  Widget _buildSignInForm(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'User ID or Email',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading ? null : _loginWithEmail,
            child: Text(
              isLoading ? 'Checking account access...' : 'Sign In to My Portal',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(bool isLoading, bool otpSent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<UserRole>(
          initialValue: _selectedRegisterRole,
          decoration: const InputDecoration(
            labelText: 'Register As',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          items: const [
            DropdownMenuItem(value: UserRole.customer, child: Text('Customer')),
            DropdownMenuItem(
              value: UserRole.vendor,
              child: Text('Vendor (Store)'),
            ),
            DropdownMenuItem(
              value: UserRole.deliveryPartner,
              child: Text('Delivery Boy'),
            ),
          ],
          onChanged: isLoading
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedRegisterRole = value;
                    _documentBytes = null;
                    _documentName = null;
                  });
                },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _registerNameController,
          decoration: InputDecoration(
            labelText: _selectedRegisterRole == UserRole.vendor
                ? 'Owner Full Name'
                : 'Full Name',
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_selectedRegisterRole == UserRole.vendor) ...[
          TextField(
            controller: _businessNameController,
            decoration: const InputDecoration(
              labelText: 'Store Name',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_selectedRegisterRole == UserRole.deliveryPartner) ...[
          TextField(
            controller: _vehicleLabelController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Type',
              hintText: 'Bike / Scooter / Cycle',
              prefixIcon: Icon(Icons.two_wheeler_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          controller: _registerEmailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _registerPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _registerPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Create Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        if (_requiresApproval) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: isLoading ? null : _pickDocument,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              _documentName == null
                  ? 'Upload Verification Document'
                  : 'Document: $_documentName',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _selectedRegisterRole == UserRole.vendor
                ? 'Vendor registration needs a store verification document and approval from Admin, Super Admin, or Manager.'
                : 'Delivery registration needs an ID or work verification document and approval from Admin, Super Admin, or Manager.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.tonalIcon(
              onPressed: isLoading ? null : _sendRegistrationOtp,
              icon: const Icon(Icons.sms_outlined),
              label: Text(otpSent ? 'Resend OTP' : 'Send OTP'),
            ),
            if (_selectedRegisterRole == UserRole.customer)
              Chip(
                label: const Text('Customer account starts immediately'),
                avatar: const Icon(Icons.verified_user_outlined, size: 18),
              )
            else
              Chip(
                label: const Text('Approval required after OTP'),
                avatar: const Icon(Icons.pending_actions_outlined, size: 18),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _registerOtpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'OTP Verification Code',
            prefixIcon: Icon(Icons.password_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading ? null : _register,
            child: Text(
              isLoading
                  ? 'Creating account...'
                  : _selectedRegisterRole == UserRole.customer
                  ? 'Verify OTP and Create Customer Account'
                  : 'Verify OTP and Submit for Approval',
            ),
          ),
        ),
      ],
    );
  }
}
