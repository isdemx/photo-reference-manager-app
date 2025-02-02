// lib/src/presentation/bloc/session_event.dart

part of 'session_bloc.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => [];
}

class ToggleShowPrivateEvent extends SessionEvent {}
