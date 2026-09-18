/// Base class for one-shot events delivered by [SideEffectBloc].
///
/// Side effects are compared by identity, which is what `Object` already
/// provides. Overriding `==` to return false breaks the reflexivity the rest
/// of the language relies on (`a == a`), and a `hashCode` derived from the
/// clock changes on every read, so neither override earned its keep.
abstract class SideEffectEvent {}
