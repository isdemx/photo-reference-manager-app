// lib/src/presentation/bloc/session_state.dart

part of 'session_bloc.dart';

class SessionState extends Equatable {
  final bool showPrivate;

  const SessionState({required this.showPrivate});

  SessionState copyWith({bool? showPrivate}) {
    return SessionState(showPrivate: showPrivate ?? this.showPrivate);
  }

  @override
  List<Object?> get props => [showPrivate];
}
