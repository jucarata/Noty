/// Único tubo de la app hacia el servidor.
///
/// Hoy encapsulará Supabase; mañana una API propia. Las pantallas no usan
/// esta clase: solo `data/remote` o los services de cada feature.
class BackendClient {
  BackendClient();
}
