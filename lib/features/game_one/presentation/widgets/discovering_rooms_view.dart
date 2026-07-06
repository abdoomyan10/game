import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/discovered_room.dart';
import '../bloc/game_one_bloc.dart';

class DiscoveringRoomsView extends StatelessWidget {
  const DiscoveringRoomsView({
    super.key,
    required this.userName,
    required this.rooms,
    required this.isJoining,
  });

  final String userName;
  final List<DiscoveredRoom> rooms;
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
            rooms.isEmpty
                ? 'جاري البحث عن غرف قريبة...'
                : 'اختر غرفة للانضمام',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXXL),
          if (rooms.isEmpty)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: rooms.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppTheme.spacingM),
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  return _RoomTile(
                    room: room,
                    onTap: () => context.read<GameOneBloc>().add(
                          DiscoverRoomsEvent(
                            userName,
                            endpointId: room.id,
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

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.onTap,
  });

  final DiscoveredRoom room;
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
                backgroundColor: AppColors.accentGame1,
                child: Icon(Icons.wifi_tethering, color: AppColors.onPrimary),
              ),
              const SizedBox(width: AppTheme.spacingL),
              Expanded(
                child: Text(room.hostName, style: AppTextStyles.title),
              ),
              const Icon(Icons.chevron_left, color: AppColors.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}
