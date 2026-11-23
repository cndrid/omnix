/// Konfigurasi Supabase proyek omnix (M0 revamp).
///
/// Nilai diambil dari `~/workspace/replica-spotify/replica/supabase-config.md`
/// (dashboard Supabase, 23 Nov 2026).
///
/// [supabasePublishableKey] adalah kunci PUBLIK (publishable/anon key):
/// aman disematkan di aplikasi karena semua akses data dibatasi oleh
/// Row Level Security (RLS) di database. JANGAN pernah menaruh
/// service_role key (kunci rahasia) di sini atau di file mana pun di repo.
library;

const String supabaseUrl = 'https://jmrppquofamctpfosnor.supabase.co';

const String supabasePublishableKey =
    'sb_publishable_d3hNrcgNQxBS3tGj-V-7aQ_6wO6wOT_';
