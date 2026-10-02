import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive.dart';

void main() {
  runApp(const ModManagerApp());
}

class ModManagerApp extends StatelessWidget {
  const ModManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCPE Mod Manager',
      theme: ThemeData.dark(),
      home: const ModListScreen(),
    );
  }
}

class ModItem {
  final String filePath;
  final String fileName;
  final List<int>? iconBytes;
  bool isSelected;

  ModItem({
    required this.filePath,
    required this.fileName,
    this.iconBytes,
    this.isSelected = false,
  });
}

class ModListScreen extends StatefulWidget {
  const ModListScreen({super.key});

  @override
  State<ModListScreen> createState() => _ModListScreenState();
}

class _ModListScreenState extends State<ModListScreen> {
  List<ModItem> modsList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  // طلب صلاحيات الوصول للملفات
  Future<void> _requestPermissionAndLoad() async {
    var status = await Permission.storage.request();
    if (await Permission.manageExternalStorage.request().isGranted || status.isGranted) {
      _scanDownloadFolder();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء إعطاء صلاحية الوصول للملفات')),
      );
    }
  }

  // مسح مجلد التنزيلات للبحث عن المودات
  Future<void> _scanDownloadFolder() async {
    setState(() => isLoading = true);
    List<ModItem> tempMods = [];

    Directory downloadDir = Directory('/storage/emulated/0/Download');
    if (await downloadDir.exists()) {
      List<FileSystemEntity> files = downloadDir.listSync();
      for (var file in files) {
        if (file.path.endsWith('.mcpack') || file.path.endsWith('.mcaddon') || file.path.endsWith('.zip')) {
          List<int>? iconData;
          try {
            // محاولة قراءة صورة pack_icon.png من داخل الملف المضغوط
            final bytes = File(file.path).readAsBytesSync();
            final archive = ZipDecoder().decodeBytes(bytes);
            for (final archiveFile in archive) {
              if (archiveFile.name.endsWith('pack_icon.png')) {
                iconData = archiveFile.content as List<int>;
                break;
              }
            }
          } catch (_) {}

          tempMods.add(ModItem(
            filePath: file.path,
            fileName: file.path.split('/').last,
            iconBytes: iconData,
          ));
        }
      }
    }

    setState(() {
      modsList = tempMods;
      isLoading = false;
    });
  }

  // تثبيت المودات المحددة
  Future<void> _installSelectedMods() async {
    List<ModItem> selectedMods = modsList.where((m) => m.isSelected).toList();
    if (selectedMods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد مود واحد على الأقل')),
      );
      return;
    }

    // مسار مجلد ماين كرافت بيدروك في أجهزة الأندرويد الحديثة
    String targetPath = '/storage/emulated/0/Android/data/com.mojang.minecraftpe/files/games/com.mojang/behavior_packs/';
    Directory targetDir = Directory(targetPath);

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    for (var mod in selectedMods) {
      File sourceFile = File(mod.filePath);
      await sourceFile.copy('$targetPath/${mod.fileName}');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تثبيت ${selectedMods.length} مود بنجاح!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة مودات Minecraft Bedrock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanDownloadFolder,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : modsList.isEmpty
              ? const Center(child: Text('لم يتم العثور على مودات في مجلد التنزيلات'))
              : ListView.builder(
                  itemCount: modsList.length,
                  itemBuilder: (context, index) {
                    final mod = modsList[index];
                    return CheckboxListTile(
                      value: mod.isSelected,
                      onChanged: (val) {
                        setState(() {
                          mod.isSelected = val ?? false;
                        });
                      },
                      title: Text(mod.fileName),
                      secondary: mod.iconBytes != null
                          ? Image.memory(
                              Uint8List.fromList(mod.iconBytes!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.extension, size: 48),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _installSelectedMods,
        label: const Text('تركيب المودات المحددة'),
        icon: const Icon(Icons.download_done),
      ),
    );
  }
}
