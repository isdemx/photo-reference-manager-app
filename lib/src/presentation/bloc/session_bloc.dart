// lib/src/presentation/bloc/session_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'session_event.dart';
part 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc() : super(const SessionState(showPrivate: false)) {
    on<ToggleShowPrivateEvent>((event, emit) {
      emit(state.copyWith(showPrivate: !state.showPrivate));
    });
  }
}
