import 'package:flutter/material.dart';
import '../widget/app_scaffold.dart';
import 'chat_list_page.dart';
import 'chat_thread_page.dart';
import 'home_page.dart';
import 'products_page.dart';
import 'profile_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({
    super.key,
    this.initialIndex = 0,
    this.openChatOrderId,
    this.openChatCustomerId,
  });

  final int initialIndex;
  final String? openChatOrderId;
  final String? openChatCustomerId;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final oid = widget.openChatOrderId;
      final cid = widget.openChatCustomerId;

      if (oid != null && oid.isNotEmpty && cid != null && cid.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatThreadPage(
              orderId: oid,
              customerId: cid,
              isAdminView: false,
            ),
          ),
        );
      }
    });

  }

  @override
  Widget build(BuildContext context) {
    // CUSTOMER TABS ONLY
    final pages = const [
      HomePage(),
      ProductsPage(),
      ChatListPage(isAdmin: false), // content-only page
      ProfilePage(),
    ];

    return AppScaffold(
      currentIndex: _currentIndex,
      onTabSelected: (index) => setState(() => _currentIndex = index),
      isAdmin: false, // ← important: do NOT show Admin tab in the customer shell
      child: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
    );
  }
}
