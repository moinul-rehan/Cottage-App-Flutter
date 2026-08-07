import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import '../data/member_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';

/// Displays all active members of a cottage with avatars, names, and emails.
class MembersScreen extends StatefulWidget {
  final String cottageId;
  const MembersScreen({super.key, required this.cottageId});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _memberService = MemberService();
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _memberService.getActiveMembers(widget.cottageId);
  }

  void _refresh() {
    setState(() => _future = _memberService.getActiveMembers(widget.cottageId));
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_rounded, color: CottageColors.primary, size: 22),
            const SizedBox(width: 8),
            const Text('Members'),
          ],
        ),
      ),
      body: FutureBuilder<List<Profile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40, color: CottageColors.destructive),
                  const SizedBox(height: 12),
                  Text('Could not load members.\n${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }

          final members = snapshot.data!;
          if (members.isEmpty) {
            return const EmptyState(
              icon: Icons.people_rounded,
              title: 'No members found',
              subtitle: 'There are no active members in this cottage.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: context.responsivePadding,
                vertical: 12,
              ),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: surface.accent,
                          backgroundImage:
                              member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                          child: member.avatarUrl == null
                              ? Text(
                                  member.firstName.isNotEmpty
                                      ? member.firstName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: surface.accentForeground,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.fullName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: surface.foreground,
                                ),
                              ),
                              if (member.email != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  member.email!,
                                  style: TextStyle(fontSize: 13, color: surface.mutedForeground),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: surface.toneGreenBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: surface.toneGreenFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
