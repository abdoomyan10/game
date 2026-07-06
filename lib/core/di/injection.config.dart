// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import '../../features/game_one/data/datasources/network_datasource.dart'
    as _i495;
import '../../features/game_one/data/datasources/network_datasource_impl.dart'
    as _i170;
import '../../features/game_one/data/repositories/game_repository_impl.dart'
    as _i528;
import '../../features/game_one/data/services/encryption_service.dart' as _i374;
import '../../features/game_one/data/services/encryption_service_impl.dart'
    as _i972;
import '../../features/game_one/data/services/p2p_permission_service.dart'
    as _i659;
import '../../features/game_one/domain/repositories/game_repository.dart'
    as _i92;
import '../../features/game_one/domain/usecases/distribute_roles_usecase.dart'
    as _i578;
import '../../features/game_one/domain/usecases/ensure_p2p_permissions_usecase.dart'
    as _i441;
import '../../features/game_one/domain/usecases/join_room_usecase.dart'
    as _i1051;
import '../../features/game_one/domain/usecases/scan_for_rooms_usecase.dart'
    as _i171;
import '../../features/game_one/domain/usecases/send_game_payload_usecase.dart'
    as _i830;
import '../../features/game_one/domain/usecases/start_hosting_usecase.dart'
    as _i957;
import '../../features/game_one/presentation/bloc/game_one_bloc.dart' as _i617;
import '../../features/game_two/data/datasources/mafia_network_datasource.dart'
    as _i671;
import '../../features/game_two/data/datasources/mafia_network_datasource_impl.dart'
    as _i937;
import '../../features/game_two/presentation/bloc/mafia_bloc.dart' as _i389;
import '../../features/home/presentation/bloc/home_bloc.dart' as _i202;
import '../../features/splash/presentation/bloc/splash_bloc.dart' as _i442;
import '../network/api_client.dart' as _i557;
import '../network/interceptors/logging_interceptor.dart' as _i344;
import '../storage/local_storage.dart' as _i329;
import '../storage/shared_prefs_storage.dart' as _i180;
import 'register_module.dart' as _i291;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> initGetIt({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => registerModule.prefs,
      preResolve: true,
    );
    gh.factory<_i389.MafiaBloc>(() => _i389.MafiaBloc());
    gh.factory<_i202.HomeBloc>(() => _i202.HomeBloc());
    gh.factory<_i442.SplashBloc>(() => _i442.SplashBloc());
    gh.lazySingleton<_i361.Dio>(() => registerModule.dio);
    gh.lazySingleton<_i344.LoggingInterceptor>(
      () => _i344.LoggingInterceptor(),
    );
    gh.lazySingleton<_i659.P2pPermissionService>(
      () => _i659.P2pPermissionServiceImpl(),
    );
    gh.lazySingleton<_i374.EncryptionService>(
      () => _i972.EncryptionServiceImpl(),
    );
    gh.factory<_i557.ApiClient>(
      () => _i557.ApiClient(gh<_i361.Dio>(), gh<_i344.LoggingInterceptor>()),
    );
    gh.lazySingleton<_i329.LocalStorage>(
      () => _i180.SharedPrefsStorage(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i671.MafiaNetworkDataSource>(
      () => _i937.MafiaNetworkDataSourceImpl(gh<_i659.P2pPermissionService>()),
    );
    gh.lazySingleton<_i495.NetworkDataSource>(
      () => _i170.NetworkDataSourceImpl(gh<_i659.P2pPermissionService>()),
    );
    gh.lazySingleton<_i92.GameRepository>(
      () => _i528.GameRepositoryImpl(
        gh<_i495.NetworkDataSource>(),
        gh<_i374.EncryptionService>(),
        gh<_i659.P2pPermissionService>(),
      ),
    );
    gh.factory<_i441.EnsureP2pPermissionsUseCase>(
      () => _i441.EnsureP2pPermissionsUseCase(gh<_i92.GameRepository>()),
    );
    gh.factory<_i1051.JoinRoomUseCase>(
      () => _i1051.JoinRoomUseCase(gh<_i92.GameRepository>()),
    );
    gh.factory<_i171.ScanForRoomsUseCase>(
      () => _i171.ScanForRoomsUseCase(gh<_i92.GameRepository>()),
    );
    gh.factory<_i830.SendGamePayloadUseCase>(
      () => _i830.SendGamePayloadUseCase(gh<_i92.GameRepository>()),
    );
    gh.factory<_i957.StartHostingUseCase>(
      () => _i957.StartHostingUseCase(gh<_i92.GameRepository>()),
    );
    gh.factory<_i578.DistributeRolesUseCase>(
      () => _i578.DistributeRolesUseCase(
        gh<_i92.GameRepository>(),
        gh<_i830.SendGamePayloadUseCase>(),
      ),
    );
    gh.factory<_i617.GameOneBloc>(
      () => _i617.GameOneBloc(
        gh<_i441.EnsureP2pPermissionsUseCase>(),
        gh<_i957.StartHostingUseCase>(),
        gh<_i171.ScanForRoomsUseCase>(),
        gh<_i1051.JoinRoomUseCase>(),
        gh<_i578.DistributeRolesUseCase>(),
        gh<_i92.GameRepository>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i291.RegisterModule {}
