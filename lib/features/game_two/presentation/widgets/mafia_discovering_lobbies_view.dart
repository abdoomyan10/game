import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/mafia_discovered_lobby.dart';
import '../bloc/mafia_bloc.dart';
import '../bloc/mafia_event.dart';

class MafiaDiscoveringLobbiesView extends StatelessWidget {
  const MafiaDiscoveringLobbiesView({
    super.key,
    required this.userName,
    required this.lobbies,
    required this.isJoining,
  });

  final String userName;
  final List<MafiaDiscoveredLobby> lobbies;
  final bool isJoining;

  @override
  Widget build(BuildContext context) {
    if (isJoining) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الغرف المتاحة',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            lobbies.isEmpty
                ? 'جاري البحث عن غرف قريبة...'
                : 'اختر غرفة للانضمام',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXXL),
          if (lobbies.isEmpty)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: lobbies.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppTheme.spacingM),
                itemBuilder: (context, index) {
                  final lobby = lobbies[index];
                  return _LobbyTile(
                    lobby: lobby,
                    onTap: () => context.read<MafiaBloc>().add(
                          DiscoverLobbyEvent(
                            userName,
                            endpointId: lobby.endpointId,
                          ),
                        ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LobbyTile extends StatelessWidget {
  const _LobbyTile({
    required this.lobby,
    required this.onTap,
  });

  final MafiaDiscoveredLobby lobby;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.accentGame2,
                child: Icon(Icons.wifi_tethering, color: AppColors.onPrimary),
              ),
              const SizedBox(width: AppTheme.spacingL),
              Expanded(
                child: Text(lobby.hostName, style: AppTextStyles.title),
              ),
              const Icon(Icons.chevron_left, color: AppColors.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}
