import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? selectedMember1;
  String? selectedMember2;

  final List<String> members = [
    'Budi Santoso',
    'Siti Aminah',
    'Andi Darmawan',
    'Rina Melati',
    'Joko Anwar',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Bandingkan Anggota', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pilih Anggota untuk Dibandingkan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildMemberSelector(
                    title: 'Anggota 1',
                    value: selectedMember1,
                    onChanged: (val) {
                      setState(() {
                        selectedMember1 = val;
                      });
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.indigo,
                    radius: 20,
                    child: Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: _buildMemberSelector(
                    title: 'Anggota 2',
                    value: selectedMember2,
                    onChanged: (val) {
                      setState(() {
                        selectedMember2 = val;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: (selectedMember1 != null && selectedMember2 != null && selectedMember1 != selectedMember2)
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Membandingkan $selectedMember1 dan $selectedMember2')),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Mulai Perbandingan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberSelector({
    required String title,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Icon(
            Icons.person,
            size: 48,
            color: value != null ? Colors.indigo : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Pilih...', textAlign: TextAlign.center),
              value: value,
              alignment: Alignment.center,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.indigo),
              items: members.map((member) {
                return DropdownMenuItem<String>(
                  value: member,
                  child: Center(child: Text(member, overflow: TextOverflow.ellipsis)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
