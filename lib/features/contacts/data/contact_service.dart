import 'contact.dart';
import 'package:cottage/helpers/supabase_service.dart';

const _contactColumns =
    'id, cottage_id, name, level, email, mobile_number, created_by, created_at';

/// CRUD for the cottage's contacts (landlord, electrician, etc).
class ContactService {
  final _client = SupabaseService.client;

  Future<List<Contact>> getContacts(String cottageId) async {
    final rows = await _client
        .from('contacts')
        .select(_contactColumns)
        .eq('cottage_id', cottageId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((r) => Contact.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> createContact({
    required String cottageId,
    required String createdBy,
    required String name,
    String? label,
    String? mobileNumber,
    String? email,
  }) async {
    await _client.from('contacts').insert({
      'cottage_id': cottageId,
      'created_by': createdBy,
      'name': name,
      'level': label,
      'mobile_number': mobileNumber,
      'email': email,
    });
  }

  Future<void> deleteContact(String contactId) async {
    await _client.from('contacts').delete().eq('id', contactId);
  }
}
