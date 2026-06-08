import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final Color mainGreen;
  final Color darkText;
  final bool isOnline;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onBackTap;
  final VoidCallback? onLogoutTap;
  final VoidCallback? onProfileTap;
  final String title;

  const AppHeader({
    super.key,
    required this.mainGreen,
    required this.darkText,
    required this.isOnline,
    required this.title,
    this.onBackTap,
    this.onNotificationTap,
    this.onLogoutTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBackTap ?? () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              color: const Color(0xFF222222),
              iconSize: 30,
            ),

            const Spacer(),

            InkWell(
              onTap: onNotificationTap,
              borderRadius: BorderRadius.circular(22),
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 31,
                  color: Color(0xFF222222),
                ),
              ),
            ),

            const SizedBox(width: 14),

            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'profile') {
                  onProfileTap?.call();
                }

                if (value == 'logout') {
                  onLogoutTap?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 22),
                      SizedBox(width: 10),
                      Text('Thay đổi thông tin'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 22,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Đăng xuất',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: mainGreen.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                  height: 1.1,
                ),
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isOnline ? mainGreen : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
