import 'package:supabase_flutter/supabase_flutter.dart';

class CreditService {
  CreditService._();

  static Future<void> updateCredit({
    required int id,
    required double earned,
    String? remarks,
  }) async {
    await Supabase.instance.client
        .from('els_leave_credits')
        .update({
          'earned': earned,
          'remarks': (remarks != null && remarks.trim().isNotEmpty)
              ? remarks.trim()
              : null,
        })
        .eq('id', id);
  }

  static Future<void> deleteCredit(int id) async {
    await Supabase.instance.client.from('els_leave_credits').delete().eq(
      'id',
      id,
    );
  }
}
