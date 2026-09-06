import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const GhostMusicApp());
}

class SongInfo {
  final String title;
  final String artist;
  final String path;
  SongInfo({required this.title, required this.artist, required this.path});
}

class GhostMusicApp extends StatelessWidget {
  const GhostMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0C0C10),
        brightness: Brightness.dark,
        fontFamily: 'sans-serif',
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final AudioPlayer _player = AudioPlayer();
  List<SongInfo> _songs = [];
  int? _currentIndex;
  bool _isPlaying = false;
  int _selectedTab = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
    _scanStorage();
  }

  Future<void> _scanStorage() async {
    setState(() => _isLoading = true);

    await Permission.audio.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    List<SongInfo> foundSongs = [];
    List<String> folders = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Download/Telegram',
      '/storage/emulated/0/Audiobooks',
      '/storage/emulated/0/Podcasts',
      '/storage/emulated/0/Ringtones',
      '/storage/emulated/0/Recordings',
    ];

    for (var f in folders) {
      var dir = Directory(f);
      if (await dir.exists()) {
        try {
          var files = dir.listSync(recursive: true);
          for (var item in files) {
            if (item.path.endsWith('.mp3') || item.path.endsWith('.m4a') || item.path.endsWith('.wav')) {
              String name = item.path.split('/').last.replaceAll(RegExp(r'\.(mp3|m4a|wav)$'), '');
              if (!foundSongs.any((s) => s.path == item.path)) {
                foundSongs.add(SongInfo(title: name, artist: "Local Audio", path: item.path));
              }
            }
          }
        } catch (_) {}
      }
    }

    setState(() {
      _songs = foundSongs;
      _isLoading = false;
    });
  }

  Future<void> _playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    try {
      _currentIndex = index;
      await _player.setFilePath(_songs[index].path);
      _player.play();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot play: $e')));
    }
  }

  void _togglePlayPause() {
    if (_songs.isEmpty) return;
    if (_currentIndex == null) {
      _playSong(0);
      return;
    }
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SongInfo? currentSong = _currentIndex != null && _songs.isNotEmpty ? _songs[_currentIndex!] : null;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedTab,
            children: [
              _buildHomeFeedTab(),
              _buildMyMusicTab(),
            ],
          ),

          // Mini Player
          if (currentSong != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 84,
              child: GestureDetector(
                onTap: () => _openNowPlaying(currentSong),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: const Color(0xFF1F1F28).withOpacity(0.9),
                      child: Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                            child: const Image(image: AssetImage('assets/logo.png'), width: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(currentSong.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(currentSong.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: const Color(0xFFD8F25C), size: 32),
                            onPressed: _togglePlayPause,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Bar
          Positioned(
            left: 36,
            right: 36,
            bottom: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: const Color(0xFF1E1E24).withOpacity(0.8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navButton(Icons.home_filled, 0),
                      _navButton(Icons.library_music_rounded, 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, int index) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFFD8F25C) : Colors.transparent, shape: BoxShape.circle),
        child: Icon(icon, color: isSelected ? Colors.black : Colors.white60, size: 22),
      ),
    );
  }

  Widget _buildHomeFeedTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          Row(
            children: [
              Image.asset('assets/logo.png', width: 38, height: 38),
              const Spacer(),
              _roundIcon(Icons.refresh, onTap: _scanStorage),
            ],
          ),
          const SizedBox(height: 18),
          const Text("Hi, Samantha", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryPill("All", true),
                _categoryPill("New Release", false),
                _categoryPill("Trending", false),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFC6A7FE), borderRadius: BorderRadius.circular(28)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Discover weekly", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 6),
                      Text(
                        _songs.isEmpty ? "Tap refresh to find songs" : "${_songs.length} offline songs ready",
                        style: const TextStyle(color: Colors.black87, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF322353),
                        child: IconButton(
                          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
                          onPressed: () {
                            if (_songs.isNotEmpty) {
                              _togglePlayPause();
                            } else {
                              _scanStorage();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Image.asset('assets/logo.png', width: 85, height: 85),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Tracks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFD8F25C)), onPressed: _scanStorage),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_songs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    const Text("No songs found in Music or Download folder", style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD8F25C), foregroundColor: Colors.black),
                      onPressed: _scanStorage,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Scan Folders Again"),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._songs.map((song) => _buildTrackTile(song, _songs.indexOf(song))),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMyMusicTab() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _roundIcon(Icons.arrow_back, onTap: () => setState(() => _selectedTab = 0)),
                const Spacer(),
                const Text("My Music", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                _roundIcon(Icons.refresh, onTap: _scanStorage),
              ],
            ),
          ),
          Expanded(
            child: _songs.isEmpty
                ? Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD8F25C), foregroundColor: Colors.black),
                      onPressed: _scanStorage,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Scan for Music"),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: _songs.length,
                    itemBuilder: (context, index) => _buildTrackTile(_songs[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(SongInfo song, int index) {
    bool isCurrentPlaying = _currentIndex == index;
    return ListTile(
      onTap: () => _playSong(index),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: const Color(0xFF1E1E24), borderRadius: BorderRadius.circular(12)),
        child: const Image(image: AssetImage('assets/logo.png'), width: 24),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: isCurrentPlaying ? const Color(0xFFD8F25C) : Colors.white)),
      subtitle: Text(song.artist, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: IconButton(
        icon: Icon(isCurrentPlaying && _isPlaying ? Icons.pause_circle_filled : Icons.play_arrow_rounded, color: isCurrentPlaying ? const Color(0xFFD8F25C) : Colors.white60),
        onPressed: () {
          if (isCurrentPlaying) {
            _togglePlayPause();
          } else {
            _playSong(index);
          }
        },
      ),
    );
  }

  Widget _roundIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(color: Color(0xFF1E1E24), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _categoryPill(String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(color: isSelected ? const Color(0xFFD8F25C) : const Color(0xFF1E1E24), borderRadius: BorderRadius.circular(20)),
      child: Text(title, style: TextStyle(color: isSelected ? Colors.black : Colors.white60, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  void _openNowPlaying(SongInfo song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StreamBuilder<Duration?>(
          stream: _player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = _player.duration ?? Duration.zero;

            return Container(
              height: MediaQuery.of(context).size.height * 0.94,
              decoration: const BoxDecoration(color: Color(0xFF0F0F14), borderRadius: BorderRadius.vertical(top: Radius.circular(36))),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 28), onPressed: () => Navigator.pop(context)),
                      const Text("Now Playing", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.favorite_border, size: 22), onPressed: () {}),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E1E24),
                      boxShadow: [BoxShadow(color: const Color(0xFFD8F25C).withOpacity(0.12), blurRadius: 40, spreadRadius: 8)],
                    ),
                    child: Center(child: Image.asset('assets/logo.png', width: 110)),
                  ),
                  const Spacer(),
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(song.artist, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 24),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                      activeTrackColor: const Color(0xFFD8F25C),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: const Color(0xFFD8F25C),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                      value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0),
                      onChanged: (val) => _player.seek(Duration(milliseconds: val.toInt())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                        Text(_formatDuration(duration), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Icon(Icons.shuffle, color: Colors.white54, size: 22),
                      IconButton(icon: const Icon(Icons.skip_previous, size: 30), onPressed: () {
                        if (_currentIndex != null && _currentIndex! > 0) _playSong(_currentIndex! - 1);
                      }),
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFFD8F25C),
                        child: IconButton(
                          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 30),
                          onPressed: _togglePlayPause,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.skip_next, size: 30), onPressed: () {
                        if (_currentIndex != null && _currentIndex! < _songs.length - 1) _playSong(_currentIndex! + 1);
                      }),
                      const Icon(Icons.repeat, color: Colors.white54, size: 22),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
