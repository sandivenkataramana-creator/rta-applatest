import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/page_header_banner.dart';
import '../../data/file_picker_service.dart';
import '../../data/models/support_ticket.dart';
import '../providers/support_provider.dart';
import '../widgets/support_overview_card.dart';
import '../widgets/ticket_search_filter.dart';
import '../widgets/upload_attachment_widget.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<SelectedAttachment> _selectedAttachments = [];
  bool _showCreateTicket = false;
  bool _uploading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load tickets once when the screen is first displayed
      ref.read(supportControllerProvider.notifier).loadTickets();
    });
  }

  Future<void> _pickFiles() async {
    try {
      final attachments = await FilePickerService.pickFiles(
        allowMultiple: true,
      );
      if (!mounted) return;
      if (attachments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No files were selected.')),
        );
        return;
      }
      setState(() {
        _selectedAttachments
          ..clear()
          ..addAll(attachments);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${attachments.length} file${attachments.length == 1 ? '' : 's'} selected.',
          ),
        ),
      );
    } on FilePickerException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to pick files right now.')),
      );
    }
  }

  void _toggleCreateTicket() {
    setState(() {
      _showCreateTicket = !_showCreateTicket;
    });
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(supportControllerProvider.notifier);
    try {
      setState(() => _uploading = true);
      await controller.createTicket(
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        attachments: _selectedAttachments
            .map((attachment) => attachment.path)
            .toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support ticket created successfully.')),
      );
      _subjectController.clear();
      _messageController.clear();
      setState(() {
        _selectedAttachments.clear();
        _uploading = false;
      });
      await controller.refreshTickets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportControllerProvider);
    final tickets = ref.watch(supportTicketsProvider);
    final total = tickets.length;
    final open = tickets.where((ticket) => ticket.isOpen).length;
    final closed = tickets.where((ticket) => ticket.isClosed).length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(supportControllerProvider.notifier).refreshTickets(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeaderBanner(
                title: 'Support Center',
                subtitle: 'Create and review support tickets',
              ),
              const SizedBox(height: 16),
              SupportOverviewCard(total: total, open: open, closed: closed),
              const SizedBox(height: 20),
              _buildToggleButton(),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _showCreateTicket
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildCreateTicketCard(),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              TicketSearchFilter(searchController: _searchController),
              const SizedBox(height: 16),
              if (state.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (state.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    state.error!,
                    style: GoogleFonts.poppins(color: const Color(0xFFBE123C)),
                  ),
                )
              else if (tickets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No tickets found',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tickets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return _TicketCard(ticket: ticket);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _toggleCreateTicket,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF08C7B5),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        icon: AnimatedRotation(
          turns: _showCreateTicket ? 0.5 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Icon(
            _showCreateTicket
                ? Icons.keyboard_arrow_up
                : Icons.add_circle_outline,
          ),
        ),
        label: Text(
          _showCreateTicket ? 'Hide Form' : 'Raise Ticket',
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCreateTicketCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Ticket',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Subject is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Message'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Message is required'
                    : null,
              ),
              const SizedBox(height: 12),
              UploadAttachmentWidget(
                attachments: _selectedAttachments,
                onPickFiles: _pickFiles,
                onRemoveAttachment: (attachment) {
                  setState(() {
                    _selectedAttachments.removeWhere(
                      (item) => item.path == attachment.path,
                    );
                  });
                },
                isUploading: _uploading,
                onClearAll: () {
                  setState(() {
                    _selectedAttachments.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _submitTicket,
                  child: _uploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Ticket'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> confirmDelete() async {
      if (ticket.id == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            title: const Text('Delete Ticket'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Are you sure you want to delete this ticket?'),
                const SizedBox(height: 10),
                Text('Ticket ID: #${ticket.id ?? '-'}'),
                const SizedBox(height: 4),
                Text('Subject: ${ticket.subject}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      try {
        await ref
            .read(supportControllerProvider.notifier)
            .deleteTicket(ticketId: ticket.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket deleted successfully.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e is ApiException ? e.message : e.toString()),
            ),
          );
        }
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${ticket.id ?? '-'}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF08C7B5),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ticket.isOpen
                        ? const Color(0xFFF6C453)
                        : const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ticket.displayStatus,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ticket.subject,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ticket.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Text(
              'Created By: ${ticket.createdBy}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Created Date: ${ticket.createdAt?.toLocal().toString().split('.').first ?? '-'}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/support/${ticket.id}'),
                    child: const Text('View Ticket'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: confirmDelete,
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
